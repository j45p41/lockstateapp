import admin from 'firebase-admin';
import fetch from 'node-fetch';
import serviceAccount from './lockstate-e72fc-66f29588f54f.json' assert { type: "json" };

const TEST_UID = '6ue1XtW8cndXJQyHydNo86PW1p43';
const TEST_ROOM_ID = 'testRoom1';
const TEST_ROOM_NAME = 'FRONT';
const FIREBASE_PROJECT_ID = 'lockstate-e72fc';
const REGION = 'us-central1';

const ALEXA_LINK_USER_URL = `https://${REGION}-${FIREBASE_PROJECT_ID}.cloudfunctions.net/alexaLinkUser`;
const LAMBDA_URL = process.env.LAMBDA_URL || null; // If you have a direct endpoint for Lambda testing

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

// --- BEGIN: Simulate Alexa OAuth Account Linking Flow ---

// Since there's no API Gateway, we'll test the Lambda function directly
const SKILL_ID = process.env.SKILL_ID || 'M2KB1TY529INC9';
const ALEXA_REDIRECT_URL = `https://layla.amazon.com/api/skill/link/${SKILL_ID}`;

async function simulateAlexaAuthPhase1() {
  // Simulate the initial GET to /alexaAuth (Phase 1) by invoking Lambda directly
  console.log(`\n[SIM] Phase 1: GET /alexaAuth (initial, no code)`);
  
  const event = {
    path: '/alexaAuth',
    httpMethod: 'GET',
    queryStringParameters: {
      state: TEST_UID,
      redirect_uri: ALEXA_REDIRECT_URL
    }
  };
  
  const lambdaHandler = (await import('./index.mjs')).handler;
  const result = await lambdaHandler(event, {});
  console.log('[SIM] Response status:', result.statusCode);
  console.log('[SIM] Redirect Location:', result.headers?.Location);
  return { status: result.statusCode, location: result.headers?.Location };
}

async function simulateAlexaAuthPhase2() {
  // Simulate the GET to /alexaAuth with a code (Phase 2)
  console.log(`\n[SIM] Phase 2: GET /alexaAuth (with code)`);
  
  const event = {
    path: '/alexaAuth',
    httpMethod: 'GET',
    queryStringParameters: {
      state: TEST_UID,
      redirect_uri: ALEXA_REDIRECT_URL,
      code: 'AUTHCODE123'
    }
  };
  
  const lambdaHandler = (await import('./index.mjs')).handler;
  const result = await lambdaHandler(event, {});
  console.log('[SIM] Response status:', result.statusCode);
  console.log('[SIM] Redirect Location:', result.headers?.Location);
  return { status: result.statusCode, location: result.headers?.Location };
}

async function simulateAlexaTokenExchange(skillCode) {
  // Simulate Alexa POSTing to /alexaToken with the code
  console.log(`\n[SIM] Phase 3: POST /alexaToken (token exchange)`);
  
  const clientId = process.env.ALEXA_CLIENT_ID || 'amzn1.application-oa2-client.ddbcc3bfaf604d1980b699300a623698';
  const clientSecret = process.env.ALEXA_CLIENT_SECRET || 'YOUR_CLIENT_SECRET';
  const auth = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');
  const body = new URLSearchParams({
    grant_type: 'authorization_code',
    code: skillCode,
    redirect_uri: ALEXA_REDIRECT_URL
  }).toString();
  
  const event = {
    path: '/alexaToken',
    httpMethod: 'POST',
    headers: {
      'Authorization': `Basic ${auth}`,
      'Content-Type': 'application/x-www-form-urlencoded'
    },
    body: body
  };
  
  const lambdaHandler = (await import('./index.mjs')).handler;
  const result = await lambdaHandler(event, {});
  console.log('[SIM] Response status:', result.statusCode);
  console.log('[SIM] Response body:', result.body);
  
  // Handle both JSON and text responses
  let data = {};
  try {
    data = JSON.parse(result.body || '{}');
  } catch (e) {
    data = { error: result.body, raw: result.body };
  }
  
  return { status: result.statusCode, data };
}

