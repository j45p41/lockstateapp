import admin from 'firebase-admin';
import https from 'https';
import serviceAccount from './lockstate-e72fc-66f29588f54f.json' assert { type: 'json' };

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

/**
 * Extract Amazon user_id from access token by calling Amazon's Profile API
 * @param {string} accessToken - The Amazon access token
 * @returns {Promise<string>} The Amazon user_id
 */
async function getAmazonUserId(accessToken) {
  console.log('🔑 Getting Amazon user_id from access token...');
  
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'api.amazon.com',
      port: 443,
      path: '/user/profile',
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      }
    };

    const req = https.request(options, (res) => {
      console.log(`📊 Amazon Profile API Status: ${res.statusCode}`);
      
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        try {
          const profile = JSON.parse(data);
          console.log('✅ Amazon Profile Response:', JSON.stringify(profile, null, 2));
          
          if (profile.user_id) {
            console.log('🎯 Found Amazon user_id:', profile.user_id);
            resolve(profile.user_id);
          } else {
            console.log('❌ No user_id in Amazon profile response');
            reject(new Error('No user_id found in Amazon profile'));
          }
        } catch (error) {
          console.log('❌ Failed to parse Amazon profile response:', error.message);
          reject(error);
        }
      });
    });

    req.on('error', (error) => {
      console.log('❌ Amazon Profile API request failed:', error.message);
      reject(error);
    });

    req.end();
  });
}

/**
 * Lookup Firebase UID by Amazon user_id
 * @param {string} amazonUserId - The Amazon user_id
 * @returns {Promise<string>} The Firebase UID
 */
async function getFirebaseUidByAmazonId(amazonUserId) {
  console.log('🔍 Looking up Firebase UID for Amazon user_id:', amazonUserId);
  
  try {
    const usersSnapshot = await db.collection('users')
      .where('amazonID', '==', amazonUserId)
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      console.log('❌ No Firebase user found for Amazon user_id:', amazonUserId);
      throw new Error(`No Firebase user found for Amazon user_id: ${amazonUserId}`);
    }

    const userDoc = usersSnapshot.docs[0];
    const firebaseUid = userDoc.id;
    
    console.log('✅ Found Firebase UID:', firebaseUid);
    console.log('📊 User data:', JSON.stringify(userDoc.data(), null, 2));
    
    return firebaseUid;
  } catch (error) {
    console.log('❌ Firestore lookup failed:', error.message);
    throw error;
  }
}

/**
 * Get Amazon user_id from Firebase UID (direct Firestore lookup)
 * @param {string} firebaseUid - The Firebase UID
 * @returns {Promise<string>} The Amazon user_id
 */
async function getAmazonUserIdFromFirebase(firebaseUid) {
  console.log('🔍 Looking up Amazon user_id for Firebase UID:', firebaseUid);
  
  try {
    const userDoc = await db.collection('users').doc(firebaseUid).get();

    if (!userDoc.exists) {
      console.log('❌ No Firebase user found for UID:', firebaseUid);
      throw new Error(`No Firebase user found for UID: ${firebaseUid}`);
    }

    const userData = userDoc.data();
    const amazonUserId = userData.amazonID;
    
    if (!amazonUserId) {
      console.log('❌ No Amazon user_id found for Firebase UID:', firebaseUid);
      throw new Error(`No Amazon user_id found for Firebase UID: ${firebaseUid}`);
    }
    
    console.log('✅ Found Amazon user_id:', amazonUserId);
    return amazonUserId;
  } catch (error) {
    console.log('❌ Firestore lookup failed:', error.message);
    throw error;
  }
}

/**
 * Store Amazon user_id mapping in Firestore (called during account linking)
 * @param {string} firebaseUid - The Firebase UID
 * @param {string} amazonUserId - The Amazon user_id
 * @returns {Promise<void>}
 */
async function storeAmazonUserIdMapping(firebaseUid, amazonUserId) {
  console.log('💾 Storing Amazon user_id mapping...');
  console.log('📝 Firebase UID:', firebaseUid);
  console.log('🔗 Amazon user_id:', amazonUserId);
  
  try {
    await db.collection('users').doc(firebaseUid).set({
      amazonID: amazonUserId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
    
    console.log('✅ Amazon user_id mapping stored successfully');
  } catch (error) {
    console.log('❌ Failed to store Amazon user_id mapping:', error.message);
    throw error;
  }
}

/**
 * Main function to get Firebase UID from Amazon access token
 * This is what your Lambda should call for Alexa Smart Home requests
 * @param {string} accessToken - The Amazon access token from Alexa request
 * @returns {Promise<string>} The Firebase UID
 */
async function getFirebaseUidFromAmazonToken(accessToken) {
  console.log('🚀 Getting Firebase UID from Amazon access token...');
  
  try {
    // Step 1: Get Amazon user_id from access token
    const amazonUserId = await getAmazonUserId(accessToken);
    
    // Step 2: Lookup Firebase UID by Amazon user_id
    const firebaseUid = await getFirebaseUidByAmazonId(amazonUserId);
    
    console.log('🎉 Successfully mapped Amazon token to Firebase UID:', firebaseUid);
    return firebaseUid;
    
  } catch (error) {
    console.log('💥 Failed to get Firebase UID from Amazon token:', error.message);
    throw error;
  }
}

// Export functions for use in main Lambda handler
export {
  getAmazonUserId,
  getFirebaseUidByAmazonId,
  getAmazonUserIdFromFirebase,
  storeAmazonUserIdMapping,
  getFirebaseUidFromAmazonToken
};

// Test function (for development)
async function testAmazonUidLookup() {
  console.log('🧪 Testing Amazon UID lookup with mock data...');
  
  const mockAmazonUserId = 'amzn1.account.A328OJA37ZT90G';
  const targetFirebaseUid = '6ue1XtW8cndXJQyHydNo86PW1p43';
  
  try {
    // Test storing mapping
    await storeAmazonUserIdMapping(targetFirebaseUid, mockAmazonUserId);
    
    // Test looking up Firebase UID
    const foundUid = await getFirebaseUidByAmazonId(mockAmazonUserId);
    
    console.log('✅ Test completed successfully!');
    console.log('🎯 Expected UID:', targetFirebaseUid);
    console.log('🔍 Found UID:', foundUid);
    console.log('✅ Match:', targetFirebaseUid === foundUid ? 'YES' : 'NO');
    
  } catch (error) {
    console.log('❌ Test failed:', error.message);
  }
}

// Run test if this file is executed directly
if (require.main === module) {
  testAmazonUidLookup();
} 