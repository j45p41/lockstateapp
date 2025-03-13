import 'package:flutter/material.dart';
import 'package:lockstate/utils/url_utils.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttTest extends StatefulWidget {
  const MqttTest({Key? key}) : super(key: key);

  @override
  _MqttTestState createState() => _MqttTestState();
}

class _MqttTestState extends State<MqttTest> {
  late MqttServerClient client;
  // MqttServerClient.withPort('eu1.cloud.thethings.network', '', 1883);
  List test = [];
  Future<MqttServerClient> connect() async {
    // MqttServerClient client =
    //     MqttServerClient.withPort('broker.emqx.io', 'flutter_client', 1883);
    client = MqttServerClient.withPort('eu1.cloud.thethings.network', '', 1883);
    client.logging(on: true);
    client.onConnected = onConnected;
    client.onDisconnected = onDisconnected;
    // client.onUnsubscribed = onUnsubscribed as UnsubscribeCallback;
    client.onSubscribed = onSubscribed;
    client.onSubscribeFail = onSubscribeFail;
    client.pongCallback = pong;
    client.keepAlivePeriod = 2000;

    final connMessage = MqttConnectMessage()
        .authenticateAs('jandraapp@ttn', UrlUtils.apiKey)
        // .keepAliveFor(60)
        // .withWillTopic('v3/jandraapp@ttn/devices/door2/up')
        // .withWillMessage('Will message')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    client.connectionMessage = connMessage;
    // try {
    // print(client.)
    await client.connect();
    client.subscribe('v3/jandraapp@ttn/devices/door2/up', MqttQos.atLeastOnce);
    // } catch (e) {
    // print('Exception: $e');
    // client.disconnect();
    // }

    // client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
    //   print("c : " + c.toString());
    //   final MqttMessage message = c[0].payload;
    //   // final payload =
    //   //     MqttPublishPayload.bytesToStringAsString(message.payload.message);

    //   print('Received message:$message from topic: ${c[0].topic}>');
    // });

    return client;
  }

  // connection succeeded
  void onConnected() {
    print('Connected');
  }

// unconnected
  void onDisconnected() {
    print('Disconnected');
  }

// subscribe to topic succeeded
  void onSubscribed(String topic) {
    print('Subscribed topic: $topic');
  }

// subscribe to topic failed
  void onSubscribeFail(String topic) {
    print('Failed to subscribe $topic');
  }

// unsubscribe succeeded
  void onUnsubscribed(String topic) {
    print('Unsubscribed topic: $topic');
  }

// PING response received
  void pong() {
    print('Ping response client callback invoked');
  }

  @override
  void initState() {
    super.initState();
    connect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<MqttReceivedMessage<MqttMessage>>>(
        builder: (context, snapshot) {
          test.add(snapshot.data![0].payload);
          print("test length ${test.length}");
          print("snapshot data ${snapshot.data![0]}");
          var recMess = snapshot.data![0].payload as MqttPublishMessage;
          var pt =
              MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
          print("payload message : $pt");
          return Center(
            child: Text(snapshot.data.toString()),
          );
        },
        stream: client.updates,
      ),
    );
  }
}
