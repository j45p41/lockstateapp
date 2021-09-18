// To parse this JSON data, do
//
//     final history = historyFromJson(jsonString);

import 'dart:convert';

History historyFromJson(String str) => History.fromJson(json.decode(str));

String historyToJson(History data) => json.encode(data.toJson());

class History {
  History({
    required this.deviceId,
    required this.deviceName,
    required this.fcmIds,
    required this.message,
    required this.roomId,
  });

  String deviceId;
  String deviceName;
  List<dynamic> fcmIds;
  Message message;
  String roomId;

  factory History.fromJson(Map<String, dynamic> json) => History(
        deviceId: json["deviceId"] == null ? "" : json["deviceId"],
        deviceName: json["deviceName"] == null ? "" : json["deviceName"],
        roomId: json["roomId"] == null ? "" : json["roomId"],
        fcmIds: List<dynamic>.from(json["fcmIds"].map((x) => x)),
        message: Message.fromJson(json["message"]),
      );

  Map<String, dynamic> toJson() => {
        "deviceId": deviceId,
        "deviceName": deviceName,
        "fcmIds": List<dynamic>.from(fcmIds.map((x) => x)),
        "message": message.toJson(),
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
        receivedAt: DateTime.parse(json["received_at"]),
        uplinkMessage: UplinkMessage.fromJson(json["uplink_message"]),
      );

  Map<String, dynamic> toJson() => {
        "received_at": receivedAt.toIso8601String(),
        "uplink_message": uplinkMessage.toJson(),
      };
}

class UplinkMessage {
  UplinkMessage({
    required this.sessionKeyId,
    required this.frmPayload,
    required this.decodedPayload,
    required this.rxMetadata,
    required this.receivedAt,
  });

  String sessionKeyId;
  String frmPayload;
  DecodedPayload decodedPayload;
  List<RxMetadatum> rxMetadata;
  DateTime receivedAt;

  factory UplinkMessage.fromJson(Map<String, dynamic> json) => UplinkMessage(
        sessionKeyId:
            json["session_key_id"] == null ? "" : json["session_key_id"],
        frmPayload: json["frm_payload"] == null ? "" : json["frm_payload"],
        decodedPayload: DecodedPayload.fromJson(json["decoded_payload"]),
        rxMetadata: List<RxMetadatum>.from(
            json["rx_metadata"].map((x) => RxMetadatum.fromJson(x))),
        receivedAt: DateTime.parse(json["received_at"]),
      );

  Map<String, dynamic> toJson() => {
        "session_key_id": sessionKeyId,
        "frm_payload": frmPayload,
        "decoded_payload": decodedPayload.toJson(),
        "rx_metadata": List<dynamic>.from(rxMetadata.map((x) => x.toJson())),
        "received_at": receivedAt.toIso8601String(),
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
        batVolts: json["batVolts"] == null ? 0 : json["batVolts"],
        lockCount: json["lockCount"] == null ? 0 : json["lockCount"],
        lockState: json["lockState"] == null ? 0 : json["lockState"],
      );

  Map<String, dynamic> toJson() => {
        "batVolts": batVolts,
        "lockCount": lockCount,
        "lockState": lockState,
      };
}

class RxMetadatum {
  RxMetadatum({
    required this.time,
    required this.location,
    required this.uplinkToken,
  });

  DateTime time;
  Location location;
  String uplinkToken;

  factory RxMetadatum.fromJson(Map<String, dynamic> json) => RxMetadatum(
        time: DateTime.parse(json["time"]),
        location: Location.fromJson(json["location"]),
        uplinkToken: json["uplink_token"],
      );

  Map<String, dynamic> toJson() => {
        "time": time.toIso8601String(),
        "location": location.toJson(),
        "uplink_token": uplinkToken,
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
