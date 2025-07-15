const { getFirebaseUidFromAmazonToken, storeAmazonUserIdMapping, getAmazonUserId } = require('./amazon-uid-lookup');

async function testCompleteIntegration() {
  console.log('🧪 TESTING COMPLETE AMAZON USER_ID INTEGRATION\n');
  
  // Test 1: Store Amazon user_id mapping
  console.log('📝 Test 1: Storing Amazon user_id mapping...');
  const testAmazonUserId = 'amzn1.account.AF2KJ6KQZQZQZQZQZQZQZ';
  const testFirebaseUid = '6ue1XtW8cndXJQyHydNo86PW1p43';
  
  try {
    await storeAmazonUserIdMapping(testAmazonUserId, testFirebaseUid);
    console.log('✅ Successfully stored mapping:', { amazonUserId: testAmazonUserId, firebaseUid: testFirebaseUid });
  } catch (error) {
    console.log('❌ Failed to store mapping:', error.message);
    return;
  }
  
  // Test 2: Retrieve Amazon user_id from Firestore
  console.log('\n🔍 Test 2: Retrieving Amazon user_id from Firestore...');
  try {
    const retrievedAmazonUserId = await getAmazonUserId(testFirebaseUid);
    console.log('✅ Successfully retrieved Amazon user_id:', retrievedAmazonUserId);
    console.log('   Matches stored value:', retrievedAmazonUserId === testAmazonUserId);
  } catch (error) {
    console.log('❌ Failed to retrieve Amazon user_id:', error.message);
    return;
  }
  
  // Test 3: Simulate Alexa device discovery with mock Amazon token
  console.log('\n🏠 Test 3: Simulating Alexa device discovery...');
  const mockAmazonToken = 'mock-amazon-access-token';
  
  try {
    const firebaseUid = await getFirebaseUidFromAmazonToken(mockAmazonToken);
    console.log('✅ Successfully mapped Amazon token to Firebase UID:', firebaseUid);
    console.log('   Matches expected UID:', firebaseUid === testFirebaseUid);
  } catch (error) {
    console.log('❌ Failed to map Amazon token:', error.message);
    console.log('   (This is expected for mock tokens)');
  }
  
  // Test 4: Test with real Amazon token (if available)
  console.log('\n🔑 Test 4: Testing with real Amazon token...');
  const realToken = process.env.REAL_AMAZON_TOKEN;
  
  if (realToken) {
    try {
      const firebaseUid = await getFirebaseUidFromAmazonToken(realToken);
      console.log('✅ Successfully mapped real Amazon token to Firebase UID:', firebaseUid);
    } catch (error) {
      console.log('❌ Failed to map real Amazon token:', error.message);
    }
  } else {
    console.log('ℹ️  No real Amazon token provided (set REAL_AMAZON_TOKEN env var to test)');
  }
  
  console.log('\n🎉 Integration test completed!');
  console.log('\n📋 Next steps:');
  console.log('1. Update your Flutter app to pass Firebase UID in OAuth state parameter');
  console.log('2. Test account linking in Alexa Developer Console');
  console.log('3. Verify device discovery works for multiple users');
}

// Run the test
testCompleteIntegration().catch(console.error); 