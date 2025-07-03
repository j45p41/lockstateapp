/**
 * Lock-sure Cloud-Functions – Alexa integration (Auth Code Grant)
 * 2025-06-30
 */
import crypto from 'crypto';
import admin from 'firebase-admin';
import fetch from 'node-fetch';
import { URLSearchParams } from 'url';
import serviceAccount from './lockstate-e72fc-66f29588f54f.json' with { type: "json" };

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const {
  ALEXA_CLIENT_ID,
  ALEXA_CLIENT_SECRET,
  TOKEN_LOOKUP_URL,
  LWA_AUTH_URL,
  LWA_TOKEN_URL = 'https://api.amazon.com/auth/o2/token',
} = process.env;

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
  // 1=LOCKED (Cyan), 2=UNLOCKED (Amber), 3=CLOSED (Amber), 4=OPEN (Red)
  return {
    1: { value: 'LOCKED', color: 'Cyan', icon: 'lock' },
    2: { value: 'UNLOCKED', color: 'Amber', icon: 'lock_open' },
    3: { value: 'CLOSED', color: 'Amber', icon: 'lock' },
    4: { value: 'OPEN', color: 'Red', icon: 'lock_open' }
  }[state] || { value: 'Unknown', color: 'Grey', icon: 'help' };
}

export async function handler(event, context) {
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
    console.log('Directive:', JSON.stringify(event.directive, null, 2));
    
    const directive = event.directive;
    const header = directive.header || {};
    const endpoint = directive.endpoint || {};
    const payload = directive.payload || {};
    
    console.log('Header namespace:', header.namespace);
    console.log('Header name:', header.name);
    console.log('Payload scope:', payload.scope);
    
    // Extract user ID from the scope token
    const uid = payload.scope?.token || endpoint.scope?.token;
    console.log('Extracted UID from scope:', uid);

    // Use hardcoded test UID for device discovery
    let actualUid = '6ue1XtW8cndXJQyHydNo86PW1p43';
    console.log('Using test UID for discovery:', actualUid);
    
    // Discovery
    if (header.namespace === 'Alexa.Discovery' && header.name === 'Discover') {
      console.log('=== HANDLING DISCOVERY REQUEST ===');
      console.log('Looking for rooms with userId:', actualUid);
      try {
        // Query Firestore for rooms for this user
        const snap = await admin.firestore().collection('rooms').where('userId', '==', actualUid).limit(8).get();
        console.log('Firestore query result - docs found:', snap.docs.length);
        if (snap.docs.length === 0) {
          console.log('No rooms found for UID:', actualUid);
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
    
    // State Report (for lock status)
    if ((header.namespace === 'Alexa.LockController' && header.name === 'ReportState') ||
        (header.namespace === 'Alexa' && header.name === 'ReportState')) {
      console.log('=== HANDLING STATE REPORT REQUEST ===');
      const roomId = endpoint.endpointId;
      console.log('Requesting state for room:', roomId);
      
      try {
        const snap = await admin.firestore().doc(`rooms/${roomId}`).get();
        if (!snap.exists) {
          console.log('Room not found:', roomId);
          return { 
            event: {
              header: {
                namespace: 'Alexa',
                name: 'ErrorResponse',
                payloadVersion: '3',
                messageId: header.messageId || crypto.randomUUID(),
                correlationToken: header.correlationToken
              },
              payload: {
                type: 'NO_SUCH_ENDPOINT',
                message: 'Room not found'
              },
              endpoint: { endpointId: roomId }
            }
          };
        }
        
        const room = snap.data();
        console.log('Room data:', room);
        const state = mapLockState(room.state);
        console.log('Mapped state:', state);
        
        const response = {
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
        };
        
        console.log('State report response:', JSON.stringify(response, null, 2));
        
        return response;
        
      } catch (error) {
        console.error('Error during state report:', error);
        return {
          event: {
            header: {
              namespace: 'Alexa',
              name: 'ErrorResponse',
              payloadVersion: '3',
              messageId: header.messageId || crypto.randomUUID(),
              correlationToken: header.correlationToken
            },
            payload: {
              type: 'INTERNAL_ERROR',
              message: 'State report failed'
            },
            endpoint: { endpointId: roomId }
          }
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
    console.log('=== /alexaAuth branch entered ===');
    const { redirect_uri } = queryStringParameters || {};
    // Use the incoming state parameter
    const state = queryStringParameters.state || crypto.randomUUID();
    console.log('Using state for authorization:', state);
    // PHASE 1: Redirect to Amazon for authorization
    if (!queryStringParameters.code) {
      if (!redirect_uri) {
        console.log('Missing redirect_uri');
        return { statusCode: 400, body: 'Missing redirect_uri' };
      }
      const params = new URLSearchParams({
        client_id: ALEXA_CLIENT_ID,
        scope: 'profile',
        response_type: 'code',
        redirect_uri,
        state
      });
      console.log('Redirecting to LWA with params:', params.toString());
      return {
        statusCode: 302,
        headers: { Location: `${LWA_AUTH_URL}?${params}` },
        body: ''
      };
    }
    // PHASE 2: Amazon redirected back with authorization code
    const dest = new URL(redirect_uri);
    dest.searchParams.set('code', queryStringParameters.code);
    dest.searchParams.set('state', state);
    console.log('Redirecting to:', dest.toString());
    return {
      statusCode: 302,
      headers: { Location: dest.toString() },
      body: ''
    };
  }

  // --- /alexaToken (POST) ---
  if (path && path.endsWith('/alexaToken') && httpMethod === 'POST') {
    console.log('=== /alexaToken branch entered ===');
    let parsedBody = {};
    let bodyToParse = body;
    if (event.isBase64Encoded && body) {
      bodyToParse = Buffer.from(body, 'base64').toString('utf-8');
    }
    // Robust content-type header handling
    const contentType = (headers['content-type'] || headers['Content-Type'] || '').toLowerCase();
    if (contentType.includes('application/json')) {
      parsedBody = JSON.parse(bodyToParse || '{}');
    } else if (contentType.includes('application/x-www-form-urlencoded')) {
      parsedBody = Object.fromEntries(new URLSearchParams(bodyToParse || ''));
    } else {
      try {
        parsedBody = JSON.parse(bodyToParse || '{}');
      } catch (e) {
        parsedBody = {};
      }
    }
    console.log('Parsed body:', parsedBody);
    const authHeader = headers['authorization'] || headers['Authorization'];
    if (!authHeader) {
      console.error('Missing Authorization header');
      return {
        statusCode: 401,
        body: JSON.stringify({ error: 'Missing Authorization header' })
      };
    }
    // Prepare POST to Amazon LWA
    const params = new URLSearchParams({
      grant_type: parsedBody['grant_type'],
      code: parsedBody['code'],
      redirect_uri: parsedBody['redirect_uri'],
      client_id: process.env.ALEXA_CLIENT_ID,
      client_secret: process.env.ALEXA_CLIENT_SECRET
    });
    console.log('POST data to Amazon:', params.toString());
    const fetch = (await import('node-fetch')).default;
    let amazonResponse;
    try {
      const res = await fetch('https://api.amazon.com/auth/o2/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: params.toString()
      });
      amazonResponse = await res.json();
      console.log('Amazon LWA response:', amazonResponse);
      return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(amazonResponse)
      };
    } catch (err) {
      console.error('Error exchanging code with Amazon:', err);
      return {
        statusCode: 500,
        body: JSON.stringify({ error: 'Token exchange failed', details: err.toString() })
      };
    }
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