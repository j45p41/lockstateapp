const functions = require("firebase-functions");
const admin = require('firebase-admin');
const mqtt = require('mqtt');
const { firebaseConfig } = require("firebase-functions");
admin.initializeApp();
// // Create and Deploy Your First Cloud Functions
// // https://firebase.google.com/docs/functions/write-firebase-functions
//
// exports.helloWorld = functions.https.onRequest((request, response) => {
//   functions.logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
exports.sendDeviceStateChangeNotification = functions.firestore.document('devices/{deviceId}/history/{historyId}').onWrite(async (change, context) => {

    var db = admin.firestore();
    var deviceId = context.params.deviceId;
    var userId = context.params.userId;
    var fcmIds = context.params.fcmIds;

    functions.logger.log("fcmids " + fcmIds);
    var message = context.params.message;
    var deviceName = context.params.deviceName;
    const payload = {
        notification: {
            title: '${deviceName} State changed',
            body: message,
        }
    };
    const response = await admin.messaging().sendToDevice(fcmIds, payload);

});


exports.mqttFunction = functions.https.onRequest
    (async (req, res) => {
        const type = req.query.type;
        functions.logger.log("type " + type);

        var db = admin.firestore();
        functions.logger.log("Function running");



        // if (type === "TTN") {
        var options = {
            retain: true,
            clientId: "",
            port: 1883,
            username: "jandraapp@ttn",
            password: "NNSXS.IZ6SZS5TMGPMYAG2WWIATBYFVZJHCUSYYUHXBTQ.IZ6NCWZ4APBRBHA4HNM6Q3QQ52AZISLGNIADJHRJ7DL3AREVFXHQ",
            clean: true,
            qos: 1
        };
        // }
        var client = mqtt.connect("mqtt://eu1.cloud.thethings.network", options);
        functions.logger.log("connected flag  " + client.connected);

        //handle incoming messages
        client.on('message', async function (topic, message, packet) {
            functions.logger.log("type of message is " + typeof (message));
            functions.logger.log("message is " + message);
            var parsedMessage = JSON.parse(message);
            functions.logger.log(" 1 device id is " + parsedMessage.end_device_ids.device_id);

            // var deviceId = message["end_device_ids"]["device_id"];

            // functions.logger.log(" 2 device id is " + deviceId);

            var doc = await db.collection('devices').doc(parsedMessage.end_device_ids.device_id).get().catch((e) => {
                functions.logger.log("get device doc error " + e);
            });
            var userId = doc.data()["userId"];
            var fcmIds = doc.data()["fcmIds"];
            var deviceName = doc.data()["deviceName"];
            var roomId = doc.data()["roomId"];

            var body = {
                "message": parsedMessage,
                "deviceId": parsedMessage.end_device_ids.device_id,
                "userId": userId,
                "fcmIds": fcmIds,
                "deviceName": deviceName,
                "roomId": roomId,
            }
            functions.logger.log("Body deviceId " + body.deviceId);
            functions.logger.log("Body device name " + body.deviceName);
            functions.logger.log("Body fcm " + body.fcmIds);
            functions.logger.log("Body message " + body.message);
            functions.logger.log("Body userid " + body.userId);


            await db.collection('devices').doc(parsedMessage.end_device_ids.device_id).collection('history').add(body).catch((e) => {
                functions.logger.log("write doc devices error " + e);
            });

            await db.collection('devices').doc(parsedMessage.end_device_ids.device_id).update({ "state": parsedMessage.uplink_message.decoded_payload.lockState });
            await db.collection('notifications').add(body).catch((e) => {
                functions.logger.log("write doc notifications error " + e);
            });

        });


        client.on("connect", function () {
            functions.logger.log("connected  " + client.connected);


        })
        //handle errors
        client.on("error", function (error) {
            functions.logger.log("Can't connect" + error);

        });



        var topic = "v3/jandraapp@ttn/devices/door2/up";


        functions.logger.log("subscribing to topics");
        client.subscribe(topic, { qos: 1 });
    });


exports.heliumMqttFunction = functions.https.onRequest
    (async (req, res) => {
        const type = req.query.type;
        functions.logger.log("type " + type);

        var db = admin.firestore();
        functions.logger.log("Function running");



        // if (type === "TTN") {
        var options = {
            retain: true,
            clientId: "2d964d7d-5dcd-496f-94e4-d8eb4497e515",
            port: 18103,
            username: "jaspal.ext@gmail.com",
            password: "bWmLEqNXk2Nmy/k8KRia17i63k7WydDLkBeRi5GffMA",
            clean: true,
            qos: 1
        };
        // }
        var client = mqtt.connect("mqtt://xccc.com", options);
        functions.logger.log("connected flag  " + client.connected);

        //handle incoming messages
        client.on('message', async function (topic, message, packet) {
            functions.logger.log("type of message is " + typeof (message));
            functions.logger.log("message is " + message);
            var parsedMessage = JSON.parse(message);
            functions.logger.log(" 1 device id is " + parsedMessage.end_device_ids.device_id);

            // var deviceId = message["end_device_ids"]["device_id"];

            // functions.logger.log(" 2 device id is " + deviceId);

            var doc = await db.collection('devices').doc(parsedMessage.end_device_ids.device_id).get().catch((e) => {
                functions.logger.log("get device doc error " + e);
            });
            var userId = doc.data()["userId"];
            var fcmIds = doc.data()["fcmIds"];
            var deviceName = doc.data()["deviceName"];
            var roomId = doc.data()["roomId"];

            var body = {
                "message": parsedMessage,
                "deviceId": parsedMessage.end_device_ids.device_id,
                "userId": userId,
                "fcmIds": fcmIds,
                "deviceName": deviceName,
                "roomId": roomId,
            }
            functions.logger.log("Body deviceId " + body.deviceId);
            functions.logger.log("Body device name " + body.deviceName);
            functions.logger.log("Body fcm " + body.fcmIds);
            functions.logger.log("Body message " + body.message);
            functions.logger.log("Body userid " + body.userId);


            await db.collection('devices').doc(parsedMessage.end_device_ids.device_id).collection('history').add(body).catch((e) => {
                functions.logger.log("write doc devices error " + e);
            });

            await db.collection('devices').doc(parsedMessage.end_device_ids.device_id).update({ "state": parsedMessage.uplink_message.decoded_payload.lockState });
            await db.collection('notifications').add(body).catch((e) => {
                functions.logger.log("write doc notifications error " + e);
            });

        });


        client.on("connect", function () {
            functions.logger.log("connected  " + client.connected);


        })
        //handle errors
        client.on("error", function (error) {
            functions.logger.log("Can't connect" + error);

        });



        var topic = "helium/dev1/rx";


        functions.logger.log("subscribing to topics");
        client.subscribe(topic, { qos: 1 });
    });



