const crypto = require('crypto');

// Simulate an Alexa state report request
const testEvent = {
  directive: {
    header: {
      namespace: 'Alexa',
      name: 'ReportState',
      payloadVersion: '3',
      messageId: crypto.randomUUID(),
      correlationToken: 'test-token'
    },
    endpoint: {
      scope: {
        type: 'BearerToken',
        token: 'test-token'
      },
      endpointId: 'RcW0lotdwT3Eq4fCvuKw'
    },
    payload: {}
  }
};

console.log('Test event for state report:');
console.log(JSON.stringify(testEvent, null, 2));

// This simulates what Alexa would send to get the state of the FRONT door
// The Lambda should return the current state from Firestore 