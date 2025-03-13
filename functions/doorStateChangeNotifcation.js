const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.sendNotificationToDevice = functions.firestore
    .document('/notifications/{docId}')
    .onCreate(async (snap, context) => {
        const data = snap.data();
        const deviceToken = data.deviceToken; // Assuming deviceToken is a string

        const message = {
            // Notification content based on data
        };

        // Send the notification to the device token
        await sendNotificationToDevice(deviceToken, message);

        return null;
    });

async function sendNotificationToDevice(deviceToken, message) {
    const messaging = admin.messaging();
    const response = await messaging.sendToDevice(deviceToken, message);
    console.log('Notification sent:', response);
}
