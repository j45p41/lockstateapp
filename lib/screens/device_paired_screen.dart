import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

class DevicePairedScreen extends StatefulWidget {
  final BluetoothDevice device;
  DevicePairedScreen(this.device);
  @override
  _DevicePairedScreenState createState() => _DevicePairedScreenState();
}

class _DevicePairedScreenState extends State<DevicePairedScreen> {
  final String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  final String TARGET_DEVICE_NAME = "ESP32 THAT PROJECT";

  FlutterBlue flutterBlue = FlutterBlue.instance;

  late BluetoothCharacteristic targetCharacteristic;
  String connectionText = "";

  @override
  void initState() {
    super.initState();
    discoverServices();
  }

  discoverServices() async {
    if (widget.device == null) {
      return;
    }
    print("running discover services");

    List<BluetoothService> services = await widget.device.discoverServices();
    services.forEach((service) {
      if (service.uuid.toString() == SERVICE_UUID) {
        service.characteristics.forEach((characteristics) {
          if (characteristics.uuid.toString() == CHARACTERISTIC_UUID) {
            setState(() {
              targetCharacteristic = characteristics;
              connectionText = "All Ready with ${widget.device.name}";
            });
          }
        });
      }
    });
  }

  writeData(String data) async {
    if (targetCharacteristic == null) return;
    print("write data");
    List<int> bytes = utf8.encode(data);
    var res = await targetCharacteristic.write(bytes);
    print(res);
  }

  submitAction() {
    var wifiData = '${wifiNameController.text},${wifiPasswordController.text}';
    writeData(wifiData);
  }

  TextEditingController wifiNameController = TextEditingController();
  TextEditingController wifiPasswordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(connectionText),
      ),
      body: Container(
          child: targetCharacteristic == null
              ? Center(
                  child: Text(
                    "Waiting...",
                    style: TextStyle(fontSize: 34, color: Colors.red),
                  ),
                )
              : Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: wifiNameController,
                        decoration: InputDecoration(labelText: 'Wifi Name'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: wifiPasswordController,
                        decoration: InputDecoration(labelText: 'Wifi Password'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton(
                        onPressed: submitAction,
                        child: Text('Submit'),
                      ),
                    )
                  ],
                )),
    );
  }
}
