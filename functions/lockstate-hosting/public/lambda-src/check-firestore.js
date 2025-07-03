import admin from 'firebase-admin';
import serviceAccount from './lockstate-e72fc-66f29588f54f.json' with { type: "json" };

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const testUid = 'amzn1.account.AFWVA2IJ7K4GCTSY6DVJNPVSTW5A';

async function checkFirestore() {
  console.log('Checking Firestore for user ID:', testUid);
  
  try {
    // Check rooms collection
    const roomsSnap = await admin.firestore().collection('rooms').where('userId', '==', testUid).get();
    console.log('Rooms found:', roomsSnap.docs.length);
    
    roomsSnap.docs.forEach((doc, index) => {
      console.log(`Room ${index + 1}:`, doc.data());
    });
    
    // Also check if there are any rooms at all
    const allRoomsSnap = await admin.firestore().collection('rooms').limit(5).get();
    console.log('\nTotal rooms in collection:', allRoomsSnap.docs.length);
    
    allRoomsSnap.docs.forEach((doc, index) => {
      console.log(`All Room ${index + 1}:`, doc.data());
    });
    
  } catch (error) {
    console.error('Error checking Firestore:', error);
  }
  
  process.exit(0);
}

checkFirestore(); 