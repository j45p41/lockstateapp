import 'dart:async';

import 'package:flutter/material.dart';

import 'package:lockstate/screens/device_paired_screen.dart';
import 'package:lockstate/utils/color_utils.dart';
import 'package:lockstate/utils/globals.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class AddHubScreen extends StatefulWidget {
  @override
  _AddHubScreenState createState() => _AddHubScreenState();
}

class _AddHubScreenState extends State<AddHubScreen> {
  bool isScanned = false;
  FlutterBluePlus _flutterBlue = FlutterBluePlus.instance;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late StreamSubscription _scanSubscription;
  Map<DeviceIdentifier, ScanResult> scanResults = new Map();
  bool isScanning = false;
  late Map<Permission, PermissionStatus> statuses;
  bool isFound = false;
  late ScanResult scanResult;
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
    _scanSubscription.cancel();
    // _scanSubscription = null;
    setState(() {
      isScanning = false;
    });
  }

  startScan() {
    print("start scan");
    _scanSubscription = _flutterBlue
        .scan(
      timeout: const Duration(seconds: 500),
      /*withServices: [
          new Guid('0000180F-0000-1000-8000-00805F9B34FB')
        ]*/
    )
        .listen((scanResult) {
      setState(() {
        print(scanResult);
        scanResults[scanResult.device.id] = scanResult;
      });
    }, onDone: stopScan);

    setState(() {
      isScanning = true;
      isScanned = true;
      scanResults.clear();
    });
    // var temp = scanResults.values
    //     .where((r) => r.device.name.contains("LOCKSURE_HUB"))
    //     .toList()[0];
    // if (temp != null) {
    //   stopScan();
    //   setState(() {
    //     scanResult = temp;
    //     isFound = true;
    //   });
    // }
  }

  @override
  void initState() {
    // startScan();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var mq = MediaQuery.of(context).size;
    return Theme(
      data: Theme.of(context),
      child: Scaffold(
        backgroundColor: Color(ColorUtils.colorDarkGrey),
        appBar: AppBar(
          title: Text(
            "Add hub",
            style: TextStyle(color: Colors.white, fontSize: 21),
          ),
          actions: [
            IconButton(
              onPressed: startScan,
              icon: Icon(Icons.ac_unit),
            ),
          ],
        ),
        body: Center(
          child: state == BluetoothState.off
              ? Text(
                  "Oops, Please Enable Bluetooth and Location",
                )
              : StreamBuilder<ScanResult>(
                  stream: _flutterBlue.scan(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircularProgressIndicator();
                    }
                    // if (snapshot.data!.device.name.contains("LOCKSURE_HUB")) {
                    //   isFound = true;
                    //   scanResult = snapshot.data!;
                    // }
                    print("snapshot data " + snapshot.data!.device.name);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 20,
                          ),
                          Center(
                            child: Text(
                              isFound
                                  ? "Locksure Mini Hub Found!"
                                  : "Hold your finger on the Volume Up + Key and then switch the Hub Off and On Again",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 20,
                          ),
                          Container(
                            padding: EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Image.asset(isFound
                                ? "assets/images/minihub.png"
                                : "assets/images/hub_tilted.png"),
                          ),
                          SizedBox(
                            height: 30,
                          ),
                          Spacer(),
                          if (isFound)
                            GestureDetector(
                              onTap: () async {
                                await scanResult.device
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
                                          "Selected device scan screen= ${scanResult.device.id}");
                                      return DevicePairedScreen(
                                        scanResult.device,
                                      );
                                    },
                                  ),
                                );
                              },
                              child: Container(
                                // padding: const EdgeInsets.all(15.0),
                                height: 65,
                                width: double.infinity,
                                decoration: new BoxDecoration(
                                  // shape: BoxShape.rectangle,
                                  borderRadius: BorderRadius.circular(10),

                                  color: Color(ColorUtils.color2),
                                ),
                                child: Center(
                                  child: Text(
                                    "Continue",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
          // ListView(
          //     padding: EdgeInsets.symmetric(
          //       vertical: mq.height * 0.02,
          //       horizontal: mq.width * 0.05,
          //     ),
          //     children: <Widget>[
          //       Column(
          //           children: scanResults.values
          //               .map((r) => GestureDetector(
          //                     onTap: () async {
          // await r.device
          //     .connect(
          //         // autoConnect: true,
          //         // timeout: Duration(seconds: 5),
          //         )
          //     .whenComplete(() {
          //   print(
          //       '-------------Device connected----------------');
          // }).catchError((e) {
          //   print(e);
          // });
          // Navigator.of(context).push(
          //   MaterialPageRoute(
          //     builder: (BuildContext context) {
          //       print(
          //           "Selected device scan screen= ${r.device.id}");
          //       return DevicePairedScreen(
          //         r.device,
          //       );
          //     },
          //   ),
          // );
          //                     },
          //                     child: Container(
          //                       padding: EdgeInsets.all(8),
          //                       margin: EdgeInsets.only(
          //                         bottom: 20,
          //                         right: 25,
          //                         left: 25,
          //                       ),
          //                       decoration: BoxDecoration(
          //                         borderRadius: BorderRadius.circular(25),
          //                         color: Theme.of(context).primaryColor,
          //                         // boxShadow: [
          //                         //   BoxShadow(
          //                         //     color: Colors.black45,
          //                         //     blurRadius: 1,
          //                         //     spreadRadius: 1,
          //                         //   )
          //                         // ],
          //                       ),
          //                       child: Row(
          //                         children: [
          //                           Expanded(
          //                             flex: 4,
          //                             child: Container(
          //                               margin: EdgeInsets.symmetric(
          //                                 horizontal: 14,
          //                                 vertical: 10,
          //                               ),
          //                               child: Column(
          //                                 mainAxisAlignment:
          //                                     MainAxisAlignment.spaceAround,
          //                                 crossAxisAlignment:
          //                                     CrossAxisAlignment.center,
          //                                 children: [
          //                                   Text(
          //                                     r.device.name,
          //                                     style: TextStyle(
          //                                         fontSize: 26,
          //                                         fontWeight:
          //                                             FontWeight.w700),
          //                                   ),
          //                                   // SizedBox(
          //                                   //   height: mq.height * 0.02,
          //                                   // ),
          //                                   // Text(
          //                                   //   r.device.id.toString(),
          //                                   //   style:
          //                                   //       TextStyle(fontSize: 16),
          //                                   // ),
          //                                   // SizedBox(
          //                                   //   height: mq.height * 0.02,
          //                                   // ),
          //                                 ],
          //                               ),
          //                             ),
          //                           ),
          //                           Expanded(
          //                             child: StreamBuilder<
          //                                 BluetoothDeviceState>(
          //                               stream: r.device.state,
          //                               initialData: BluetoothDeviceState
          //                                   .disconnected,
          //                               builder: (c, snapshot) {
          //                                 if (snapshot.data ==
          //                                     BluetoothDeviceState
          //                                         .connected) {
          //                                   Globals.isConnected = true;
          //                                   return Icon(
          //                                     Icons.bluetooth_connected,
          //                                     size: 25,
          //                                   );
          //                                 }
          //                                 return Icon(
          //                                   Icons.bluetooth_disabled,
          //                                   size: 25,
          //                                 );
          //                               },
          //                             ),
          //                             flex: 1,
          //                           ),
          //                           Expanded(
          //                             child: Icon(
          //                               Icons.arrow_forward_ios_rounded,
          //                             ),
          //                             flex: 1,
          //                           )
          //                         ],
          //                       ),
          //                     ),
          //                   ))
          //               .toList()),
          //       Column(
          //         children: [
          //           isScanned
          //               ? Text(
          //                   "Select the device you wish to pair.",
          //                   style: TextStyle(color: Colors.grey[600]),
          //                 )
          //               : Text(
          //                   "Turn on your device and then activate\nBluetooth on your mobile. ",
          //                   textAlign: TextAlign.center,
          //                   style: TextStyle(color: Colors.grey[600]),
          //                 ),
          //           SizedBox(
          //             height: 25,
          //           ),
          //           isScanning
          //               ? Center(
          //                   child: CircularProgressIndicator(),
          //                 )
          //               : GestureDetector(
          //                   onTap: startScan,
          //                   child: Container(
          //                     height: mq.height * 0.042,
          //                     width: mq.width * 0.6,
          //                     decoration: BoxDecoration(
          //                         borderRadius: BorderRadius.circular(12),
          //                         color: Theme.of(context).buttonColor,
          //                         boxShadow: [
          //                           BoxShadow(
          //                               blurRadius: 1,
          //                               color: Colors.black26,
          //                               spreadRadius: 1.3),
          //                         ]),
          //                     child: Center(
          //                       child: Text(
          //                         isScanned
          //                             ? "RESCAN FOR DEVICES"
          //                             : "PAIR DEVICE",
          //                         style: TextStyle(
          //                             fontSize: 18,
          //                             fontWeight: FontWeight.w400),
          //                       ),
          //                     ),
          //                   ),
          //                 ),
          //         ],
          //       ),
          //     ],
          //   ),
        ),
      ),
    );
  }
}
