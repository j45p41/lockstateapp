// To parse this JSON data, do
//
//     final history = historyFromJson(jsonString);

import 'dart:convert';

History historyFromJson(String str) => History.fromJson(json.decode(str));

String historyToJson(History data) => json.encode(data.toJson());

class History {
  History(
      {required this.deviceId,
      required this.deviceName,
      required this.fcmIds,
      required this.isIndoor,
      required this.radioPowerLevel,
      required this.message,
      required this.roomId,
      required this.userId});

  String deviceId;
  String deviceName;
  int radioPowerLevel;
  bool isIndoor;
  List<dynamic> fcmIds;
  Message message;
  String roomId;
  String userId;

  factory History.fromJson(Map<String, dynamic> json) => History(
      deviceId: json["deviceId"] ?? "",
      deviceName: json["deviceName"] ?? "",
      roomId: json["roomId"] ?? "",
      radioPowerLevel:json["radioPowerLevel"] ?? "",
            isIndoor:json["isIndoor"] ?? "",
      fcmIds: List<dynamic>.from(json["fcmIds"].map((x) => x)),
      message: Message.fromJson(json["message"]),
      userId: json["userId"] ?? "");

  Map<String, dynamic> toJson() => {
        "deviceId": deviceId,
        "deviceName": deviceName,
        "radioPowerLevel": radioPowerLevel,
        "isIndoor": isIndoor,
        "fcmIds": List<dynamic>.from(fcmIds.map((x) => x)),
        "message": message.toJson(),
        "userId": userId,
      };
}

class Message {
  Message({
    required this.receivedAt,
    required this.uplinkMessage,
  });

  DateTime receivedAt;
  UplinkMessage uplinkMessage;

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        receivedAt: DateTime.parse(json["received_at"].toString()),
        uplinkMessage: UplinkMessage.fromJson(json["uplink_message"]),
      );

  Map<String, dynamic> toJson() => {
        "received_at": receivedAt.toIso8601String(),
        "uplink_message": uplinkMessage.toJson(),
      };
}

class UplinkMessage {
  UplinkMessage({
    required this.decodedPayload,
  });

  DecodedPayload decodedPayload;

  factory UplinkMessage.fromJson(Map<String, dynamic> json) => UplinkMessage(
        decodedPayload: DecodedPayload.fromJson(json["decoded_payload"]),
      );

  Map<String, dynamic> toJson() => {
        "decoded_payload": decodedPayload.toJson(),
      };
}

class DecodedPayload {
  DecodedPayload({
    required this.batVolts,
    required this.lockCount,
    required this.lockState,
  });

  int batVolts;
  int lockCount;
  int lockState;

  factory DecodedPayload.fromJson(Map<String, dynamic> json) => DecodedPayload(
        batVolts: json["batVolts"] ?? 0,
        lockCount: json["lockCount"] ?? 0,
        lockState: json["lockState"] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        "batVolts": batVolts,
        "lockCount": lockCount,
        "lockState": lockState,
      };
}

class Location {
  Location({
    required this.latitude,
    required this.longitude,
  });

  double latitude;
  double longitude;

  factory Location.fromJson(Map<String, dynamic> json) => Location(
        latitude: json["latitude"] == null ? 0.0 : json["latitude"].toDouble(),
        longitude:
            json["longitude"] == null ? 0.0 : json["longitude"].toDouble(),
      );

  Map<String, dynamic> toJson() => {
        "latitude": latitude,
        "longitude": longitude,
      };
}
