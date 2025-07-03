/**
 * Lock-sure Cloud Functions – Alexa integration (Auth Code Grant)
 * 2025-06-30
 */
const functions = require('firebase-functions');
const admin     = require('firebase-admin');
const crypto    = require('crypto');
const logger    = require('firebase-functions/logger');
const fetch     = globalThis.fetch || ((...args) =>
  import('node-fetch').then(m => m.default(...args)));
const qs        = require('querystring');
const DEFAULT_LWA_TOKEN_URL = 'https://api.amazon.com/auth/o2/token';

admin.initializeApp();

// pull secrets from Firebase config: run `firebase functions:config:set alexa.client_id="..."` etc.
const {
  client_id:        ALEXA_CLIENT_ID,
  client_secret:    ALEXA_CLIENT_SECRET,
  lwa_auth_url:     LWA_AUTH_URL,
  lwa_token_url:    LWA_TOKEN_URL,
  token_lookup_url: TOKEN_LOOKUP_URL,
  list_rooms_url:   LIST_ROOMS_URL,
  firebase_url:     FIREBASE_URL,
} = functions.config().alexa;

// fallback if config omission
const finalLwaTokenUrl = LWA_TOKEN_URL || DEFAULT_LWA_TOKEN_URL;

// simple UID validation
const isValidUid = t => typeof t === 'string' && /^[A-Za-z0-9]{28}$/.test(t);

/**
 * Exchange an LWA access_token → Firebase UID
 */
async function uidFromAccessToken(token) {
  if (isValidUid(token)) return token;
  if (!token.startsWith('Atza|')) return null;

  const res = await fetch(TOKEN_LOOKUP_URL, {
    method:  'POST',
    headers: { 'Content-Type': 'application/json' },
    body:    JSON.stringify({ accessToken: token }),
  });
  if (!res.ok) {
    logger.error('token lookup failed', await res.text());
    throw new Error('Bad accessToken');
  }
  const { uid } = await res.json();
  if (!isValidUid(uid)) throw new Error('Invalid UID from lookup');
  return uid;
}

// Smart-Home capabilities block (unchanged)
const CAPS = [
  { type:'AlexaInterface', interface:'Alexa', version:'3' },
  {
    type:'AlexaInterface', interface:'Alexa.LockController', version:'3',
    properties:{ supported:[{name:'lockState'}], retrievable:true, proactivelyReported:false }
  },
  {
    type:'AlexaInterface', interface:'Alexa.ContactSensor', version:'3',
    properties:{ supported:[{name:'detectionState'}], retrievable:true, proactivelyReported:false }
  },
  {
    type:'AlexaInterface', interface:'Alexa.EndpointHealth', version:'3',
    properties:{ supported:[{name:'connectivity'}], retrievable:true, proactivelyReported:false }
  },
];

// 1) Notifications (unchanged)
exports.sendNotification = functions.firestore
  .document('/notifications/{docId}')
  .onCreate(async snap => {
    const { userId: uid, message, deviceName } = snap.data();
    if (!isValidUid(uid)) return;
    const state = message?.uplink_message?.decoded_payload?.lockState;
    const label = {1:'LOCKED',2:'UNLOCKED',3:'OPEN',4:'CLOSED'}[state] || 'Unknown';
    const userSnap = await admin.firestore().collection('users').doc(uid).get();
    const tokens   = (userSnap.data()?.fcmId || []).filter(t => typeof t==='string' && t.length>100);
    await Promise.all(tokens.map(tok =>
      admin.messaging().send({
        token: tok,
        notification:{ title:'Locksure', body:`${deviceName} door is ${label}` },
        android:{ priority:'high' },
        apns:{ payload:{ aps:{ contentAvailable:true } } },
      }).catch(e => {
        if (e.code?.includes('registration-token')) {
          admin.firestore().doc(`users/${uid}`)
            .update({ fcmId: admin.firestore.FieldValue.arrayRemove(tok) });
        }
      })
    ));
  });

// 2) Smart-Home endpoints (unchanged)
exports.alexaSmartHome = functions.https.onRequest(async (req, res) => {
  const { userId, roomId } = req.query;
  if (!userId || !roomId) return res.status(400).json({ error:'userId+roomId required' });
  const doc = await admin.firestore().doc(`rooms/${roomId}`).get();
  if (!doc.exists || doc.data().userId !== userId)
    return res.status(404).json({ error:'room not found' });
  res.json({ state: doc.data().state || 0 });
});
exports.listRooms = functions.https.onRequest(async (req, res) => {
  const { userId } = req.query;
  if (!userId) return res.status(400).json({ error:'userId required' });
  const snap = await admin.firestore().collection('rooms')
    .where('userId','==',userId).get();
  res.json(snap.docs.map(d=>({ roomId:d.id, name:d.data().name || d.id })));
});

