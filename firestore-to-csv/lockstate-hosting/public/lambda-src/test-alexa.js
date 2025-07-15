// Test script to simulate Alexa Smart Home discovery
const testEvent = {
  directive: {
    header: {
      namespace: "Alexa.Discovery",
      name: "Discover",
      payloadVersion: "3",
      messageId: "test-message-id"
    },
    payload: {
      scope: {
        type: "BearerToken",
        token: "amzn1.account.AFWVA2IJ7K4GCTSY6DVJNPVSTW5A" // This is the user ID from your logs
      }
    }
  }
};

console.log('Test event:', JSON.stringify(testEvent, null, 2));

// This simulates what Alexa sends to your Lambda
// The user ID "amzn1.account.AFWVA2IJ7K4GCTSY6DVJNPVSTW5A" should match
// the userId field in your Firestore rooms collection 