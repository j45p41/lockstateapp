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
    var wifiData = '${wifiNameController.text},${wifiPasswordController.text}';
    writeData(wifiData);
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
                            child: TextField(
                              controller: wifiNameController,
                              decoration:
                                  InputDecoration(labelText: 'Wifi Name'),
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
                          StreamBuilder(
                            stream: targetCharacteristic.value,
                            builder: (context, snapshot) {
                              return Text(snapshot.toString());
                            },
                          ),
                          SizedBox(
                            height: 16,
                          ),
                          Text(readData.toString()),
                          SizedBox(
                            height: 16,
                          ),
                          ElevatedButton(
                              onPressed: () async {
                                setState(() {
                                  isLoading = true;
                                });
                                var res = await targetCharacteristic.read();
                                final dataController =
                                    Momentum.controller<DataController>(
                                        context);

                                print(res.toString());
                                setState(() {
                                  readData = utf8.decode(res);
                                });
                                List temp = readData.split(',').toList();
                                List temp1 = [];
                                temp.forEach((element) {
                                  temp1.add(element.toString() //.substring(1)
                                      );
                                });

                                print(temp1);
                                List roomsIds = [];

                                roomsIds = temp1.toList();
                                print("after set " + roomsIds.toString());
                                for (int i = 0; i < temp1.length; i += 2) {//1,2,3,4,5,6,7,8      
                                  FirebaseFirestore.instance
                                      .collection('rooms')
                                      .add({
                                    'name': "room${temp1[i]}",
                                    'userId':
                                        FirebaseAuth.instance.currentUser!.uid
                                  }).then((doc) {
                                    FirebaseFirestore.instance
                                        .collection('rooms')
                                        .doc(doc.id)
                                        .update({'roomId': doc.id});
                                    if (temp[i] != "0") {
                                      dataController.addDevice(
                                          temp1[i],
                                          FirebaseAuth
                                              .instance.currentUser!.uid,
                                          temp1[i],
                                          false,
                                          doc.id);
                                    }
                                    if (temp[i + 1] != "0") {
                                      dataController.addDevice(
                                          temp1[i + 1],
                                          FirebaseAuth
                                              .instance.currentUser!.uid,
                                          temp1[i + 1],
                                          true,
                                          doc.id);
                                    }

                                    
                                  });
                                }
                                setState(() {
                                  isLoading = false;
                                });
                                Navigator.of(context)
                                    .pushReplacement(MaterialPageRoute(
                                  builder: (context) {
                                    return Authenticate();
                                  },
                                ));
                                // roomsIds.forEach((element) {
                                //   FirebaseFirestore.instance
                                //       .collection('rooms')
                                //       .add({
                                //     'name': "room$element",
                                //     'userId':
                                //         FirebaseAuth.instance.currentUser!.uid
                                //   }).then((doc) {
                                //     FirebaseFirestore.instance
                                //         .collection('rooms')
                                //         .doc(doc.id)
                                //         .update({'roomId': doc.id});

                                //     dataController.addDevice(
                                //         "O" + element,
                                //         FirebaseAuth.instance.currentUser!.uid,
                                //         "O" + element,
                                //         false,
                                //         doc.id);
                                //     dataController.addDevice(
                                //         "I" + element,
                                //         FirebaseAuth.instance.currentUser!.uid,
                                //         "I" + element,
                                //         true,
                                //         doc.id);
                                //     setState(() {
                                //       isLoading = false;
                                //     });
                                //     Navigator.of(context)
                                //         .pushReplacement(MaterialPageRoute(
                                //       builder: (context) {
                                //         return Authenticate();
                                //       },
                                //     ));
                                //   });
                                // });
                              },
                              child: Text("Press to read"))
                        ],
                      ),
                    )),
    );
  }
}
