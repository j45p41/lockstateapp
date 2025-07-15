'use strict';

/*  LockSure Alexa Smart-Home Skill – 2025-07-08 (tokenMap, logging, full flow)
 *  Single-file CommonJS for AWS Lambda (API-Gateway proxy)
 *  Paths: /alexaAuth   /alexaCallback   /alexaToken   /smartHome
 */

/* ───────── 0.  FULL TRACE OF INCOMING EVENT ───────── */
exports.handler = async event => {
  console.log('RAW-EVENT FULL:', JSON.stringify(event, null, 2));
  log('INFO', 'Lambda invoked', { path: event.path, method: event.httpMethod, rawPath: event.rawPath });

  if (event.directive || (event.body && safeJSON(event.body)?.directive))
    return await smartHome(event);

  const p = (event.rawPath || event.path || '').toLowerCase().replace(/^\/prod/, '');
  const m = (event.requestContext?.http?.method || event.httpMethod || 'GET').toUpperCase();

  if (/\/alexaauth$/.test(p) && (m === 'GET' || m === 'POST')) return await alexaAuth(event);
  if (/\/alexacallback$/.test(p) && m === 'GET')                 return await alexaAuth(event); // same handler
  if (/\/alexatoken$/.test(p) && m === 'POST')                   return await alexaToken(event);
  if (/\/smarthome$|\/smart-home$/.test(p) && m === 'POST') return await smartHome(event);

  return { statusCode: 404, body: 'Not found' };
};

/* ───────── 1.  DEPENDENCIES ───────── */
const crypto = require('crypto');
const admin  = require('firebase-admin');
const https  = require('https');
const http   = require('http');

/* tiny fetch helper (keeps us single-file) */
const fetch = (url, opts = {}) => new Promise((res, rej) => {
  const u   = new URL(url);
  const mod = u.protocol === 'https:' ? https : http;
  const req = mod.request(
    { hostname: u.hostname,
      port    : u.port || (u.protocol === 'https:' ? 443 : 80),
      path    : u.pathname + u.search,
      method  : opts.method || 'GET',
      headers : opts.headers || {} },
    r => {
      let data = '';
      r.on('data', d => (data += d));
      r.on('end', () =>
        res({
          ok    : r.statusCode >= 200 && r.statusCode < 300,
          status: r.statusCode,
          json  : () => Promise.resolve(JSON.parse(data || '{}')),
          text  : () => Promise.resolve(data)
        }));
    });
  req.on('error', rej);
  if (opts.body) req.write(opts.body);
  req.end();
});

/* ───────── 2.  CONFIG ───────── */
const { FB_SERVICE_ACCOUNT_JSON, FIREBASE_API_KEY } = process.env;
const SKILL_ID  = 'amzn1.ask.skill.89751fb9-1b7f-4c40-8c9f-a5231bdb3998';
const API_BASE  = 'https://ayb2a2m447.execute-api.eu-west-1.amazonaws.com/prod';
const REDIRECT_URI = `${API_BASE}/alexaCallback`;

/* ───────── 3.  FIREBASE ───────── */
if (!admin.apps.length) {
  if (!FB_SERVICE_ACCOUNT_JSON) throw new Error('FB_SERVICE_ACCOUNT_JSON missing');
  admin.initializeApp({ credential: admin.credential.cert(JSON.parse(FB_SERVICE_ACCOUNT_JSON)) });
}
const db = admin.firestore();

log('DEBUG', 'Firebase project', { projectId: admin.app().options.credential.projectId });

/* ───────── 4.  HELPERS ───────── */
function log(lvl, msg, data = {}) {
  console.log(JSON.stringify({ ts: new Date().toISOString(), lvl, msg, data }));
}

function safeJSON(str) {
  if (!str || str === 'undefined') return undefined;
  try { return JSON.parse(str); } catch { return undefined; }
}

const stateToAlexa = (state) => {
  switch (state) {
    case 1: // LOCKED
      return { value: 'LOCKED', colorHint: 'cyan' };
    case 2: // UNLOCKED
      return { value: 'UNLOCKED', colorHint: 'amber' };
    case 3: // CLOSED
      return { value: 'LOCKED', colorHint: 'amber' };
    case 4: // OPEN
      return { value: 'UNLOCKED', colorHint: 'red' };
    default:
      return { value: 'JAMMED', colorHint: 'red' };
  }
};

