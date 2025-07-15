const { storeAmazonUserIdMapping, getAmazonUserIdFromFirebase } = require('./amazon-uid-lookup');

async function testFirestoreIntegration() {
  console.log('🧪 TESTING FIRESTORE AMAZON USER_ID INTEGRATION\n');
  
  // Test 1: Store Amazon user_id mapping
  console.log('📝 Test 1: Storing Amazon user_id mapping...');
  const testAmazonUserId = 'amzn1.account.TEST123456789';
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
    const retrievedAmazonUserId = await getAmazonUserIdFromFirebase(testFirebaseUid);
    console.log('✅ Successfully retrieved Amazon user_id:', retrievedAmazonUserId);
    console.log('   Matches stored value:', retrievedAmazonUserId === testAmazonUserId);
  } catch (error) {
    console.log('❌ Failed to retrieve Amazon user_id:', error.message);
    return;
  }
  
  // Test 3: Test with a different Firebase UID
  console.log('\n🔄 Test 3: Testing with different Firebase UID...');
  const testFirebaseUid2 = 'test-user-123';
  const testAmazonUserId2 = 'amzn1.account.TEST456789012';
  
  try {
    await storeAmazonUserIdMapping(testAmazonUserId2, testFirebaseUid2);
    console.log('✅ Successfully stored second mapping');
    
    const retrievedAmazonUserId2 = await getAmazonUserIdFromFirebase(testFirebaseUid2);
    console.log('✅ Successfully retrieved second Amazon user_id:', retrievedAmazonUserId2);
    console.log('   Matches stored value:', retrievedAmazonUserId2 === testAmazonUserId2);
  } catch (error) {
    console.log('❌ Failed second test:', error.message);
  }
  
  console.log('\n🎉 Firestore integration test completed!');
  console.log('\n📋 Next steps:');
  console.log('1. Update your Flutter app to pass Firebase UID in OAuth state parameter');
  console.log('2. Test account linking in Alexa Developer Console');
  console.log('3. Verify device discovery works for multiple users');
}

// Run the test
testFirestoreIntegration().catch(console.error); 