// --- END: Simulate Alexa OAuth Account Linking Flow ---

async function ensureTestRoom() {
  const db = admin.firestore();
  const roomRef = db.collection('rooms').doc(TEST_ROOM_ID);
  const doc = await roomRef.get();
  if (!doc.exists) {
    await roomRef.set({
      userId: TEST_UID,
      name: TEST_ROOM_NAME,
      roomId: TEST_ROOM_ID,
      state: 1 // LOCKED
    });
    console.log(`[Firestore] Created test room for UID ${TEST_UID}`);
  } else {
    console.log(`[Firestore] Test room already exists for UID ${TEST_UID}`);
  }
}

async function linkAlexaUser() {
  const res = await fetch(ALEXA_LINK_USER_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ userId: TEST_UID })
  });
  const data = await res.json();
  if (res.ok) {
    console.log(`[Cloud Function] Alexa user linked:`, data);
  } else {
    console.error(`[Cloud Function] Alexa link failed:`, data);
  }
}

async function simulateAlexaDiscovery() {
  // Simulate Alexa Discovery directive
  const event = {
    directive: {
      header: {
        namespace: 'Alexa.Discovery',
        name: 'Discover',
        payloadVersion: '3',
        messageId: 'test-discovery-1'
      },
      payload: {
        scope: {
          type: 'BearerToken',
          token: TEST_UID
        }
      }
    }
  };
  const lambdaHandler = (await import('./index.mjs')).handler;
  const result = await lambdaHandler(event, {});
  console.log('[Lambda] Discovery response:', JSON.stringify(result, null, 2));
  return result;
}

async function simulateAlexaStateReport(endpointId) {
  // Simulate Alexa StateReport directive
  const event = {
    directive: {
      header: {
        namespace: 'Alexa',
        name: 'ReportState',
        payloadVersion: '3',
        messageId: 'test-state-1',
        correlationToken: 'test-correlation-1'
      },
      endpoint: {
        scope: {
          type: 'BearerToken',
          token: TEST_UID
        },
        endpointId
      },
      payload: {}
    }
  };
  const lambdaHandler = (await import('./index.mjs')).handler;
  const result = await lambdaHandler(event, {});
  console.log('[Lambda] StateReport response:', JSON.stringify(result, null, 2));
  return result;
}

async function main() {
  console.log('--- Simulating Flutter app and Alexa flow ---');
  await ensureTestRoom();
  await linkAlexaUser();
  const discovery = await simulateAlexaDiscovery();
  const endpointId = discovery?.event?.payload?.endpoints?.[0]?.endpointId;
  if (endpointId) {
    await simulateAlexaStateReport(endpointId);
  } else {
    console.error('No endpointId found in discovery response!');
  }

  // --- Simulate Alexa OAuth Account Linking Flow ---
  const phase1 = await simulateAlexaAuthPhase1();
  if (phase1.status === 302 && phase1.location) {
    // Simulate user login at Amazon, then redirect back to /alexaAuth with code
    const phase2 = await simulateAlexaAuthPhase2();
    if (phase2.status === 302 && phase2.location) {
      // Extract the code from the redirect URL (should be TEST_UID in your flow)
      const urlObj = new URL(phase2.location);
      const skillCode = urlObj.searchParams.get('code');
      if (skillCode) {
        await simulateAlexaTokenExchange(skillCode);
      } else {
        console.error('[SIM] No code found in redirect URL!');
      }
    } else {
      console.error('[SIM] Phase 2 failed:', phase2);
    }
  } else {
    console.error('[SIM] Phase 1 failed:', phase1);
  }
  process.exit(0);
}

main().catch(e => {
  console.error('Simulation failed:', e);
  process.exit(1);
}); 