// 3) OAuth2 Auth Code Grant — Authorization endpoint
exports.alexaAuth = functions.https.onRequest(async (req, res) => {
  const { redirect_uri, state, code: lwaCode } = req.query;
  console.log('🔍 Query Params:', req.query);

  // ── PHASE 1: redirect the user to LWA for sign-in & consent ──
  if (!lwaCode) {
    if (!redirect_uri || !state) {
      return res.status(400).send('Missing redirect_uri or state');
    }
    const params = qs.stringify({
      client_id:     ALEXA_CLIENT_ID,
      scope:         'profile',
      response_type: 'code',         // ← Auth Code Grant
      redirect_uri:  redirect_uri,   // LWA will come back here
      state:         state,          // preserve original Alexa state
    });
    return res.redirect(`${LWA_AUTH_URL}?${params}`);
  }

  // ── PHASE 2: LWA has given us an authorization code ──
  // Exchange that for an LWA access_token
  let lwaToken, uid;
  try {
    const tokenRes = await fetch(finalLwaTokenUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type:    'authorization_code',
        code:          lwaCode,
        client_id:     ALEXA_CLIENT_ID,
        client_secret: ALEXA_CLIENT_SECRET,
        redirect_uri,
      })
    });

    if (!tokenRes.ok) {
      const err = await tokenRes.text();
      console.error('❌ LWA token exchange failed:', err);
      throw new Error(err);
    }

    const tokenJson = await tokenRes.json();
    console.log('✅ LWA access token received:', tokenJson.access_token);

    lwaToken = tokenJson.access_token;
    uid = await uidFromAccessToken(lwaToken);
    console.log('✅ Firebase UID resolved:', uid);

  } catch (e) {
    console.error('❌ Failed in /alexaAuth:', e.message || e);
    return res.status(400).send('invalid_grant');
  }

  // Generate our one-time skill code, store mapping → { uid, lwaToken }
  const skillCode = crypto.randomBytes(16).toString('hex');
  console.log('🔐 alexaAuth generated skillCode:', { uid, skillCode });
  await admin.firestore().collection('alexaCodes').doc(skillCode).set({
    uid,
    accessToken: lwaToken,
    created:     admin.firestore.FieldValue.serverTimestamp(),
  });

  // Redirect back to Alexa's redirect_uri with our code + original state
  const dest = new URL(redirect_uri);
  dest.searchParams.set('code',  skillCode);
  dest.searchParams.set('state', state);
  console.log('🔗 Redirecting to:', dest.toString());
  return res.redirect(dest.toString());
});

// 4) Token endpoint — Alexa calls this to swap code → Firebase UID
exports.alexaToken = functions.https.onRequest(async (req, res) => {
  console.log('alexaToken called:', req.method, req.body, req.headers);
  if (req.method !== 'POST') return res.status(405).send('Method Not Allowed');
  const auth = (req.headers.authorization||'').split(' ')[1] || '';
  const [cid,secret] = Buffer.from(auth,'base64').toString().split(':');
  if (cid!==ALEXA_CLIENT_ID||secret!==ALEXA_CLIENT_SECRET) {
    return res.status(401).send('Bad client credentials');
  }
  const { code } = req.body || {};
  if (!code) return res.status(400).json({ error:'invalid_request' });
  const snap = await admin.firestore().doc(`alexaCodes/${code}`).get();
  if (!snap.exists) return res.status(400).json({ error:'invalid_grant' });
  return res.json({
    access_token: snap.data().uid,
    token_type:   'bearer',
    expires_in:   3600
  });
});

// 5) Token Lookup — for Flutter in-app linking
exports.alexaTokenLookup = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') return res.status(405).send('Method Not Allowed');
  const { accessToken } = req.body||{};
  if (!accessToken?.startsWith('Atza|')) {
    return res.status(400).json({ error:'bad accessToken' });
  }
  const q = await admin.firestore().collection('alexaCodes')
    .where('accessToken','==',accessToken).limit(1).get();
  if (q.empty) return res.status(404).json({ error:'not linked yet' });
  res.json({ uid: q.docs[0].data().uid });
});

// 6) Flutter helper: mark a user as linked
exports.alexaLinkUser = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') return res.status(405).send('Method Not Allowed');
  const { userId } = req.body||{};
  if (!isValidUid(userId)) return res.status(400).send('bad uid');
  await admin.firestore().doc(`users/${userId}`)
    .set({ alexaLinked:true },{ merge:true });
  res.json({ ok:true });
});