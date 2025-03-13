/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { Messaging } = require('firebase-admin/messaging');

admin.initializeApp();

exports.sendNotification = functions.firestore
    .document('/notifications/{docId}')
    .onCreate(async (snap, context) => {
        const data = snap.data();
        const deviceName = data.deviceName;
        const lockState = data.message.uplink_message.decoded_payload.lockState;
        const userId = data.userId;

        if (!userId) return;

        const userDoc = await admin.firestore()
            .collection('users')
            .doc(userId)
            .get();

        if (!userDoc.exists) return;

        const userData = userDoc.data();
        let fcmIds = userData.fcmId || [];
        
        if (!Array.isArray(fcmIds)) return;

        // Filter out invalid tokens
        fcmIds = fcmIds.filter(token => 
            token && typeof token === 'string' && token.length >= 100
        );

        if (fcmIds.length === 0) return;

        let lockStateString;
        switch (lockState) {
            case 1: lockStateString = 'LOCKED'; break;
            case 2: lockStateString = 'UNLOCKED'; break;
            case 3: lockStateString = 'OPEN'; break;
            case 4: lockStateString = 'CLOSED'; break;
            default: lockStateString = 'Unknown';
        }

        // Send notifications to valid tokens
        for (const fcmId of fcmIds) {
            try {
                await admin.messaging().send({
                    token: fcmId.trim(),
                    notification: {
                        title: 'Locksure',
                        body: `${deviceName} Door is ${lockStateString}`,
                    },
                    android: {
                        priority: 'high',
                    },
                    apns: {
                        payload: {
                            aps: {
                                contentAvailable: true,
                            },
                        },
                    }
                });
            } catch (error) {
                if (error.code === 'messaging/invalid-registration-token' ||
                    error.code === 'messaging/registration-token-not-registered') {
                    await admin.firestore()
                        .collection('users')
                        .doc(userId)
                        .update({
                            fcmId: fcmIds.filter(t => t !== fcmId)
                        });
                }
            }
        }
    });

exports.alexaDoorsStatus = functions.https.onRequest(async (request, response) => {
  const intentName = request.body.request.intent.name;
  
  switch (intentName) {
    case 'CheckDoorsIntent':
      return handleCheckDoorsIntent(request, response);
    
    case 'AMAZON.HelpIntent':
      return response.json({
        version: '1.0',
        response: {
          outputSpeech: {
            type: 'PlainText',
            text: 'You can ask me to check if your doors are locked by saying "are my doors locked" or "check door status".'
          }
        }
      });
    
    case 'AMAZON.StopIntent':
    case 'AMAZON.CancelIntent':
      return response.json({
        version: '1.0',
        response: {
          outputSpeech: {
            type: 'PlainText',
            text: 'Goodbye!'
          },
          shouldEndSession: true
        }
      });
    
    default:
      return response.json({
        version: '1.0',
        response: {
          outputSpeech: {
            type: 'PlainText',
            text: 'Sorry, I didn\'t understand that command. You can ask me to check your doors by saying "are my doors locked".'
          }
        }
      });
  }
});

async function handleCheckDoorsIntent(request, response) {
  const userId = request.body.userId;
  
  try {
    const roomsSnapshot = await admin.firestore()
      .collection('rooms')
      .where('userId', '==', userId)
      .get();

    const unlockedDoors = [];
    let allLocked = true;
    
    roomsSnapshot.forEach(doc => {
      const room = doc.data();
      if (room.state !== 1) { // If not locked
        allLocked = false;
        unlockedDoors.push(room.name);
      }
    });

    if (allLocked) {
      return response.json({
        version: '1.0',
        response: {
          outputSpeech: {
            type: 'PlainText',
            text: 'Yes, all doors are locked.'
          }
        }
      });
    } else {
      const speechText = `Door ${unlockedDoors.join(' and ')} ${unlockedDoors.length === 1 ? 'is' : 'are'} unlocked.`;
      return response.json({
        version: '1.0',
        response: {
          outputSpeech: {
            type: 'PlainText',
            text: speechText
          }
        }
      });
    }
  } catch (error) {
    return response.json({
      version: '1.0',
      response: {
        outputSpeech: {
          type: 'PlainText',
          text: 'Sorry, I had trouble checking your doors.'
        }
      }
    });
  }
}
