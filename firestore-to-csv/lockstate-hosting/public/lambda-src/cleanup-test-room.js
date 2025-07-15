import admin from 'firebase-admin';
import serviceAccount from './lockstate-e72fc-66f29588f54f.json' assert { type: "json" };

const TEST_UID = '6ue1XtW8cndXJQyHydNo86PW1p43';
const TEST_ROOM_ID = 'testRoom1'; // The test room to remove

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

async function cleanupTestRoom() {
  const db = admin.firestore();
  console.log(`\n=== CLEANING UP TEST ROOM ===`);
  console.log(`Removing test room: ${TEST_ROOM_ID}`);
  
  try {
    await db.collection('rooms').doc(TEST_ROOM_ID).delete();
    console.log('✅ Test room removed successfully');
  } catch (error) {
    console.log('ℹ️ Test room was already removed or does not exist');
  }
  
  // Verify remaining rooms
  const snap = await db.collection('rooms').where('userId', '==', TEST_UID).get();
  console.log(`\nRemaining rooms for user: ${snap.docs.length}`);
  snap.docs.forEach(doc => {
    const data = doc.data();
    console.log(`- ${doc.id}: ${data.name} (state: ${data.state})`);
  });
}

async function main() {
  await cleanupTestRoom();
  process.exit(0);
}

main().catch(e => {
  console.error('❌ Cleanup failed:', e);
  process.exit(1);
}); 