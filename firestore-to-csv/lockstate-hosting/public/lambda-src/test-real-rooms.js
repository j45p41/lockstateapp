import admin from 'firebase-admin';
import serviceAccount from './lockstate-e72fc-66f29588f54f.json' assert { type: "json" };

const TEST_UID = '6ue1XtW8cndXJQyHydNo86PW1p43';
const FIREBASE_PROJECT_ID = 'lockstate-e72fc';
const REGION = 'us-central1';

const ALEXA_LINK_USER_URL = `https://${REGION}-${FIREBASE_PROJECT_ID}.cloudfunctions.net/alexaLinkUser`;

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

async function checkExistingRooms() {
  const db = admin.firestore();
  console.log(`\n=== CHECKING EXISTING ROOMS FOR UID: ${TEST_UID} ===`);
  
  const snap = await db.collection('rooms').where('userId', '==', TEST_UID).get();
  console.log(`Found ${snap.docs.length} rooms for this user:`);
  
  const rooms = [];
  snap.docs.forEach(doc => {
    const data = doc.data();
    rooms.push({
      id: doc.id,
      ...data
    });
    console.log(`- Room ID: ${doc.id}`);
    console.log(`  Name: ${data.name || 'Unknown'}`);
    console.log(`  State: ${data.state || 'Unknown'}`);
    console.log(`  RoomId: ${data.roomId || 'None'}`);
    console.log(`  UserId: ${data.userId}`);
    console.log('');
  });
  
  return rooms;
}

async function testAlexaDiscoveryWithRealRooms() {
  console.log('\n=== TESTING ALEXA DISCOVERY WITH REAL ROOMS ===');
  
  // Simulate Alexa Discovery directive
  const event = {
    directive: {
      header: {
        namespace: 'Alexa.Discovery',
        name: 'Discover',
        payloadVersion: '3',
        messageId: 'test-discovery-real-rooms'
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
  
  console.log('Discovery response:');
  console.log(JSON.stringify(result, null, 2));
  
  const endpoints = result?.event?.payload?.endpoints || [];
  console.log(`\nDiscovered ${endpoints.length} endpoints:`);
  endpoints.forEach((endpoint, index) => {
    console.log(`${index + 1}. ${endpoint.friendlyName} (${endpoint.endpointId})`);
  });
  
  return endpoints;
}

async function testStateReportForRealRooms(endpoints) {
  console.log('\n=== TESTING STATE REPORT FOR REAL ROOMS ===');
  
  for (const endpoint of endpoints) {
    console.log(`\nTesting state report for: ${endpoint.friendlyName} (${endpoint.endpointId})`);
    
    const event = {
      directive: {
        header: {
          namespace: 'Alexa',
          name: 'ReportState',
          payloadVersion: '3',
          messageId: `test-state-${endpoint.endpointId}`,
          correlationToken: `test-correlation-${endpoint.endpointId}`
        },
        endpoint: {
          scope: {
            type: 'BearerToken',
            token: TEST_UID
          },
          endpointId: endpoint.endpointId
        },
        payload: {}
      }
    };
    
    const lambdaHandler = (await import('./index.mjs')).handler;
    const result = await lambdaHandler(event, {});
    
    const lockState = result?.context?.properties?.find(p => p.namespace === 'Alexa.LockController' && p.name === 'lockState');
    console.log(`State: ${lockState?.value || 'Unknown'}`);
  }
}

async function linkAlexaUser() {
  console.log('\n=== LINKING ALEXA USER ===');
  try {
    const res = await fetch(ALEXA_LINK_USER_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ userId: TEST_UID })
    });
    const data = await res.json();
    if (res.ok) {
      console.log('✅ Alexa user linked successfully:', data);
    } else {
      console.error('❌ Alexa link failed:', data);
    }
  } catch (error) {
    console.error('❌ Error linking Alexa user:', error.message);
  }
}

async function main() {
  console.log('=== TESTING REAL ROOMS FLOW ===');
  
  // Check what rooms exist
  const existingRooms = await checkExistingRooms();
  
  if (existingRooms.length === 0) {
    console.log('\n❌ No rooms found for this user. Cannot test Alexa flow.');
    console.log('Please ensure the user has at least one working room in Firestore.');
    process.exit(1);
  }
  
  // Link Alexa user
  await linkAlexaUser();
  
  // Test discovery with real rooms
  const discoveredEndpoints = await testAlexaDiscoveryWithRealRooms();
  
  if (discoveredEndpoints.length === 0) {
    console.log('\n❌ No endpoints discovered. Check Lambda logs for errors.');
    process.exit(1);
  }
  
  // Test state report for each discovered endpoint
  await testStateReportForRealRooms(discoveredEndpoints);
  
  console.log('\n✅ Real rooms flow test completed successfully!');
  console.log(`Found ${existingRooms.length} real rooms, discovered ${discoveredEndpoints.length} endpoints.`);
  
  process.exit(0);
}

main().catch(e => {
  console.error('❌ Test failed:', e);
  process.exit(1);
}); 