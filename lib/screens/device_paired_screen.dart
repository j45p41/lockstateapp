import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:lockstate/data/data.controller.dart';
import 'package:lockstate/main.dart';
import 'package:momentum/momentum.dart';

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

  FlutterBluePlus flutterBlue = FlutterBluePlus.instance;

  late BluetoothCharacteristic targetCharacteristic;
  String connectionText = "";

  @override
  void initState() {
    print("_DevicePairedScreenState");

    super.initState();
    discoverServices();
  }

  discoverServices() async {
    if (widget.device == null) {
      return;
    }
    print("running discover services");
    print("device : " + widget.device.toString());

    List<BluetoothService> services = await widget.device.discoverServices();

    services.forEach((service) {
      if (service.uuid.toString() == SERVICE_UUID) {
        service.characteristics.forEach((characteristics) {
          if (characteristics.uuid.toString() == CHARACTERISTIC_UUID) {
            setState(() {
              targetCharacteristic = characteristics;
              connectionText = "All Ready with ${widget.device.name}";
              readBLE();
            });
          }
        });
      }
    });
    targetCharacteristic.setNotifyValue(true);
  }

  writeData(String data) async {
    if (targetCharacteristic == null) return;
    print("write data");
    List<int> bytes = utf8.encode(data);
    var res = await targetCharacteristic.write(bytes);
    print(res);
  }

  submitAction() {
    var wifiData = '${firstWifi},${wifiPasswordController.text}';
    writeData(wifiData);

    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (context) {
        return Authenticate();
      },
    ));
  }

  List temp1 = [];
  List temp = [];

  List<String> wifiIDs = [];
  List wifiIDrop = [];
  List roomsIds = [];
  String firstWifi = "";
  String selectedWifiSSID = "";

  void readBLE() async {
    setState(() {
      isLoading = true;
    });
    var res = await targetCharacteristic.read();
    final dataController = Momentum.controller<DataController>(context);

    print("res.toString()");
    print(res.toString());
    setState(() {
      readData = utf8.decode(res);
    });
    print("readData");
    print(readData);

// SPLIT SSIDS and Doors

    temp = readData.split(',').toList();

    temp.forEach((element) {
      temp1.add(element.toString() //.substring(1)
          );
    });

    "print(temp1)";
    print(temp1);

    String wifiIDTemp;

    wifiIDTemp = temp1
        .toList()
        .sublist(0, 10)
        .toString()
        .replaceFirst(', 0', '')
        .replaceFirst(', 0', '')
        .replaceFirst(', 0', '')
        .replaceFirst(', 0', '')
        .replaceFirst(', 0', '')
        .replaceFirst(', 0', '')
        .replaceFirst(', 0', '')
        .replaceFirst(', 0', '')
        .replaceFirst(', 0', '')
        .replaceFirst(' ', '')
        .replaceFirst(' ', '')
        .replaceFirst(' ', '')
        .replaceFirst(' ', '')
        .replaceFirst(' ', '')
        .replaceFirst(' ', '')
        .replaceFirst(' ', '')
        .replaceFirst(' ', '')
        .replaceFirst(' ', '')
        .replaceFirst(' ', '');

    print(wifiIDTemp);

    wifiIDs = wifiIDTemp
        .replaceRange(0, 1, '')
        .replaceRange(wifiIDTemp.length - 2, wifiIDTemp.length - 1, '')
        // .replaceFirst('[', '')
        // .replaceFirst(']', '')

        .split(',');

    firstWifi = wifiIDs[0].toString();

    roomsIds = temp1.toList().sublist(10);

    // wifiIDs = temp1
    //     .toList()
    //     .sublist(0, 10)
    //     .toString()
    //     .replaceRange(0, 1, '')
    //     .replaceRange(0, length - 2, '')R
    //     // .replaceFirst('[', '')
    //     // .replaceFirst(']', '')
    //     // .replaceFirst(',0,', ',')
    //     .split(',');
    roomsIds = temp1.toList().sublist(10);

    "print(wifiIDs)";
    print(wifiIDs);

    "print(roomsIds)";
    print(roomsIds);

    print("after set " + roomsIds.toString());

// DELETE OLD ROOMS HERE

    print("OLD ROOMS:");
    final db = FirebaseFirestore.instance;
    var userId = FirebaseAuth.instance.currentUser!.uid.toString();

    var result =
        await db.collection('rooms').where("userId", isEqualTo: userId).get();
    result.docs.forEach((res) {
      print(res.id);

      FirebaseFirestore.instance.collection('rooms').doc(res.id).delete();
    });

    var index = 1;

    bool j = false;
    for (int i = 0; i < roomsIds.length; i += 2) {
      //1,2,3,4,5,6,7,8
      print("********ROOM ID's*******");
      print("room${i}");

      FirebaseFirestore.instance.collection('rooms').add({
        'name': "room ${index}",
        'userId': FirebaseAuth.instance.currentUser!.uid
      }).then((doc) {
        FirebaseFirestore.instance
            .collection('rooms')
            .doc(doc.id)
            .update({'roomId': doc.id});
        if (temp[i] != "0") {
          dataController.addDevice(temp1[i],
              FirebaseAuth.instance.currentUser!.uid, temp1[i], true, doc.id);
        }
        if (temp[i + 1] != "0") {
          dataController.addDevice(
              temp1[i + 1],
              FirebaseAuth.instance.currentUser!.uid,
              temp1[i + 1],
              false,
              doc.id);
        }
      });
      index++;
    }

    setState(() {
      isLoading = false;
    });
  }

  TextEditingController wifiNameController = TextEditingController();
  TextEditingController wifiPasswordController = TextEditingController();
  String readData = '';
  bool isLoading = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(connectionText),
      ),
      body: isLoading
          ? Center(
              child: Text("Creating rooms and doors please wait..."),
            )
          : Container(
              child: targetCharacteristic == null
                  ? Center(
                      child: Text(
                        "Waiting...",
                        style: TextStyle(fontSize: 34, color: Colors.red),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: DropdownButton<String>(
                              value: firstWifi,
                              items: wifiIDs.map((String items) {
                                return DropdownMenuItem(
                                  value: items,
                                  child: Text(items),
                                );
                              }).toList(),
                              isExpanded: true,
                              onChanged: (String? newValue) {
                                setState(() {
                                  firstWifi = newValue!;
                                });
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: TextField(
                              controller: wifiPasswordController,
                              decoration:
                                  InputDecoration(labelText: 'Wifi Password'),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: ElevatedButton(
                              onPressed: submitAction,
                              child: Text('Submit'),
                            ),
                          ),
                          // StreamBuilder(
                          //   stream: targetCharacteristic.value,
                          //   builder: (context, snapshot) {
                          //     return Text(wifiIDs.toString());
                          //   },
                          // ),
                          // SizedBox(
                          //   height: 16,
                          // ),
                          // Text(readData.toString()),
                          // SizedBox(
                          //   height: 16,
                          // ),
                        ],
                      ),
                    )),
    );
  }
}