const htmlLogin = (state, redirect, stagePrefix = '') => /*html*/`
<!DOCTYPE html><html><head><title>Locksure – Sign In</title></head>
<body style="font-family:sans-serif;max-width:420px;margin:40px auto;padding:24px">
  <h2>Link your Locksure account</h2>
  <form method="POST" action="${stagePrefix}/alexaAuth" style="display:flex;flex-direction:column;gap:12px">
    <input type="email"    name="email"    placeholder="Email"    required style="padding:8px">
    <input type="password" name="password" placeholder="Password" required style="padding:8px">
    <input type="hidden"   name="state"        value="${state}">
    <input type="hidden"   name="redirect_uri" value="${redirect}">
    <button type="submit"  style="padding:10px 20px;font-size:16px">Sign in</button>
  </form>
</body></html>`;

/* ───────── 4a. UID resolver ───────── */
async function resolveUid(tok) {
  log('DEBUG', 'resolveUid called', { tok });
  if (!tok || typeof tok !== 'string' || tok.trim() === '') {
    log('WARN', 'resolveUid received empty token', { tok });
    return null;
  }
  // Accept Firebase UID directly
  if (/^[A-Za-z0-9_-]{28}$/.test(tok)) {
    log('DEBUG', 'resolveUid: Token looks like Firebase UID', { uid: tok });
    return tok;
  }
  // Check /users for legacy support
  const q = await db.collection('users').where('lwaAccessToken', '==', tok).limit(1).get();
  if (!q.empty) {
    log('DEBUG', 'resolveUid: found via users.lwaAccessToken', { uid: q.docs[0].id });
    return q.docs[0].id;
  }
  log('WARN', 'resolveUid: could not resolve token', { tok });
  return null;
}

/* ───────── 5.  ROOM HELPERS ───────── */
const getRoomsForUser = async uid => {
  const snap  = await db.collection('rooms').where('userId', '==', uid).get();
  const rooms = snap.docs.map(d => ({ id: d.id, ...d.data() }));
  log('INFO', 'Firestore rooms query', { uid, count: rooms.length, roomIds: rooms.map(r => r.id) });
  return rooms;
};

const getRoomState = async roomId => {
  log('DEBUG', 'getRoomState', { roomId });
  const doc = await db.collection('rooms').doc(roomId).get();
  log('DEBUG', 'getRoomState Firestore doc', { exists: doc.exists, data: doc.data() });
  return doc.data();
};

const setRoomState = async (roomId, locked) => {
  log('INFO', 'setRoomState', { roomId, locked });
  await db.collection('rooms').doc(roomId)
    .set({ state: locked ? 1 : 2,
           lastUpdated: admin.firestore.FieldValue.serverTimestamp() },
         { merge: true });
};

