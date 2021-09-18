import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:lockstate/screens/device_paired_screen.dart';
import 'package:lockstate/utils/globals.dart';
import 'package:permission_handler/permission_handler.dart';

class AddHubScreen extends StatefulWidget {
  @override
  _AddHubScreenState createState() => _AddHubScreenState();
}

class _AddHubScreenState extends State<AddHubScreen> {
  bool isScanned = false;
  FlutterBlue _flutterBlue = FlutterBlue.instance;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  late StreamSubscription _scanSubscription;
  Map<DeviceIdentifier, ScanResult> scanResults = new Map();
  bool isScanning = false;
  late Map<Permission, PermissionStatus> statuses;

  BluetoothState state = BluetoothState.unknown;
  requestPerm() async {
    print("Requesting permissions");
    statuses = await [
      Permission.location,
      Permission.locationWhenInUse,
      Permission.unknown,
    ].request();
  }

  stopScan() {
    _scanSubscription?.cancel();
    // _scanSubscription = null;
    setState(() {
      isScanning = false;
    });
  }

  startScan() {
    _scanSubscription = _flutterBlue
        .scan(
      timeout: const Duration(seconds: 10),
      /*withServices: [
          new Guid('0000180F-0000-1000-8000-00805F9B34FB')
        ]*/
    )
        .listen((scanResult) {
      setState(() {
        scanResults[scanResult.device.id] = scanResult;
      });
    }, onDone: stopScan);

    setState(() {
      isScanning = true;
      isScanned = true;
      scanResults.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    var mq = MediaQuery.of(context).size;
    return Theme(
      data: Theme.of(context),
      child: Scaffold(
        appBar: AppBar(
          actions: [],
          leadingWidth: mq.width * 0.2,
          leading: Row(
            children: [
              Expanded(child: Container(), flex: 1),
              Expanded(
                flex: 3,
                child: Image.asset(
                  'assets/small-wetrics@2x.png',
                ),
              ),
            ],
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.start,
          ),
          title: Text(
            !isScanned ? "Set up your device" : "Available Devices",
            style:
                TextStyle(color: Colors.black, letterSpacing: 2, fontSize: 21),
          ),
        ),
        body: Center(
          child: state == BluetoothState.off
              ? Text(
                  "Oops, Please Enable Bluetooth and Location",
                )
              : ListView(
                  padding: EdgeInsets.symmetric(
                    vertical: mq.height * 0.02,
                    horizontal: mq.width * 0.05,
                  ),
                  children: <Widget>[
                    Column(
                        children: scanResults.values
                            .map((r) => GestureDetector(
                                  onTap: () async {
                                    await r.device
                                        .connect(
                                            // autoConnect: true,
                                            // timeout: Duration(seconds: 5),
                                            )
                                        .whenComplete(() {
                                      print(
                                          '-------------Device connected----------------');
                                    }).catchError((e) {
                                      print(e);
                                    });
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (BuildContext context) {
                                          print(
                                              "Selected device scan screen= ${r.device.id}");
                                          return DevicePairedScreen(
                                            r.device,
                                          );
                                        },
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(8),
                                    margin: EdgeInsets.only(
                                      bottom: 20,
                                      right: 25,
                                      left: 25,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(25),
                                      color: Theme.of(context).primaryColor,
                                      // boxShadow: [
                                      //   BoxShadow(
                                      //     color: Colors.black45,
                                      //     blurRadius: 1,
                                      //     spreadRadius: 1,
                                      //   )
                                      // ],
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 4,
                                          child: Container(
                                            margin: EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceAround,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Text(
                                                  r.device.name,
                                                  style: TextStyle(
                                                      fontSize: 26,
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w700),
                                                ),
                                                // SizedBox(
                                                //   height: mq.height * 0.02,
                                                // ),
                                                // Text(
                                                //   r.device.id.toString(),
                                                //   style:
                                                //       TextStyle(fontSize: 16),
                                                // ),
                                                // SizedBox(
                                                //   height: mq.height * 0.02,
                                                // ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: StreamBuilder<
                                              BluetoothDeviceState>(
                                            stream: r.device.state,
                                            initialData: BluetoothDeviceState
                                                .disconnected,
                                            builder: (c, snapshot) {
                                              if (snapshot.data ==
                                                  BluetoothDeviceState
                                                      .connected) {
                                                Globals.isConnected = true;
                                                return Icon(
                                                  Icons.bluetooth_connected,
                                                  color: Colors.white,
                                                  size: 25,
                                                );
                                              }
                                              return Icon(
                                                Icons.bluetooth_disabled,
                                                color: Colors.white,
                                                size: 25,
                                              );
                                            },
                                          ),
                                          flex: 1,
                                        ),
                                        Expanded(
                                          child: Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            color: Colors.white,
                                          ),
                                          flex: 1,
                                        )
                                      ],
                                    ),
                                  ),
                                ))
                            .toList()),
                    Column(
                      children: [
                        isScanned
                            ? Text(
                                "Select the device you wish to pair.",
                                style: TextStyle(color: Colors.grey[600]),
                              )
                            : Text(
                                "Turn on your device and then activate\nBluetooth on your mobile. ",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                        SizedBox(
                          height: 25,
                        ),
                        isScanning
                            ? Center(
                                child: CircularProgressIndicator(),
                              )
                            : GestureDetector(
                                onTap: startScan,
                                child: Container(
                                  height: mq.height * 0.042,
                                  width: mq.width * 0.6,
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Theme.of(context).buttonColor,
                                      boxShadow: [
                                        BoxShadow(
                                            blurRadius: 1,
                                            color: Colors.black26,
                                            spreadRadius: 1.3),
                                      ]),
                                  child: Center(
                                    child: Text(
                                      isScanned
                                          ? "RESCAN FOR DEVICES"
                                          : "PAIR DEVICE",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w400),
                                    ),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
