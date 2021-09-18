import 'package:cloud_firestore/cloud_firestore.dart';

class Device {
  String userId;
  String deviceId;
  String deviceName;
  List<dynamic> fcmIds;
  String roomId;
  Device(
      {required this.deviceId,
      required this.deviceName,
      required this.roomId,
      required this.fcmIds,
      required this.userId});

  factory Device.fromDocument(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return Device(
        roomId: doc.data()['roomId'],
        deviceId: doc.data()['deviceId'],
        deviceName: doc.data()["deviceName"],
        fcmIds: doc.data()["fcmIds"],
        userId: doc.data()["userId"]);
  }
}
