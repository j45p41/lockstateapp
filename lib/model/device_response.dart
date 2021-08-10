// To parse this JSON data, do
//
//     final deviceResponse = deviceResponseFromJson(jsonString);

import 'package:meta/meta.dart';
import 'dart:convert';

DeviceResponse deviceResponseFromJson(String str) =>
    DeviceResponse.fromJson(json.decode(str));

String deviceResponseToJson(DeviceResponse data) => json.encode(data.toJson());

class DeviceResponse {
  DeviceResponse({
    required this.result,
  });

  Result result;

  factory DeviceResponse.fromJson(Map<String, dynamic> json) => DeviceResponse(
        result: Result.fromJson(json["result"]),
      );

  Map<String, dynamic> toJson() => {
        "result": result.toJson(),
      };
}

class Result {
  Result({
    required this.endDeviceIds,
    required this.receivedAt,
    required this.uplinkMessage,
  });

  EndDeviceIds endDeviceIds;
  DateTime receivedAt;
  UplinkMessage uplinkMessage;

  factory Result.fromJson(Map<String, dynamic> json) => Result(
        endDeviceIds: EndDeviceIds.fromJson(json["end_device_ids"]),
        receivedAt: DateTime.parse(json["received_at"]),
        uplinkMessage: UplinkMessage.fromJson(json["uplink_message"]),
      );

  Map<String, dynamic> toJson() => {
        "end_device_ids": endDeviceIds.toJson(),
        "received_at": receivedAt.toIso8601String(),
        "uplink_message": uplinkMessage.toJson(),
      };
}

class EndDeviceIds {
  EndDeviceIds({
    required this.deviceId,
    required this.applicationIds,
    required this.devEui,
    required this.devAddr,
  });

  String deviceId;
  ApplicationIds applicationIds;
  String devEui;
  String devAddr;

  factory EndDeviceIds.fromJson(Map<String, dynamic> json) => EndDeviceIds(
        deviceId: json["device_id"],
        applicationIds: ApplicationIds.fromJson(json["application_ids"]),
        devEui: json["dev_eui"],
        devAddr: json["dev_addr"],
      );

  Map<String, dynamic> toJson() => {
        "device_id": deviceId,
        "application_ids": applicationIds.toJson(),
        "dev_eui": devEui,
        "dev_addr": devAddr,
      };
}

class ApplicationIds {
  ApplicationIds({
    required this.applicationId,
  });

  String applicationId;

  factory ApplicationIds.fromJson(Map<String, dynamic> json) => ApplicationIds(
        applicationId: json["application_id"],
      );

  Map<String, dynamic> toJson() => {
        "application_id": applicationId,
      };
}

class UplinkMessage {
  UplinkMessage({
    required this.fPort,
    required this.fCnt,
    required this.frmPayload,
    required this.rxMetadata,
    required this.settings,
    required this.receivedAt,
    required this.consumedAirtime,
  });

  int fPort;
  int fCnt;
  String frmPayload;
  List<RxMetadatum> rxMetadata;
  Settings settings;
  DateTime receivedAt;
  String consumedAirtime;

  factory UplinkMessage.fromJson(Map<String, dynamic> json) => UplinkMessage(
        fPort: json["f_port"],
        fCnt: json["f_cnt"],
        frmPayload: json["frm_payload"],
        rxMetadata: List<RxMetadatum>.from(
            json["rx_metadata"].map((x) => RxMetadatum.fromJson(x))),
        settings: Settings.fromJson(json["settings"]),
        receivedAt: DateTime.parse(json["received_at"]),
        consumedAirtime: json["consumed_airtime"],
      );

  Map<String, dynamic> toJson() => {
        "f_port": fPort,
        "f_cnt": fCnt,
        "frm_payload": frmPayload,
        "rx_metadata": List<dynamic>.from(rxMetadata.map((x) => x.toJson())),
        "settings": settings.toJson(),
        "received_at": receivedAt.toIso8601String(),
        "consumed_airtime": consumedAirtime,
      };
}

class RxMetadatum {
  RxMetadatum({
    required this.gatewayIds,
    required this.packetBroker,
    required this.time,
    required this.rssi,
    required this.channelRssi,
    required this.snr,
  });

  GatewayIds gatewayIds;
  PacketBroker packetBroker;
  DateTime time;
  int rssi;
  int channelRssi;
  double snr;

