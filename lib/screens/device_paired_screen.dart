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
  const DevicePairedScreen(this.device, {Key? key}) : super(key: key);

  @override
  _DevicePairedScreenState createState() => _DevicePairedScreenState();
}

class _DevicePairedScreenState extends State<DevicePairedScreen> {
  final String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  final String TARGET_DEVICE_NAME = "ESP32 THAT PROJECT";

  // FlutterBluePlus flutterBlue = FlutterBluePlus.instance;

  bool deleteRooms = false;
  bool deleteRoomsSelected = false;
  bool portSSID = false;
  String storedSSID = "";
  String storedPassword = "";

  @override
  void initState() {
    super.initState();
    // Removed dialog logic from initState
    discoverServices();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Use addPostFrameCallback to ensure the dialog is shown after the build process
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final snapshot = await FirebaseFirestore.instance
          .collection('rooms')
          .where("userId", isEqualTo: userId)
          .get();
      if (snapshot.docs.isNotEmpty) {
        showDialog(
          context: context,
          barrierDismissible:
              false, // Prevents the user from dismissing the dialog by tapping outside
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Is this the first hub?"),
              actions: <Widget>[
                TextButton(
                  child: const Text('Yes'),
                  onPressed: () {
                    setState(() {
                      deleteRooms = true;
                      deleteRoomsSelected = true;
                      print("User selected: Yes");
                    });
                    Navigator.of(context).pop(); // Closes the dialog
                  },
                ),
                TextButton(
                  child: const Text('No'),
                  onPressed: () {
                    setState(() {
                      deleteRooms = false;
                      deleteRoomsSelected = true;
                      print("User selected: No");
                    });
                    Navigator.of(context).pop(); // Closes the dialog
                  },
                ),
              ],
            );
          },
        );
      } else {
        setState(() {
          deleteRooms = false;
          deleteRoomsSelected = true;
        });
      }
    });
  }

  late BluetoothCharacteristic targetCharacteristic;
  String connectionText = "";

  discoverServices() async {
    print("Running discover services for device: ${widget.device.toString()}");

    List<BluetoothService> services = await widget.device.discoverServices();
    print("Discovered services: $services");

    for (var service in services) {
      if (service.uuid.toString() == SERVICE_UUID) {
        print("Service found: ${service.uuid}");
        for (var characteristics in service.characteristics) {
          if (characteristics.uuid.toString() == CHARACTERISTIC_UUID) {
            setState(() {
              targetCharacteristic = characteristics;
              connectionText = "WIFI SETUP";
              print("Target characteristic set: ${targetCharacteristic.uuid}");
              readBLE();
            });
          }
        }
      }
    }
    targetCharacteristic.setNotifyValue(true);
    print("Notification set for target characteristic.");
  }

  writeData(String data) async {
    print("Writing data: $data");
    List<int> bytes = utf8.encode(data);
    await targetCharacteristic.write(bytes);
    // Removed the print statement since write() returns void
  }

  submitAction() async {
    var wifiData = '$firstWifi,${wifiPasswordController.text}';
    print("Submitting WiFi data: $wifiData");

    // Write to Firestore
    final userId =
        FirebaseAuth.instance.currentUser!.uid; // Get the current user's ID
    final db = FirebaseFirestore.instance;
    if (!portSSID) {
      try {
        await db.collection('users').doc(userId).set(
            {
              'SSID': firstWifi, // Write firstWifi to SSID field
              'password': wifiPasswordController
                  .text, // Write password to password field
            },
            SetOptions(
                merge: true)); // Use merge to avoid overwriting other fields
        print("WiFi credentials saved successfully.");
      } catch (e) {
        print("Error saving WiFi credentials: $e");
      }
    } else {
      wifiData = '$storedSSID,$storedPassword';
    }
    // Continue with the rest of the submit action
    writeData(wifiData);

    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (context) {
        print("Navigating to Authenticate screen.");
        return const Authenticate();
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
    print("Reading data from BLE characteristic.");
    var res = await targetCharacteristic.read();
    final dataController = Momentum.controller<DataController>(context);

    print("Read result: ${res.toString()}");
    setState(() {
      readData = utf8.decode(res);
    });
    print("Decoded read data: $readData");

    // SPLIT SSIDS and Doors
    temp = readData.split(',').toList();
    print("Split data into temp: $temp");

    for (var element in temp) {
      temp1.add(element.toString());
    }
    print("Temp1 after adding elements: $temp1");

    String wifiIDTemp = temp1
        .toList()
        .sublist(0, 10)
        .toString()
        .replaceAll(', 0', '')
        .replaceAll(', ', ',');

    print("Processed WiFi IDs: $wifiIDTemp");

    wifiIDs = wifiIDTemp
        .replaceRange(0, 1, '')
        .replaceRange(wifiIDTemp.length - 2, wifiIDTemp.length - 1, '')
        .split(',')
        .toSet()
        .toList();

    firstWifi = wifiIDs[0].toString();
    print("First WiFi ID: $firstWifi");

    roomsIds = temp1.toList().sublist(10);
    print("Room IDs: $roomsIds");

    // DELETE OLD ROOMS HERE
    final db = FirebaseFirestore.instance;
    var userId = FirebaseAuth.instance.currentUser!.uid.toString();

    print("CHECKING IF SSID Already Stored");

    DocumentSnapshot userDoc = await db.collection('users').doc(userId).get();
    try {
      storedSSID = userDoc['SSID'];
      storedPassword = userDoc['password'];
    } catch (e) {
      print("Error while fetching stored SSID and password: $e");
    }
    print('Stored SSID: $storedSSID');
    print('Stored Password: $storedPassword');

    bool matchedSSID = wifiIDs.contains(storedSSID);

    print('Matched SSID: $matchedSSID');

    print("Fetching rooms for user ID: $userId");

    while (!deleteRoomsSelected) {
      await Future.delayed(const Duration(seconds: 1));
    }
    var result =
        await db.collection('rooms').where("userId", isEqualTo: userId).get();
    for (var res in result.docs) {
      if (deleteRooms) {
        print("Deleting old room: ${res.id}");
        FirebaseFirestore.instance.collection('rooms').doc(res.id).delete();
      } else {
        print("Not deleting old room: ${res.id}");
      }
    }

    var index = 1;
    var roomIndex = 1;
    List<String> roomNames = ["", "FRONT", "BACK", "PATIO", "GARAGE", ""];

    // ADD ROOMS
    for (int i = 0; i < roomsIds.length; i += 2) {
      print("Adding room with ID: ${roomsIds[i]}");
      FirebaseFirestore.instance.collection('rooms').add({
        'name': roomNames[index],
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'state': 0,
        'displayOrder': index - 1, // Use index - 1 since index starts at 1
        'sharedWith': []
      }).then((doc) {
        FirebaseFirestore.instance
            .collection('rooms')
            .doc(doc.id)
            .update({'roomId': doc.id});
        print("Room added with ID: ${doc.id}");

        // ONE MONITOR
        if (roomsIds[i + 1].toString().length == 14) {
          if (roomsIds[i] != "0") {
            dataController.addDevice(
                roomsIds[i],
                FirebaseAuth.instance.currentUser!.uid,
                roomNames[roomIndex],
                true,
                doc.id);
            print("Device added for room: ${roomNames[roomIndex]}");
          }
        } else {
          // TWO MONITORS
          if (roomsIds[i] != "0") {
            dataController.addDevice(
                roomsIds[i],
                FirebaseAuth.instance.currentUser!.uid,
                roomNames[roomIndex],
                true,
                doc.id);
            print("Indoor device added for room: ${roomNames[roomIndex]}");
          }
          if (roomsIds[i + 1] != "0") {
            dataController.addDevice(
                roomsIds[i + 1],
                FirebaseAuth.instance.currentUser!.uid,
                // '${roomNames[roomIndex]} OUTSIDE',
                roomNames[roomIndex],
                false,
                doc.id);
            print("Outdoor device added for room: ${roomNames[roomIndex]}");
          }
        }

        roomIndex++;
      });
      index++;
    }

    setState(() {
      isLoading = false;
    });
    print("Finished reading BLE and processing data.");

    if (matchedSSID) {
      print('Creating dialogue box for port SSID check');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Use existing hub password?'),
            content: Text('SSID: $storedSSID'),
            actions: <Widget>[
              TextButton(
                child: const Text('No'),
                onPressed: () {
                  print('User selected No');
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('Yes'),
                onPressed: () {
                  print('User selected Yes');
                  portSSID = true;
                  Navigator.of(context).pop();
                  submitAction();
                },
              ),
            ],
          );
        },
      );
    }
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
          ? const Center(
              child: Text("Creating rooms and doors please wait..."),
            )
          : Container(
              child: targetCharacteristic == null
                  ? const Center(
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
                                  const InputDecoration(labelText: 'Wifi Password'),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: ElevatedButton(
                              onPressed: submitAction,
                              child: const Text('Submit'),
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
