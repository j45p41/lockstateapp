/**
 * Lock-sure Cloud-Functions – Alexa integration (Auth Code Grant)
 * 2025-06-30
 */
const crypto = require('crypto');
const admin = require('firebase-admin');
const https = require('https');
const { URLSearchParams } = require('url');
const serviceAccount = require('./lockstate-e72fc-66f29588f54f.json');
const querystring = require('querystring');

// Temporary storage for OAuth state (in production, use Redis or DynamoDB)
const oauthStateStorage = {};

// Simple fetch replacement using https
function fetch(url, options = {}) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    const data = options.body ? JSON.stringify(options.body) : null;
    
    const requestOptions = {
      hostname: urlObj.hostname,
      port: urlObj.port || (urlObj.protocol === 'https:' ? 443 : 80),
      path: urlObj.pathname + urlObj.search,
      method: options.method || 'GET',
      headers: {
        'Content-Type': 'application/json',
        ...options.headers
      }
    };
    
    if (data) {
      requestOptions.headers['Content-Length'] = Buffer.byteLength(data);
    }
    
    const req = https.request(requestOptions, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        resolve({
          status: res.statusCode,
          statusText: res.statusMessage,
          headers: res.headers,
          json: () => JSON.parse(body),
          text: () => body,
          ok: res.statusCode >= 200 && res.statusCode < 300
        });
      });
    });
    
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const {
  ALEXA_CLIENT_ID,
  ALEXA_CLIENT_SECRET,
  TOKEN_LOOKUP_URL,
  LWA_AUTH_URL,
  LWA_TOKEN_URL = 'https://api.amazon.com/auth/o2/token',
} = process.env;

// Import Amazon user_id lookup functions
const { getFirebaseUidFromAmazonToken, storeAmazonUserIdMapping, getAmazonUserId } = require('./amazon-uid-lookup');

const isValidUid = uid => typeof uid === 'string' && /^[A-Za-z0-9]{28}$/.test(uid);

async function uidFromAccessToken(token) {
  if (isValidUid(token)) return token;
  if (!token || !token.startsWith('Atza|')) return null;
  if (!TOKEN_LOOKUP_URL) throw new Error('TOKEN_LOOKUP_URL not set');

  let url = TOKEN_LOOKUP_URL.trim();
  if (url.endsWith('/alexaToken')) url += 'Lookup';

  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ accessToken: token })
  });

  if (!res.ok) {
    console.error('Token lookup failed', res.status, await res.text());
    throw new Error(`Token lookup failed (${res.status})`);
  }

  const { uid } = await res.json();
  if (!isValidUid(uid)) throw new Error('Invalid UID from lookup');
  return uid;
}

function mapLockState(state) {
  // Alexa only supports LOCKED and UNLOCKED for lockState
  // 1=LOCKED, 2=UNLOCKED, 3=CLOSED (treat as LOCKED), 4=OPEN (treat as UNLOCKED)
  return {
    1: { value: 'LOCKED', color: 'Cyan', icon: 'lock' },
    2: { value: 'UNLOCKED', color: 'Amber', icon: 'lock_open' },
    3: { value: 'LOCKED', color: 'Amber', icon: 'lock' },
    4: { value: 'UNLOCKED', color: 'Red', icon: 'lock_open' }
  }[state] || { value: 'Unknown', color: 'Grey', icon: 'help' };
}

// Helper function to get Firebase UID by Amazon user_id
async function getFirebaseUidByAmazonUserId(amazonUserId) {
  try {
    console.log('🔍 Searching for Firebase UID with Amazon user_id:', amazonUserId);
    
    // Query Firestore for user document with matching amazonUserId
    const usersRef = admin.firestore().collection('users');
    const querySnapshot = await usersRef.where('amazonUserId', '==', amazonUserId).get();
    
    if (!querySnapshot.empty) {
      const userDoc = querySnapshot.docs[0];
      const firebaseUid = userDoc.id;
      console.log('✅ Found Firebase UID:', firebaseUid, 'for Amazon user_id:', amazonUserId);
      return firebaseUid;
    } else {
      console.log('❌ No user found with Amazon user_id:', amazonUserId);
      return null;
    }
  } catch (error) {
    console.log('❌ Error finding Firebase UID by Amazon user_id:', error.message);
    throw error;
  }
}

