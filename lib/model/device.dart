import 'package:cloud_firestore/cloud_firestore.dart';

class Device {
  String userId;
  String deviceId;
  String deviceName;
  List<dynamic> fcmIds;
  int state;
  String roomId;
  String lastRecievedAt;
  int batVolts;
  int count;
  bool isIndoor;

  Device(
      {required this.deviceId,
      required this.deviceName,
      required this.roomId,
      required this.fcmIds,
      required this.userId,
      required this.state,
      required this.batVolts,
      required this.count,
      required this.isIndoor,
      required this.lastRecievedAt});

  factory Device.fromDocument(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return Device(
      roomId: doc.data()['roomId'],
      deviceId: doc.data()['deviceId'],
      deviceName: doc.data()["deviceName"],
      fcmIds: doc.data()["fcmIds"],
      userId: doc.data()["userId"],
      state: doc.data()["state"] ?? 0,
      batVolts: doc.data()["volts"] ?? -1,
      count: doc.data()["count"] ?? -1,
      isIndoor: doc.data()["isIndoor"] ?? false,
      lastRecievedAt: doc.data()["last_update_recieved_at"] ?? "",
    );
  }
}
