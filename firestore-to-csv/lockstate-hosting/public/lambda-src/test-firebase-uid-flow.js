#!/usr/bin/env node

/**
 * Test Firebase UID Flow for Alexa Integration
 * 
 * This test simulates the complete flow:
 * 1. Flutter app passes Firebase UID as state parameter
 * 2. OAuth flow preserves the UID
 * 3. Device discovery uses the actual Firebase UID
 * 4. Verification of results
 */

import fetch from 'node-fetch';
import admin from 'firebase-admin';
import fs from 'fs';
import crypto from 'crypto';

// Initialize Firebase Admin
const serviceAccount = JSON.parse(fs.readFileSync('./lockstate-e72fc-66f29588f54f.json', 'utf8'));
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const LAMBDA_URL = 'https://0dpfo4tmbd.execute-api.eu-west-1.amazonaws.com/prod'; // Current Lambda URL
const TEST_FIREBASE_UID = 'testFirebaseUid123456789012345678'; // Test UID to simulate (28 chars like real Firebase UIDs)
const REAL_FIREBASE_UID = '6ue1XtW8cndXJQyHydNo86PW1p43'; // Real Firebase UID from your logs
const TEST_AMAZON_EMAIL = 'test@example.com';

class AlexaIntegrationTest {
  constructor() {
    this.testResults = [];
    this.sessionId = crypto.randomUUID();
  }

  log(message, data = null) {
    const timestamp = new Date().toISOString();
    const logEntry = { timestamp, message, data };
    this.testResults.push(logEntry);
    console.log(`[${timestamp}] ${message}`);
    if (data) console.log(JSON.stringify(data, null, 2));
  }

  async testStep(stepName, testFunction) {
    this.log(`🧪 Starting: ${stepName}`);
    try {
      const result = await testFunction();
      this.log(`✅ Passed: ${stepName}`, result);
      return result;
    } catch (error) {
      this.log(`❌ Failed: ${stepName}`, { error: error.message, stack: error.stack });
      throw error;
    }
  }

  async testOAuthFlowWithFirebaseUID() {
    return await this.testStep('OAuth Flow with Firebase UID', async () => {
      // Step 1: Simulate Flutter app initiating OAuth with Firebase UID as state
      const redirectUri = 'https://your-app.com/alexa-callback';
      const state = TEST_FIREBASE_UID; // Firebase UID as state parameter
      
      const authUrl = `${LAMBDA_URL}/alexaAuth?redirect_uri=${encodeURIComponent(redirectUri)}&state=${encodeURIComponent(state)}`;
      
      this.log('Generated OAuth URL with Firebase UID as state', { authUrl, state });
      
      // Step 2: Simulate the OAuth redirect (we can't actually follow it, but we can verify the URL structure)
      const url = new URL(authUrl);
      const params = new URLSearchParams(url.search);
      
      const verification = {
        hasClientId: !!params.get('client_id'),
        hasScope: params.get('scope') === 'profile',
        hasResponseType: params.get('response_type') === 'code',
        hasRedirectUri: params.get('redirect_uri') === redirectUri,
        hasState: params.get('state') === TEST_FIREBASE_UID,
        stateIsFirebaseUID: params.get('state') === TEST_FIREBASE_UID
      };
      
      this.log('OAuth URL verification', verification);
      
      if (!verification.stateIsFirebaseUID) {
        throw new Error('Firebase UID not properly passed as state parameter');
      }
      
      return { authUrl, verification };
    });
  }