exports.handler = async function(event, context) {
  // ULTRA-VERBOSE LOGGING AT THE TOP
  console.log('=== LAMBDA INVOCATION START ===', new Date().toISOString());
  console.log('EVENT:', JSON.stringify(event, null, 2));
  console.log('CONTEXT:', JSON.stringify(context, null, 2));

  // --- COLD START & ENV LOGGING ---
  console.log('=== LAMBDA COLD START ===');
  console.log('ENV:', JSON.stringify({
    ALEXA_CLIENT_ID: process.env.ALEXA_CLIENT_ID,
    ALEXA_CLIENT_SECRET: process.env.ALEXA_CLIENT_SECRET,
    TOKEN_LOOKUP_URL: process.env.TOKEN_LOOKUP_URL,
    LWA_AUTH_URL: process.env.LWA_AUTH_URL,
    LWA_TOKEN_URL: process.env.LWA_TOKEN_URL,
    NODE_ENV: process.env.NODE_ENV
  }, null, 2));
  
  // COMPREHENSIVE REQUEST LOGGING
  console.log('=== LAMBDA REQUEST START ===');
  console.log('Event:', JSON.stringify(event, null, 2));
  console.log('Context:', JSON.stringify(context, null, 2));
  
  // Check if this is a direct Alexa Smart Home directive first
  if (event.directive) {
    console.log('=== ALEXA SMART HOME DIRECTIVE DETECTED ===');
    const directive = event.directive;
    const header = directive.header || {};
    const endpoint = directive.endpoint || {};
    const scope = endpoint.scope || {};
    const token = scope.token;
    
    let firebaseUid;
    if (token) {
      try {
        // Get Amazon user_id from the access token
        const amazonUserId = await getAmazonUserId(token);
        console.log('🔍 Amazon user_id from token:', amazonUserId);
        
        // Look up Firebase UID by Amazon user_id in Firestore
        firebaseUid = await getFirebaseUidByAmazonUserId(amazonUserId);
        console.log('🔍 Firebase UID from Firestore:', firebaseUid);
        
        if (!firebaseUid) {
          console.error('❌ No Firebase UID found for Amazon user_id:', amazonUserId);
          return {
            statusCode: 400,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ 
              error: 'user_not_found', 
              message: 'User not found in Firestore. Please link your account first.' 
            })
          };
        }
      } catch (error) {
        console.error('❌ Error getting Firebase UID:', error);
        return {
          statusCode: 500,
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ 
            error: 'internal_error', 
            message: 'Error retrieving user information' 
          })
        };
      }
    } else {
      console.error('❌ No access token provided in directive');
      return {
        statusCode: 400,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          error: 'missing_token', 
          message: 'Access token is required' 
        })
      };
    }
    
    console.log('✅ Using Firebase UID for device queries:', firebaseUid);
    
    // Discovery
    if (header.namespace === 'Alexa.Discovery' && header.name === 'Discover') {
      console.log('=== HANDLING DISCOVERY REQUEST ===');
      console.log('DEPLOYMENT TEST 2025-07-01 22:00 UTC'); // Unique log for deployment verification
      console.log('Looking for rooms with userId:', firebaseUid);
      
      try {
        // Query Firestore for rooms for this user
        const snap = await admin.firestore().collection('rooms').where('userId', '==', firebaseUid).limit(8).get();
        console.log('Firestore query result - docs found:', snap.docs.length);
        if (snap.docs.length === 0) {
          console.log('No rooms found for UID:', firebaseUid);
        } else {
          snap.docs.forEach(doc => {
            console.log('Room found:', { id: doc.id, ...doc.data() });
          });
        }
        
        let rooms = snap.docs.map(d => {
          const data = d.data();
          console.log('Room data:', { id: d.id, ...data });
          return { id: d.id, ...data };
        });
        
        // Sort: FRONT first, then others
        rooms.sort((a, b) => (a.name === 'FRONT' ? -1 : b.name === 'FRONT' ? 1 : 0));
        console.log('Sorted rooms:', rooms.map(r => r.name));
        
        const endpoints = rooms.map(room => ({
          endpointId: room.roomId || room.id,
          manufacturerName: 'Locksure',
          friendlyName: room.name || room.roomId || room.id,
          description: 'Locksure Door',
          displayCategories: ['SMARTLOCK'],
          cookie: {},
          capabilities: [
            {
              type: 'AlexaInterface',
              interface: 'Alexa',
              version: '3'
            },
            {
              type: 'AlexaInterface',
              interface: 'Alexa.LockController',
              version: '3',
              properties: {
                supported: [{ name: 'lockState' }],
                retrievable: true,
                proactivelyReported: false
              }
            },
            {
              type: 'AlexaInterface',
              interface: 'Alexa.ContactSensor',
              version: '3',
              properties: {
                supported: [{ name: 'detectionState' }],
                retrievable: true,
                proactivelyReported: false
              }
            },
            {
              type: 'AlexaInterface',
              interface: 'Alexa.EndpointHealth',
              version: '3',
              properties: {
                supported: [{ name: 'connectivity' }],
                retrievable: true,
                proactivelyReported: false
              }
            }
          ]
        }));
        
        console.log('Generated endpoints:', endpoints.length);
        console.log('Endpoint IDs:', endpoints.map(e => e.endpointId));
        
        const response = {
          event: {
            header: {
              namespace: 'Alexa.Discovery',
              name: 'Discover.Response',
              payloadVersion: '3',
              messageId: header.messageId || crypto.randomUUID()
            },
            payload: { endpoints }
          }
        };
        
        console.log('Discovery response:', JSON.stringify(response, null, 2));
        
        return response;
        
      } catch (error) {
        console.error('Error during discovery:', error);
        return {
          event: {
            header: {
              namespace: 'Alexa',
              name: 'ErrorResponse',
              payloadVersion: '3',
              messageId: header.messageId || crypto.randomUUID()
            },
            payload: {
              type: 'INTERNAL_ERROR',
              message: 'Discovery failed'
            }
          }
        };
      }
    }
    
    // State Report
    if (header.namespace === 'Alexa' && header.name === 'ReportState') {
      console.log('=== HANDLING STATE REPORT REQUEST ===');
      const endpointId = endpoint.endpointId;
      console.log('Requesting state for room:', endpointId);
      
      try {
        // Query Firestore for the specific room
        const roomDoc = await admin.firestore().collection('rooms').doc(endpointId).get();
        
        if (roomDoc.exists) {
          const roomData = roomDoc.data();
          console.log('Room data:', roomData);
          
          // Verify the room belongs to the correct user
          if (roomData.userId !== firebaseUid) {
            console.log('❌ Room does not belong to user. Room userId:', roomData.userId, 'Expected:', firebaseUid);
            return {
              statusCode: 403,
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ error: 'forbidden' })
            };
          }
          
          // Map state values
          const stateMapping = {
            0: { value: 'UNLOCKED', color: 'Green', icon: 'unlock' },
            1: { value: 'LOCKED', color: 'Cyan', icon: 'lock' }
          };
          
          const mappedState = stateMapping[roomData.state] || { value: 'UNLOCKED', color: 'Green', icon: 'unlock' };
          console.log('Mapped state:', mappedState);
          
          const response = {
            context: {
              properties: [
                {
                  namespace: 'Alexa.LockController',
                  name: 'lockState',
                  value: mappedState.value,
                  timeOfSample: new Date().toISOString(),
                  uncertaintyInMilliseconds: 500
                },
                {
                  namespace: 'Alexa.ContactSensor',
                  name: 'detectionState',
                  value: mappedState.value === 'LOCKED' ? 'DETECTED' : 'NOT_DETECTED',
                  timeOfSample: new Date().toISOString(),
                  uncertaintyInMilliseconds: 500
                },
                {
                  namespace: 'Alexa.EndpointHealth',
                  name: 'connectivity',
                  value: 'OK',
                  timeOfSample: new Date().toISOString(),
                  uncertaintyInMilliseconds: 500
                }
              ]
            },
            event: {
              header: {
                namespace: 'Alexa',
                name: 'StateReport',
                payloadVersion: '3',
                messageId: header.messageId,
                correlationToken: header.correlationToken
              },
              endpoint: {
                endpointId: endpointId
              },
              payload: {}
            }
          };
          
          console.log('State report response:', JSON.stringify(response, null, 2));
          
          return {
            statusCode: 200,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(response)
          };
        } else {
          console.log('❌ Room not found:', endpointId);
          return {
            statusCode: 404,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ error: 'not_found' })
          };
        }
      } catch (error) {
        console.log('❌ Error getting room state:', error.message);
        return {
          statusCode: 500,
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ error: 'internal_error' })
        };
      }
    }
    
    // Add more Alexa directives as needed
    console.log('Unhandled Alexa directive:', header.namespace, header.name);
    return {
      event: {
        header: {
          namespace: 'Alexa',
          name: 'ErrorResponse',
          payloadVersion: '3',
          messageId: header.messageId || crypto.randomUUID()
        },
        payload: {
          type: 'INVALID_DIRECTIVE',
          message: 'Directive not implemented'
        }
      }
    };
  }
  
  // --- LOG ALL EVENTS FOR DEBUGGING ---
  console.log('No Alexa directive matched. Event:', JSON.stringify(event, null, 2));
  
  // Support both REST API and HTTP API Gateway event formats
  const path = event.path || event.rawPath;
  const httpMethod = event.httpMethod || (event.requestContext && event.requestContext.http && event.requestContext.http.method);
  const queryStringParameters = event.queryStringParameters || (event.rawQueryString
    ? Object.fromEntries(new URLSearchParams(event.rawQueryString))
    : {});
  const { body, headers } = event;

  console.log('=== PARSED REQUEST ===');
  console.log('PATH:', path);
  console.log('METHOD:', httpMethod);
  console.log('QUERY:', queryStringParameters);
  console.log('HEADERS:', headers);
  console.log('BODY:', body);
  console.log('BODY TYPE:', typeof body);
  console.log('BODY LENGTH:', body ? body.length : 0);

  // Log before each handler check
  console.log('=== CHECKING HANDLERS ===');
  console.log('Checking /alexaAuth:', path && path.replace(/\/+$/, '').endsWith('/alexaAuth') && httpMethod === 'GET');
  console.log('Checking /alexaToken:', path && path.endsWith('/alexaToken') && httpMethod === 'POST');
  console.log('Checking /alexaSmartHome:', path && path.endsWith('/alexaSmartHome') && httpMethod === 'POST');

  // --- Test endpoint to show user ID and check Firestore ---
  if (path && path.endsWith('/test') && httpMethod === 'GET') {
    console.log('=== TEST ENDPOINT CALLED ===');
    
    // Get the user ID from query params or use a test one
    const testUid = queryStringParameters?.uid || 'amzn1.account.AFWVA2IJ7K4GCTSY6DVJNPVSTW5A';
    console.log('Testing with UID:', testUid);
    
    try {
      // Check if this user has any rooms in Firestore
      const snap = await admin.firestore().collection('rooms').where('userId', '==', testUid).get();
      console.log('Firestore query result - docs found:', snap.docs.length);
      
      const rooms = snap.docs.map(d => {
        const data = d.data();
        return { id: d.id, ...data };
      });
      
      console.log('Rooms found:', rooms);
      
      return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          testUid,
          roomsFound: snap.docs.length,
          rooms: rooms,
          message: 'Test completed successfully'
        })
      };
    } catch (error) {
      console.error('Test endpoint error:', error);
      return {
        statusCode: 500,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ error: error.message })
      };
    }
  }

  // --- /alexaAuth (GET) ---
  if (path && path.replace(/\/+$/, '').endsWith('/alexaAuth') && httpMethod === 'GET') {
    console.log('=== /alexaAuth called: OAuth is DISABLED ===');
    return {
      statusCode: 400,
      body: 'OAuth is disabled. Please link your account via the app.'
    };
  }

  // --- /alexaToken (POST) ---
  if (path && path.replace(/\/+$/, '').endsWith('/alexaToken') && httpMethod === 'POST') {
    console.log('=== /alexaToken called: OAuth is DISABLED ===');
    return {
      statusCode: 400,
      body: 'OAuth is disabled. Please link your account via the app.'
    };
  }

  // --- /alexaSmartHome (POST) ---
  if (path && path.endsWith('/alexaSmartHome') && httpMethod === 'POST') {
    let directive;
    try {
      directive = JSON.parse(body || '{}');
    } catch (e) {
      return { statusCode: 400, body: 'Invalid JSON' };
    }
    const header = directive.directive?.header || {};
    const endpoint = directive.directive?.endpoint || {};
    const payload = directive.directive?.payload || {};
    const uid = endpoint.scope?.token || payload.scope?.token;
    if (!isValidUid(uid)) {
      return { statusCode: 401, body: JSON.stringify({ error: 'invalid_grant' }) };
    }
    // Discovery
    if (header.namespace === 'Alexa.Discovery' && header.name === 'Discover') {
      // Query Firestore for rooms for this user
      const snap = await admin.firestore().collection('rooms').where('userId', '==', uid).limit(8).get();
      let rooms = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      rooms.sort((a, b) => (a.name === 'FRONT' ? -1 : b.name === 'FRONT' ? 1 : 0));
      const endpoints = rooms.map(room => ({
        endpointId: room.roomId || room.id,
        manufacturerName: 'Locksure',
        friendlyName: room.name || room.roomId || room.id,
        description: 'Locksure Door',
        displayCategories: ['SMARTLOCK'],
        cookie: {},
        capabilities: [
          { type: 'AlexaInterface', interface: 'Alexa', version: '3' },
          { type: 'AlexaInterface', interface: 'Alexa.LockController', version: '3', properties: { supported: [{ name: 'lockState' }], retrievable: true, proactivelyReported: false } },
          { type: 'AlexaInterface', interface: 'Alexa.ContactSensor', version: '3', properties: { supported: [{ name: 'detectionState' }], retrievable: true, proactivelyReported: false } },
          { type: 'AlexaInterface', interface: 'Alexa.EndpointHealth', version: '3', properties: { supported: [{ name: 'connectivity' }], retrievable: true, proactivelyReported: false } }
        ]
      }));
      const response = {
        event: {
          header: {
            namespace: 'Alexa.Discovery',
            name: 'Discover.Response',
            payloadVersion: '3',
            messageId: header.messageId || crypto.randomUUID()
          },
          payload: { endpoints }
        }
      };
      return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(response)
      };
    }
    // State Report (for lock status)
    if (header.namespace === 'Alexa.LockController' && header.name === 'ReportState') {
      const roomId = endpoint.endpointId;
      const snap = await admin.firestore().doc(`rooms/${roomId}`).get();
      if (!snap.exists) {
        return { statusCode: 404, body: 'Room not found' };
      }
      const room = snap.data();
      const state = mapLockState(room.state);
      // Map contact sensor state
      // 1,2,3 = CLOSED; 4 = OPEN
      let contactSensorState = 'DETECTED'; // CLOSED
      if (room.state === 4) contactSensorState = 'NOT_DETECTED'; // OPEN
      return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          context: {
            properties: [
              {
                namespace: 'Alexa.LockController',
                name: 'lockState',
                value: state.value,
                timeOfSample: new Date().toISOString(),
                uncertaintyInMilliseconds: 500
              },
              {
                namespace: 'Alexa.ContactSensor',
                name: 'detectionState',
                value: contactSensorState,
                timeOfSample: new Date().toISOString(),
                uncertaintyInMilliseconds: 500
              },
              {
                namespace: 'Alexa.EndpointHealth',
                name: 'connectivity',
                value: 'OK',
                timeOfSample: new Date().toISOString(),
                uncertaintyInMilliseconds: 500
              }
            ]
          },
          event: {
            header: {
              namespace: 'Alexa',
              name: 'StateReport',
              payloadVersion: '3',
              messageId: header.messageId || crypto.randomUUID(),
              correlationToken: header.correlationToken
            },
            endpoint: { endpointId: roomId },
            payload: {}
          }
        })
      };
    }
    // Add more Alexa directives as needed
    return { statusCode: 501, body: 'Not implemented' };
  }

  // --- Not found ---
  console.log('No handler matched for path:', path, 'method:', httpMethod);
  return {
    statusCode: 404,
    body: 'Not found'
  };
}