  factory RxMetadatum.fromJson(Map<String, dynamic> json) => RxMetadatum(
        gatewayIds: GatewayIds.fromJson(json["gateway_ids"]),
        packetBroker: PacketBroker.fromJson(json["packet_broker"]),
        time: DateTime.parse(json["time"]),
        rssi: json["rssi"],
        channelRssi: json["channel_rssi"],
        snr: json["snr"].toDouble(),
      );

  Map<String, dynamic> toJson() => {
        "gateway_ids": gatewayIds.toJson(),
        "packet_broker": packetBroker.toJson(),
        "time": time.toIso8601String(),
        "rssi": rssi,
        "channel_rssi": channelRssi,
        "snr": snr,
      };
}

class GatewayIds {
  GatewayIds({
    required this.gatewayId,
  });

  String gatewayId;

  factory GatewayIds.fromJson(Map<String, dynamic> json) => GatewayIds(
        gatewayId: json["gateway_id"],
      );

  Map<String, dynamic> toJson() => {
        "gateway_id": gatewayId,
      };
}

class PacketBroker {
  PacketBroker({
    required this.messageId,
    required this.forwarderNetId,
    required this.forwarderTenantId,
    required this.forwarderClusterId,
    required this.forwarderGatewayEui,
    required this.forwarderGatewayId,
    required this.homeNetworkNetId,
    required this.homeNetworkTenantId,
    required this.homeNetworkClusterId,
  });

  String messageId;
  String forwarderNetId;
  String forwarderTenantId;
  String forwarderClusterId;
  String forwarderGatewayEui;
  String forwarderGatewayId;
  String homeNetworkNetId;
  String homeNetworkTenantId;
  String homeNetworkClusterId;

  factory PacketBroker.fromJson(Map<String, dynamic> json) => PacketBroker(
        messageId: json["message_id"],
        forwarderNetId: json["forwarder_net_id"],
        forwarderTenantId: json["forwarder_tenant_id"],
        forwarderClusterId: json["forwarder_cluster_id"],
        forwarderGatewayEui: json["forwarder_gateway_eui"],
        forwarderGatewayId: json["forwarder_gateway_id"],
        homeNetworkNetId: json["home_network_net_id"],
        homeNetworkTenantId: json["home_network_tenant_id"],
        homeNetworkClusterId: json["home_network_cluster_id"],
      );

  Map<String, dynamic> toJson() => {
        "message_id": messageId,
        "forwarder_net_id": forwarderNetId,
        "forwarder_tenant_id": forwarderTenantId,
        "forwarder_cluster_id": forwarderClusterId,
        "forwarder_gateway_eui": forwarderGatewayEui,
        "forwarder_gateway_id": forwarderGatewayId,
        "home_network_net_id": homeNetworkNetId,
        "home_network_tenant_id": homeNetworkTenantId,
        "home_network_cluster_id": homeNetworkClusterId,
      };
}

class Settings {
  Settings({
    required this.dataRate,
    required this.dataRateIndex,
    required this.codingRate,
    required this.frequency,
  });

  DataRate dataRate;
  int dataRateIndex;
  String codingRate;
  String frequency;

  factory Settings.fromJson(Map<String, dynamic> json) => Settings(
        dataRate: DataRate.fromJson(json["data_rate"]),
        dataRateIndex: json["data_rate_index"],
        codingRate: json["coding_rate"],
        frequency: json["frequency"],
      );

  Map<String, dynamic> toJson() => {
        "data_rate": dataRate.toJson(),
        "data_rate_index": dataRateIndex,
        "coding_rate": codingRate,
        "frequency": frequency,
      };
}

class DataRate {
  DataRate({
    required this.lora,
  });

  Lora lora;

  factory DataRate.fromJson(Map<String, dynamic> json) => DataRate(
        lora: Lora.fromJson(json["lora"]),
      );

  Map<String, dynamic> toJson() => {
        "lora": lora.toJson(),
      };
}

class Lora {
  Lora({
    required this.bandwidth,
    required this.spreadingFactor,
  });

  int bandwidth;
  int spreadingFactor;

  factory Lora.fromJson(Map<String, dynamic> json) => Lora(
        bandwidth: json["bandwidth"],
        spreadingFactor: json["spreading_factor"],
      );

  Map<String, dynamic> toJson() => {
        "bandwidth": bandwidth,
        "spreading_factor": spreadingFactor,
      };
}