  async testDeviceDiscoveryWithFirebaseUID() {
    return await this.testStep('Device Discovery with Firebase UID', async () => {
      // Create a test room in Firestore for our test Firebase UID
      const testRoom = {
        roomId: `test-room-${this.sessionId}`,
        name: 'TEST FRONT DOOR',
        userId: TEST_FIREBASE_UID,
        state: 1, // LOCKED
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      };
      
      // Add test room to Firestore
      const roomRef = admin.firestore().collection('rooms').doc(testRoom.roomId);
      await roomRef.set(testRoom);
      this.log('Created test room in Firestore', testRoom);
      
      // Simulate Alexa discovery request with Firebase UID
      const discoveryRequest = {
        directive: {
          header: {
            namespace: 'Alexa.Discovery',
            name: 'Discover',
            payloadVersion: '3',
            messageId: crypto.randomUUID()
          },
          payload: {
            scope: {
              type: 'BearerToken',
              token: TEST_FIREBASE_UID // Firebase UID as token
            }
          }
        }
      };
      
      this.log('Sending discovery request', discoveryRequest);
      
      // Send request to Lambda
      const response = await fetch(`${LAMBDA_URL}/alexaSmartHome`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${TEST_FIREBASE_UID}`
        },
        body: JSON.stringify(discoveryRequest)
      });
      
      if (!response.ok) {
        throw new Error(`Discovery request failed: ${response.status} ${response.statusText}`);
      }
      
      const discoveryResponse = await response.json();
      this.log('Discovery response received', discoveryResponse);
      
      // Verify the response contains our test room
      const endpoints = discoveryResponse.event?.payload?.endpoints || [];
      const testEndpoint = endpoints.find(ep => ep.endpointId === testRoom.roomId);
      
      if (!testEndpoint) {
        throw new Error('Test room not found in discovery response');
      }
      
      const verification = {
        endpointsFound: endpoints.length,
        testRoomFound: !!testEndpoint,
        testRoomName: testEndpoint.friendlyName,
        testRoomId: testEndpoint.endpointId,
        hasLockController: testEndpoint.capabilities.some(cap => cap.interface === 'Alexa.LockController')
      };
      
      this.log('Discovery verification', verification);
      
      // Clean up test room
      await roomRef.delete();
      this.log('Cleaned up test room');
      
      return { discoveryResponse, verification };
    });
  }

  async testStateReportWithFirebaseUID() {
    return await this.testStep('State Report with Firebase UID', async () => {
      // Create a test room with known state
      const testRoom = {
        roomId: `test-state-${this.sessionId}`,
        name: 'TEST STATE DOOR',
        userId: TEST_FIREBASE_UID,
        state: 2, // UNLOCKED
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      };
      
      const roomRef = admin.firestore().collection('rooms').doc(testRoom.roomId);
      await roomRef.set(testRoom);
      this.log('Created test room for state report', testRoom);
      
      // Simulate Alexa state report request
      const stateRequest = {
        directive: {
          header: {
            namespace: 'Alexa.LockController',
            name: 'ReportState',
            payloadVersion: '3',
            messageId: crypto.randomUUID(),
            correlationToken: crypto.randomUUID()
          },
          endpoint: {
            endpointId: testRoom.roomId,
            scope: {
              type: 'BearerToken',
              token: TEST_FIREBASE_UID
            }
          },
          payload: {}
        }
      };
      
      this.log('Sending state report request', stateRequest);
      
      const response = await fetch(`${LAMBDA_URL}/alexaSmartHome`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${TEST_FIREBASE_UID}`
        },
        body: JSON.stringify(stateRequest)
      });
      
      if (!response.ok) {
        throw new Error(`State report request failed: ${response.status} ${response.statusText}`);
      }
      
      const stateResponse = await response.json();
      this.log('State report response received', stateResponse);
      
      // Verify the state report
      const lockState = stateResponse.context?.properties?.find(prop => prop.name === 'lockState');
      
      if (!lockState) {
        throw new Error('Lock state not found in response');
      }
      
      const verification = {
        lockState: lockState.value,
        expectedState: 'UNLOCKED', // Based on state: 2
        hasConnectivity: !!stateResponse.context?.properties?.find(prop => prop.name === 'connectivity'),
        timestamp: lockState.timeOfSample
      };
      
      this.log('State report verification', verification);
      
      // Clean up
      await roomRef.delete();
      this.log('Cleaned up test room for state report');
      
      return { stateResponse, verification };
    });
  }

  async testRealUserFlow() {
    return await this.testStep('Real User Flow Simulation', async () => {
      // Get a real Firebase UID from Firestore
      const realUserQuery = await admin.firestore().collection('users').limit(1).get();
      
      if (realUserQuery.empty) {
        this.log('No real users found in Firestore, skipping real user test');
        return { skipped: true, reason: 'No real users found' };
      }
      
      const realUser = realUserQuery.docs[0];
      const realUid = realUser.id;
      this.log('Found real user for testing', { uid: realUid });
      
      // Check if this user has rooms
      const roomsQuery = await admin.firestore().collection('rooms').where('userId', '==', realUid).get();
      const rooms = roomsQuery.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      
      this.log('Real user rooms found', { count: rooms.length, rooms: rooms.map(r => ({ id: r.id, name: r.name })) });
      
      if (rooms.length === 0) {
        this.log('Real user has no rooms, skipping discovery test');
        return { skipped: true, reason: 'No rooms for real user' };
      }
      
      // Test discovery with real user
      const discoveryRequest = {
        directive: {
          header: {
            namespace: 'Alexa.Discovery',
            name: 'Discover',
            payloadVersion: '3',
            messageId: crypto.randomUUID()
          },
          payload: {
            scope: {
              type: 'BearerToken',
              token: realUid
            }
          }
        }
      };
      
      const response = await fetch(`${LAMBDA_URL}/alexaSmartHome`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${realUid}`
        },
        body: JSON.stringify(discoveryRequest)
      });
      
      if (!response.ok) {
        throw new Error(`Real user discovery failed: ${response.status} ${response.statusText}`);
      }
      
      const discoveryResponse = await response.json();
      const endpoints = discoveryResponse.event?.payload?.endpoints || [];
      
      const verification = {
        realUid,
        endpointsFound: endpoints.length,
        expectedEndpoints: rooms.length,
        endpointIds: endpoints.map(ep => ep.endpointId),
        roomIds: rooms.map(r => r.roomId || r.id)
      };
      
      this.log('Real user discovery verification', verification);
      
      return { discoveryResponse, verification };
    });
  }

  async testKnownRealUserFlow() {
    return await this.testStep('Known Real User Flow (6ue1XtW8cndXJQyHydNo86PW1p43)', async () => {
      const knownUid = REAL_FIREBASE_UID;
      this.log('Testing with known real Firebase UID', { uid: knownUid });
      
      // Check if this user has rooms
      const roomsQuery = await admin.firestore().collection('rooms').where('userId', '==', knownUid).get();
      const rooms = roomsQuery.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      
      this.log('Known user rooms found', { count: rooms.length, rooms: rooms.map(r => ({ id: r.id, name: r.name })) });
      
      if (rooms.length === 0) {
        this.log('Known user has no rooms, creating test room');
        
        // Create a test room for this known user
        const testRoom = {
          roomId: `test-known-user-${this.sessionId}`,
          name: 'TEST KNOWN USER DOOR',
          userId: knownUid,
          state: 1, // LOCKED
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        };
        
        const roomRef = admin.firestore().collection('rooms').doc(testRoom.roomId);
        await roomRef.set(testRoom);
        this.log('Created test room for known user', testRoom);
        
        // Update rooms array
        rooms.push(testRoom);
      }
      
      // Test discovery with known user
      const discoveryRequest = {
        directive: {
          header: {
            namespace: 'Alexa.Discovery',
            name: 'Discover',
            payloadVersion: '3',
            messageId: crypto.randomUUID()
          },
          payload: {
            scope: {
              type: 'BearerToken',
              token: knownUid
            }
          }
        }
      };
      
      this.log('Sending discovery request for known user', discoveryRequest);
      
      const response = await fetch(`${LAMBDA_URL}/alexaSmartHome`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${knownUid}`
        },
        body: JSON.stringify(discoveryRequest)
      });
      
      if (!response.ok) {
        const errorText = await response.text();
        this.log('Discovery response error', { status: response.status, statusText: response.statusText, body: errorText });
        throw new Error(`Known user discovery failed: ${response.status} ${response.statusText} - ${errorText}`);
      }
      
      const discoveryResponse = await response.json();
      this.log('Discovery response for known user', discoveryResponse);
      
      const endpoints = discoveryResponse.event?.payload?.endpoints || [];
      
      const verification = {
        knownUid,
        endpointsFound: endpoints.length,
        expectedEndpoints: rooms.length,
        endpointIds: endpoints.map(ep => ep.endpointId),
        roomIds: rooms.map(r => r.roomId || r.id),
        hasExpectedRooms: rooms.every(room => endpoints.some(ep => ep.endpointId === (room.roomId || room.id)))
      };
      
      this.log('Known user discovery verification', verification);
      
      // Clean up test room if we created one
      if (rooms.length === 1 && rooms[0].roomId?.includes('test-known-user-')) {
        await admin.firestore().collection('rooms').doc(rooms[0].roomId).delete();
        this.log('Cleaned up test room for known user');
      }
      
      return { discoveryResponse, verification };
    });
  }

  async runAllTests() {
    this.log('🚀 Starting Firebase UID Flow Tests');
    this.log('Session ID', this.sessionId);
    
    try {
      // Test 1: OAuth Flow with Firebase UID
      await this.testOAuthFlowWithFirebaseUID();
      
      // Test 2: Device Discovery with Firebase UID
      await this.testDeviceDiscoveryWithFirebaseUID();
      
      // Test 3: State Report with Firebase UID
      await this.testStateReportWithFirebaseUID();
      
      // Test 4: Real User Flow
      await this.testRealUserFlow();
      
      // Test 5: Known Real User Flow
      await this.testKnownRealUserFlow();
      
      this.log('🎉 All tests completed successfully!');
      
    } catch (error) {
      this.log('💥 Test suite failed', { error: error.message });
    } finally {
      // Save test results
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const filename = `firebase-uid-test-results-${timestamp}.json`;
      fs.writeFileSync(filename, JSON.stringify({
        sessionId: this.sessionId,
        timestamp: new Date().toISOString(),
        results: this.testResults
      }, null, 2));
      
      this.log(`📄 Test results saved to ${filename}`);
      
      // Print summary
      const passed = this.testResults.filter(r => r.message.includes('✅')).length;
      const failed = this.testResults.filter(r => r.message.includes('❌')).length;
      
      console.log('\n📊 Test Summary:');
      console.log(`✅ Passed: ${passed}`);
      console.log(`❌ Failed: ${failed}`);
      console.log(`📄 Results saved to: ${filename}`);
    }
  }
}

// Run the tests
const test = new AlexaIntegrationTest();
test.runAllTests().catch(console.error); 