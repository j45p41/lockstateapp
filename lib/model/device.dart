import 'package:cloud_firestore/cloud_firestore.dart';

class Device {
  String userId;
  String deviceId;
  String deviceName;
  List<dynamic> fcmIds;
  int state;
  String roomId;
  Device(
      {required this.deviceId,
      required this.deviceName,
      required this.roomId,
      required this.fcmIds,
      required this.userId,
      required this.state});

  factory Device.fromDocument(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return Device(
      roomId: doc.data()['roomId'],
      deviceId: doc.data()['deviceId'],
      deviceName: doc.data()["deviceName"],
      fcmIds: doc.data()["fcmIds"],
      userId: doc.data()["userId"],
      state: doc.data()["state"] == null ? 0 : doc.data()["state"],
    );
  }
}