/* ───────── 6a.  /alexaAuth ───────── */
async function alexaAuth(event) {
  log('HANDLER', 'alexaAuth called', { method: event.httpMethod, qs: event.queryStringParameters });
  const q    = event.queryStringParameters || {};
  const body = event.httpMethod === 'POST'
    ? Object.fromEntries(new URLSearchParams(event.body || ''))
    : {};
  const state        = q.state        || body.state        || crypto.randomBytes(8).toString('hex');
  const redirect_uri = q.redirect_uri || body.redirect_uri || REDIRECT_URI;
  const { email, password } = body;

  // ───  AUTO-LINK  (called from the mobile app) ─────────
  if (event.httpMethod === 'GET' && q.auto === '1' && q.uid) {
    log('INFO', 'auto-link request', { uid: q.uid });

    // OPTIONAL - verify that the UID really exists
    // const user = await admin.auth().getUser(q.uid).catch(() => null);
    // if (!user) return { statusCode: 400, body: 'invalid uid' };

    const code = crypto.randomBytes(32).toString('hex');
    await db.collection('alexaCodes').doc(code)
            .set({ uid: q.uid, state, used: false,
                   exp: Date.now() + 5 * 60e3 });

    const back = `${redirect_uri}?code=${code}&state=${state}`;
    return { statusCode: 302, headers: { Location: back }, body: '' };
  }

  if (email && password) {
    const resp = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_API_KEY}`,
      { method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password, returnSecureToken: true }) });
    const j = await resp.json();
    if (!resp.ok) {
      log('WARN', 'alexaAuth login failed', { error: j.error?.message });
      return { statusCode: 401, body: `Login failed: ${j.error?.message}` };
    }
    const code = crypto.randomBytes(32).toString('hex');
    await db.collection('alexaCodes').doc(code)
            .set({ uid: j.localId, state, used: false, exp: Date.now() + 5 * 60e3 });
    /*  Build redirect using the *actual* redirect_uri Amazon supplied, keeping
        us compatible with dev / prod Skill IDs. The original redirect_uri looks like
        https://layla.amazon.com/api/skill/link/<skillId>
        We simply append code & state.  */

    const back = `${redirect_uri}?code=${encodeURIComponent(code)}&state=${encodeURIComponent(state)}`;
    log('INFO', 'alexaAuth login success', { uid: j.localId, state, redirect: back });
    const stagePrefix = event.requestContext?.stage ? `/${event.requestContext.stage}` : '';
    return { statusCode: 302, headers: { Location: back }, body: '' };
  }
  const stagePrefix = event.requestContext?.stage ? `/${event.requestContext.stage}` : '';
  return { statusCode: 200, headers: { 'Content-Type': 'text/html' }, body: htmlLogin(state, redirect_uri, stagePrefix) };
}

/* ───────── 6b.  /alexaToken ───────── */
async function alexaToken(event) {
  log('HANDLER', 'alexaToken called', { method: event.httpMethod, body: event.body });
  const params = Object.fromEntries(new URLSearchParams(event.body || ''));
  log('HANDLER', 'alexaToken params', params);
  const { code, state } = params;

  if (!code)
    return { statusCode: 400, body: JSON.stringify({ error: 'missing_code' }) };

  const doc = await db.collection('alexaCodes').doc(code).get();
  log('DEBUG', 'alexaToken doc', { code, exists: doc.exists, data: doc.data() });
  if (!doc.exists)
    return { statusCode: 400, body: JSON.stringify({ error: 'invalid_code' }) };
  if (doc.data().used)
    return { statusCode: 400, body: JSON.stringify({ error: 'code_used' }) };
  if (state !== undefined && doc.data().state !== undefined && doc.data().state !== state)
    return { statusCode: 400, body: JSON.stringify({ error: 'state_mismatch' }) };

  await doc.ref.update({ used: true, usedAt: Date.now() });
  const uid = doc.data().uid;

  // Return the UID as the access_token for Alexa
  return {
    statusCode: 200,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      access_token: uid,
      token_type  : 'bearer',
      expires_in  : 3600
    })
  };
}

/* ───────── 6c.  /smartHome ───────── */
async function smartHome(event) {
  log('HANDLER', 'smartHome called', { eventType: typeof event });
  const directive = event.directive || safeJSON(event.body)?.directive;
  if (!directive) {
    log('ERROR', 'No directive in event', { event });
    return { statusCode: 400, body: JSON.stringify({ error: 'no_directive' }) };
  }
  const { header, payload } = directive;
  const { namespace, name } = header;

  /* ❶ AcceptGrant (LWA account-link handshake) */
  if (namespace === 'Alexa.Authorization' && name === 'AcceptGrant') {
    log('INFO', 'AcceptGrant received', { payload });
    // NO tokenMap update here, this is not the correct place!
    return {
      event: {
        header : { namespace: 'Alexa.Authorization', name: 'AcceptGrant.Response',
                   payloadVersion: '3', messageId: crypto.randomBytes(16).toString('hex') },
        payload: {}
      }
    };
  }

  /* bearer-token → Firebase UID */
  const token =
    payload?.scope?.token ||
    directive.endpoint?.scope?.token ||
    '';
  log('DEBUG', 'smartHome checking token', { token });
  const uid = await resolveUid(token);
  log('DEBUG', 'smartHome resolved UID', { uid });

  if (!uid) {
    const errorMsg = token === '' ? 'Empty token received - please re-link your account in the Alexa app' : 'Unknown or expired token';
    log('ERROR', 'Invalid authorization credential', { token, errorMsg });
    return {
      event: {
        header : { namespace: 'Alexa', name: 'ErrorResponse', payloadVersion: '3',
                   messageId: crypto.randomBytes(16).toString('hex') },
        payload: { type: 'INVALID_AUTHORIZATION_CREDENTIAL', message: errorMsg }
      }
    };
  }

  /* ❷ Discovery */
  if (namespace === 'Alexa.Discovery' && name === 'Discover') {
    try {
      const rooms     = await getRoomsForUser(uid);
      log('INFO', 'smartHome discovery endpoints', { count: rooms.length, endpoints: rooms.map(r => r.id) });
      const endpoints = rooms.map(r => {
        log('DEBUG', 'Creating endpoint for room', { roomId: r.id, roomName: r.name, roomData: r });
        return {
          endpointId       : r.id,
          manufacturerName : 'Locksure',
          friendlyName     : r.name || 'Door Lock',
          description      : r.name || 'Smart Lock',
          displayCategories: ['SMARTLOCK'],
          capabilities     : [{
            type: 'AlexaInterface',
            interface: 'Alexa.LockController',
            version: '3',
            properties: {
              supported: [{ name: 'lockState' }],
              proactivelyReported: true,
              retrievable: true
            }
          }]
        };
      });
      return {
        event: {
          header : { namespace: 'Alexa.Discovery', name: 'Discover.Response',
                     payloadVersion: '3', messageId: crypto.randomBytes(16).toString('hex') },
          payload: { endpoints }
        }
      };
    } catch (e) {
      log('ERROR', 'Discovery failed', { uid, error: e.message, stack: e.stack });
      return {
        event: {
          header : { namespace: 'Alexa', name: 'ErrorResponse', payloadVersion: '3',
                     messageId: crypto.randomBytes(16).toString('hex') },
          payload: { type: 'INTERNAL_ERROR', message: 'Firestore query failed' }
        }
      };
    }
  }

  /* ❸ Lock / Unlock */
  if (namespace === 'Alexa.LockController' && (name === 'Lock' || name === 'Unlock')) {
    const roomId     = payload.endpointId;
    const wantLocked = name === 'Lock';
    try {
      await setRoomState(roomId, wantLocked);
      const cur = await getRoomState(roomId);
      log('INFO', 'smartHome lock/unlock', { roomId, wantLocked, newState: cur?.state });
      return {
        context: {
          properties: [
            {
              namespace: 'Alexa.LockController',
              name     : 'lockState',
              value    : cur?.state === 1 ? 'LOCKED' : 'UNLOCKED',
              timeOfSample               : new Date().toISOString(),
              uncertaintyInMilliseconds  : 0
            },
            {
              namespace: 'Alexa.EndpointHealth',
              name     : 'connectivity',
              value    : { value: 'OK' },
              timeOfSample               : new Date().toISOString(),
              uncertaintyInMilliseconds  : 0
            }
          ]
        },
        event: {
          header : { namespace: 'Alexa', name: 'Response', payloadVersion: '3',
                     messageId: crypto.randomBytes(16).toString('hex'),
                     correlationToken: header.correlationToken },
          endpoint: { endpointId: roomId },
          payload : {}
        }
      };
    } catch (e) {
      log('ERROR', 'Lock/Unlock failed', { roomId, error: e.message, stack: e.stack });
      return {
        event: {
          header : { namespace: 'Alexa', name: 'ErrorResponse', payloadVersion: '3',
                     messageId: crypto.randomBytes(16).toString('hex'),
                     correlationToken: header.correlationToken },
          payload: { type: 'INTERNAL_ERROR', message: 'DB update failed' }
        }
      };
    }
  }

  /* ❹ ReportState (when user taps device in Alexa app) */
  if ((namespace === 'Alexa.LockController' && name === 'ReportState') || 
      (namespace === 'Alexa' && name === 'ReportState')) {
    log('INFO', 'ReportState directive received', { namespace, name, payload });
    const roomId = payload.endpointId || directive.endpoint?.endpointId;
    log('DEBUG', 'ReportState roomId', { roomId, payload, directive });
    try {
      const cur = await getRoomState(roomId);
      log('INFO', 'smartHome reportState', { roomId, state: cur?.state });
      const alexaState = stateToAlexa(cur?.state);
      log('INFO', 'smartHome reportState mapped', { roomId, originalState: cur?.state, alexaState });
      return {
        context: {
          properties: [
            {
              namespace: 'Alexa.LockController',
              name     : 'lockState',
              value    : alexaState.value,
              timeOfSample              : new Date().toISOString(),
              uncertaintyInMilliseconds : 500
            },
            {
              namespace: 'Alexa.EndpointHealth',
              name     : 'connectivity',
              value    : { value: 'OK' },
              timeOfSample              : new Date().toISOString(),
              uncertaintyInMilliseconds : 500
            }
          ]
        },
        event: {
          header : { namespace: 'Alexa', name: 'StateReport', payloadVersion: '3',
                     messageId: crypto.randomBytes(16).toString('hex'),
                     correlationToken: header.correlationToken },
          endpoint: { endpointId: roomId },
          payload : {}
        }
      };
    } catch (e) {
      log('ERROR', 'ReportState failed', { roomId, error: e.message, stack: e.stack });
      return {
        event: {
          header : { namespace: 'Alexa', name: 'ErrorResponse', payloadVersion: '3',
                     messageId: crypto.randomBytes(16).toString('hex'),
                     correlationToken: header.correlationToken },
          payload: { type: 'INTERNAL_ERROR', message: 'DB query failed' }
        }
      };
    }
  }

  /* fall-through */
  log('INFO', 'smartHome unsupported directive', { namespace, name, header, payload });
  return {
    event: {
      header : { namespace: 'Alexa', name: 'ErrorResponse', payloadVersion: '3',
                 messageId: crypto.randomBytes(16).toString('hex'),
                 correlationToken: header.correlationToken },
      payload: { type: 'INVALID_DIRECTIVE', message: `Unsupported ${namespace}.${name}` }
    }
  };
}

/* ───────── 8.  GLOBAL TRAPS ───────── */
process.on('uncaughtException',  e => log('FATAL', 'uncaught',  { msg: e.message, stack: e.stack }));
process.on('unhandledRejection', e => log('FATAL', 'unhandled', { msg: e.message, stack: e.stack }));