const https = require('https');
const querystring = require('querystring');
const crypto = require('crypto');

// Environment variables
const ALEXA_CLIENT_ID = process.env.ALEXA_CLIENT_ID;
const ALEXA_CLIENT_SECRET = process.env.ALEXA_CLIENT_SECRET;
const LWA_AUTH_URL = process.env.LWA_AUTH_URL || 'https://www.amazon.com/ap/oa';
const LWA_TOKEN_URL = process.env.LWA_TOKEN_URL || 'https://api.amazon.com/auth/o2/token';

// Simple fetch implementation for Node.js
function fetch(url, options = {}) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    const req = https.request(urlObj, options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        resolve({
          ok: res.statusCode >= 200 && res.statusCode < 300,
          status: res.statusCode,
          statusText: res.statusMessage,
          text: () => Promise.resolve(data),
          json: () => Promise.resolve(JSON.parse(data))
        });
      });
    });
    req.on('error', reject);
    if (options.body) {
      req.write(options.body);
    }
    req.end();
  });
}

// Helper function to extract UID from access token
async function uidFromAccessToken(token) {
  try {
    const response = await fetch('https://api.amazon.com/user/profile', {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    if (response.ok) {
      const data = await response.json();
      return data.user_id;
    }
  } catch (e) {
    console.error('Error getting UID from token:', e);
  }
  return null;
}

// Helper function to map lock state
function mapLockState(state) {
  switch (state) {
    case 1: return 'LOCKED';
    case 2: return 'LOCKED';
    case 3: return 'LOCKED';
    case 4: return 'UNLOCKED';
    default: return 'LOCKED';
  }
}

// Helper function to validate UID
function isValidUid(uid) {
  return uid && typeof uid === 'string' && uid.length > 0;
}

exports.handler = async function(event, context) {
  console.log('=== LAMBDA COLD START ===');
  console.log('ENV:', {
    ALEXA_CLIENT_ID: process.env.ALEXA_CLIENT_ID,
    ALEXA_CLIENT_SECRET: process.env.ALEXA_CLIENT_SECRET,
    LWA_AUTH_URL: process.env.LWA_AUTH_URL,
    LWA_TOKEN_URL: process.env.LWA_TOKEN_URL
  });
  
  console.log('=== LAMBDA REQUEST START ===');
  console.log('Event:', JSON.stringify(event, null, 2));
  console.log('Context:', JSON.stringify(context, null, 2));

  try {
    const { path, httpMethod, headers, queryStringParameters, body, multiValueHeaders, multiValueQueryStringParameters } = event;
    
    console.log('=== PARSED REQUEST ===');
    console.log('PATH:', path);
    console.log('METHOD:', httpMethod);
    console.log('QUERY:', queryStringParameters);
    console.log('HEADERS:', headers);
    console.log('BODY:', body);
    console.log('BODY TYPE:', typeof body);
    console.log('BODY LENGTH:', body ? body.length : 0);

    console.log('=== CHECKING HANDLERS ===');
    console.log('Checking /alexaAuth:', path && path.replace(/\/+$/, '').endsWith('/alexaAuth') && httpMethod === 'GET');
    console.log('Checking /alexaToken:', path && path.endsWith('/alexaToken') && httpMethod === 'POST');
    console.log('Checking /alexaSmartHome:', path && path.endsWith('/alexaSmartHome') && httpMethod === 'POST');

    // --- /alexaAuth (GET) ---
    if (path && path.replace(/\/+$/, '').endsWith('/alexaAuth') && httpMethod === 'GET') {
      console.log('=== /alexaAuth branch entered ===');
      const { redirect_uri, state, code: authCode } = queryStringParameters || {};
      console.log('redirect_uri:', redirect_uri);
      console.log('state:', state);
      console.log('authCode:', authCode);
      console.log('authCode exists:', !!authCode);

      if (!authCode) {
        console.log('=== PHASE 1: Redirecting to Amazon ===');
        if (!redirect_uri || !state) {
          console.log('Missing redirect_uri or state');
          return { statusCode: 400, body: 'Missing redirect_uri or state' };
        }
        // Phase 1: Redirect to Amazon for authorization
        // Use the incoming state parameter (not hardcoded)
        const params = new URLSearchParams({
          client_id: ALEXA_CLIENT_ID,
          scope: 'profile',
          response_type: 'code',
          redirect_uri,
          state: state  // Use the incoming state parameter
        });
        console.log('Redirecting to LWA with params:', params.toString());
        return {
          statusCode: 302,
          headers: { Location: `${LWA_AUTH_URL}?${params}` },
          body: ''
        };
      }
      // PHASE 2: Amazon redirected back with authorization code
      console.log('=== PHASE 2: Amazon redirected back with code ===');
      // Just redirect back to Alexa with the skill code (no Firestore write)
      const skillCode = state; // Use the Firebase UID as the code
      const dest = new URL(redirect_uri);
      dest.searchParams.set('code', skillCode);
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
      console.log('=== /alexaToken handler entered ===');
      try {
        const headers = event.headers || {};
        const body = event.body;
        console.log('BODY:', body);
        
        let params = {};
        if (typeof body === 'string' && body.length > 0) {
          body.split('&').forEach(pair => {
            const [k, v] = pair.split('=');
            params[decodeURIComponent(k)] = decodeURIComponent(v || '');
          });
        }
        console.log('PARSED PARAMS:', params);
        
        const authHeader = headers['authorization'] || headers['Authorization'];
        console.log('AUTHORIZATION HEADER:', authHeader);
        
        if (!authHeader) {
          console.error('Missing Authorization header');
          return {
            statusCode: 401,
            body: JSON.stringify({ error: 'Missing Authorization header' })
          };
        }
        
        // Validate required parameters
        if (!params.grant_type || !params.code || !params.redirect_uri) {
          console.error('Missing required parameters:', params);
          return {
            statusCode: 400,
            body: JSON.stringify({ error: 'Missing required parameters' })
          };
        }
        
        console.log('Making real token exchange request to Amazon LWA...');
        
        // Make actual request to Amazon LWA token endpoint
        const tokenResponse = await fetch(LWA_TOKEN_URL, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Authorization': authHeader
          },
          body: new URLSearchParams({
            grant_type: params.grant_type,
            code: params.code,
            redirect_uri: params.redirect_uri
          }).toString()
        });
        
        console.log('Amazon LWA response status:', tokenResponse.status);
        const tokenData = await tokenResponse.text();
        console.log('Amazon LWA response body:', tokenData);
        
        if (tokenResponse.ok) {
          // Success - return the token data as-is
          return {
            statusCode: 200,
            headers: {
              'Content-Type': 'application/json'
            },
            body: tokenData
          };
        } else {
          // Amazon returned an error
          console.error('Amazon LWA error:', tokenResponse.status, tokenData);
          return {
            statusCode: tokenResponse.status,
            headers: {
              'Content-Type': 'application/json'
            },
            body: tokenData
          };
        }
        
      } catch (err) {
        console.error('ERROR in /alexaToken:', err);
        return {
          statusCode: 500,
          body: JSON.stringify({ error: 'Internal server error', details: err.message })
        };
      }
    }

    // --- /alexaSmartHome (POST) ---
    if (path && path.endsWith('/alexaSmartHome') && httpMethod === 'POST') {
      console.log('=== /alexaSmartHome handler entered ===');
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
                  value: state,
                  timeOfSample: new Date().toISOString(),
                  uncertaintyInMilliseconds: 0
                },
                {
                  namespace: 'Alexa.ContactSensor',
                  name: 'detectionState',
                  value: contactSensorState,
                  timeOfSample: new Date().toISOString(),
                  uncertaintyInMilliseconds: 0
                },
                {
                  namespace: 'Alexa.EndpointHealth',
                  name: 'connectivity',
                  value: { value: 'OK' },
                  timeOfSample: new Date().toISOString(),
                  uncertaintyInMilliseconds: 0
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
              endpoint: {
                scope: { type: 'BearerToken', token: uid },
                endpointId: roomId
              },
              payload: {}
            }
          })
        };
      }
      // Control
      if (header.namespace === 'Alexa.LockController' && header.name === 'Lock') {
        const roomId = endpoint.endpointId;
        // Update Firestore
        await admin.firestore().doc(`rooms/${roomId}`).update({
          state: 1, // LOCKED
          lastUpdated: new Date()
        });
        return {
          statusCode: 200,
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            context: {
              properties: [
                {
                  namespace: 'Alexa.LockController',
                  name: 'lockState',
                  value: 'LOCKED',
                  timeOfSample: new Date().toISOString(),
                  uncertaintyInMilliseconds: 0
                }
              ]
            },
            event: {
              header: {
                namespace: 'Alexa',
                name: 'Response',
                payloadVersion: '3',
                messageId: header.messageId || crypto.randomUUID(),
                correlationToken: header.correlationToken
              },
              endpoint: {
                scope: { type: 'BearerToken', token: uid },
                endpointId: roomId
              },
              payload: {}
            }
          })
        };
      }
      if (header.namespace === 'Alexa.LockController' && header.name === 'Unlock') {
        const roomId = endpoint.endpointId;
        // Update Firestore
        await admin.firestore().doc(`rooms/${roomId}`).update({
          state: 4, // UNLOCKED
          lastUpdated: new Date()
        });
        return {
          statusCode: 200,
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            context: {
              properties: [
                {
                  namespace: 'Alexa.LockController',
                  name: 'lockState',
                  value: 'UNLOCKED',
                  timeOfSample: new Date().toISOString(),
                  uncertaintyInMilliseconds: 0
                }
              ]
            },
            event: {
              header: {
                namespace: 'Alexa',
                name: 'Response',
                payloadVersion: '3',
                messageId: header.messageId || crypto.randomUUID(),
                correlationToken: header.correlationToken
              },
              endpoint: {
                scope: { type: 'BearerToken', token: uid },
                endpointId: roomId
              },
              payload: {}
            }
          })
        };
      }
      return { statusCode: 400, body: 'Unsupported directive' };
    }

    // No matching handler
    console.log('No Alexa directive matched. Event:', JSON.stringify(event, null, 2));
    return {
      statusCode: 404,
      body: JSON.stringify({ error: 'Not found' })
    };

  } catch (error) {
    console.error('Lambda error:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Internal server error', details: error.message })
    };
  }
}; 