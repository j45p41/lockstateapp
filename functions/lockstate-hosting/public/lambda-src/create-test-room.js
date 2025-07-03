import admin from 'firebase-admin';
import serviceAccount from './lockstate-e72fc-66f29588f54f.json' assert { type: "json" };

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

const userId = '6ue1XtW8cndXJQyHydNo86PW1p43';
const roomId = 'test-room-' + Date.now();

async function createRoom() {
  await db.collection('rooms').doc(roomId).set({
    userId,
    roomId,
    name: 'Test Alexa Room',
    state: 1
  });
  console.log('Test room created for user:', userId, 'with roomId:', roomId);
}

createRoom().then(() => process.exit(0)); 