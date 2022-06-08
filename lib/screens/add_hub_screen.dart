import 'dart:async';
import 'dart:io';

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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Devices'),
        actions: [
          ElevatedButton(
            child: const Text('TURN OFF'),
            style: ElevatedButton.styleFrom(
              primary: Colors.black,
              onPrimary: Colors.white,
            ),
            onPressed: Platform.isAndroid
                ? () => FlutterBluePlus.instance.turnOff()
                : null,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => FlutterBluePlus.instance
            .startScan(timeout: const Duration(seconds: 4)),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              StreamBuilder<List<BluetoothDevice>>(
                stream: Stream.periodic(const Duration(seconds: 2))
                    .asyncMap((_) => FlutterBluePlus.instance.connectedDevices),
                initialData: const [],
                builder: (c, snapshot) => Column(
                  children: snapshot.data!
                      .map((d) => ListTile(
                            title: Text(d.name),
                            subtitle: Text(d.id.toString()),
                            trailing: StreamBuilder<BluetoothDeviceState>(
                              stream: d.state,
                              initialData: BluetoothDeviceState.disconnected,
                              builder: (c, snapshot) {
                                if (snapshot.data ==
                                    BluetoothDeviceState.connected) {
                                  return ElevatedButton(
                                    child: const Text('OPEN'),
                                    onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                DevicePairedScreen(d))),
                                  );
                                }
                                return Text(snapshot.data.toString());
                              },
                            ),
                          ))
                      .toList(),
                ),
              ),
              StreamBuilder<List<ScanResult>>(
                stream: FlutterBluePlus.instance.scanResults,
                initialData: const [],
                builder: (c, snapshot) => Column(
                  children: snapshot.data!
                      .map(
                        (r) => ScanResultTile(
                            result: r,
                            onTap: () async {
                              await r.device.connect();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) {
                                    return DevicePairedScreen(r.device);
                                  },
                                ),
                              );
                            }),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: StreamBuilder<bool>(
        stream: FlutterBluePlus.instance.isScanning,
        initialData: false,
        builder: (c, snapshot) {
          if (snapshot.data!) {
            return FloatingActionButton(
              child: const Icon(Icons.stop),
              onPressed: () => FlutterBluePlus.instance.stopScan(),
              backgroundColor: Colors.red,
            );
          } else {
            return FloatingActionButton(
                child: const Icon(Icons.search),
                onPressed: () => FlutterBluePlus.instance
                    .startScan(timeout: const Duration(seconds: 4)));
          }
        },
      ),
    );
  }
  // bool isScanned = false;
  // FlutterBluePlus _flutterBlue = FlutterBluePlus.instance;
  // final scaffoldKey = GlobalKey<ScaffoldState>();
  // late StreamSubscription _scanSubscription;
  // Map<DeviceIdentifier, ScanResult> scanResults = new Map();
  // bool isScanning = false;
  // late Map<Permission, PermissionStatus> statuses;
  // bool isFound = false;
  // late ScanResult scanResult;
  // BluetoothState state = BluetoothState.unknown;
  // requestPerm() async {
  //   print("Requesting permissions");
  //   statuses = await [
  //     Permission.location,
  //     Permission.locationWhenInUse,
  //     Permission.unknown,
  //   ].request();
  // }

  // stopScan() {
  //   _scanSubscription.cancel();
  //   // _scanSubscription = null;
  //   setState(() {
  //     isScanning = false;
  //   });
  // }

  // startScan() {
  //   print("start scan");
  //   _scanSubscription = _flutterBlue
  //       .scan(
  //     timeout: const Duration(seconds: 500),
  //     /*withServices: [
  //         new Guid('0000180F-0000-1000-8000-00805F9B34FB')
  //       ]*/
  //   )
  //       .listen((scanResult) {
  //     setState(() {
  //       print(scanResult);
  //       scanResults[scanResult.device.id] = scanResult;
  //     });
  //   }, onDone: stopScan);

  //   setState(() {
  //     isScanning = true;
  //     isScanned = true;
  //     scanResults.clear();
  //   });
  //   // var temp = scanResults.values
  //   //     .where((r) => r.device.name.contains("LOCKSURE_HUB"))
  //   //     .toList()[0];
  //   // if (temp != null) {
  //   //   stopScan();
  //   //   setState(() {
  //   //     scanResult = temp;
  //   //     isFound = true;
  //   //   });
  //   // }
  // }

  // @override
  // void initState() {
  //   // startScan();
  //   super.initState();
  // }

  // @override
  // Widget build(BuildContext context) {
  //   var mq = MediaQuery.of(context).size;
  //   return Theme(
  //     data: Theme.of(context),
  //     child: Scaffold(
  //       backgroundColor: Color(ColorUtils.colorDarkGrey),
  //       appBar: AppBar(
  //         title: Text(
  //           "Add hub",
  //           style: TextStyle(color: Colors.white, fontSize: 21),
  //         ),
  //         actions: [
  //           IconButton(
  //             onPressed: startScan,
  //             icon: Icon(Icons.ac_unit),
  //           ),
  //         ],
  //       ),
  //       body: Center(
  //         child: state == BluetoothState.off
  //             ? Text(
  //                 "Oops, Please Enable Bluetooth and Location",
  //               )
  //             : StreamBuilder<ScanResult>(
  //                 stream: _flutterBlue.scan(),
  //                 builder: (context, snapshot) {
  //                   if (snapshot.connectionState == ConnectionState.waiting) {
  //                     return CircularProgressIndicator();
  //                   }
  //                   // if (snapshot.data!.device.name.contains("LOCKSURE_HUB")) {
  //                   //   isFound = true;
  //                   //   scanResult = snapshot.data!;
  //                   // }
  //                   print("snapshot data " + snapshot.data!.device.name);

  //                   return Padding(
  //                     padding: const EdgeInsets.symmetric(horizontal: 20.0),
  //                     child: Column(
  //                       children: [
  //                         SizedBox(
  //                           height: 20,
  //                         ),
  //                         Center(
  //                           child: Text(
  //                             isFound
  //                                 ? "Locksure Mini Hub Found!"
  //                                 : "Hold your finger on the Volume Up + Key and then switch the Hub Off and On Again",
  //                             textAlign: TextAlign.center,
  //                             style: TextStyle(
  //                               color: Colors.white,
  //                               fontSize: 16,
  //                               fontWeight: FontWeight.w600,
  //                             ),
  //                           ),
  //                         ),
  //                         SizedBox(
  //                           height: 20,
  //                         ),
  //                         Container(
  //                           padding: EdgeInsets.all(15),
  //                           decoration: BoxDecoration(
  //                             color: Colors.white,
  //                             shape: BoxShape.circle,
  //                           ),
  //                           child: Image.asset(isFound
  //                               ? "assets/images/minihub.png"
  //                               : "assets/images/hub_tilted.png"),
  //                         ),
  //                         SizedBox(
  //                           height: 30,
  //                         ),
  //                         Spacer(),
  //                         if (isFound)
  //                           GestureDetector(
  //                             onTap: () async {
  //                               await scanResult.device
  //                                   .connect(
  //                                       // autoConnect: true,
  //                                       // timeout: Duration(seconds: 5),
  //                                       )
  //                                   .whenComplete(() {
  //                                 print(
  //                                     '-------------Device connected----------------');
  //                               }).catchError((e) {
  //                                 print(e);
  //                               });
  //                               Navigator.of(context).push(
  //                                 MaterialPageRoute(
  //                                   builder: (BuildContext context) {
  //                                     print(
  //                                         "Selected device scan screen= ${scanResult.device.id}");
  //                                     return DevicePairedScreen(
  //                                       scanResult.device,
  //                                     );
  //                                   },
  //                                 ),
  //                               );
  //                             },
  //                             child: Container(
  //                               // padding: const EdgeInsets.all(15.0),
  //                               height: 65,
  //                               width: double.infinity,
  //                               decoration: new BoxDecoration(
  //                                 // shape: BoxShape.rectangle,
  //                                 borderRadius: BorderRadius.circular(10),

  //                                 color: Color(ColorUtils.color2),
  //                               ),
  //                               child: Center(
  //                                 child: Text(
  //                                   "Continue",
  //                                   style: TextStyle(
  //                                       color: Colors.white,
  //                                       fontSize: 14,
  //                                       fontWeight: FontWeight.w800),
  //                                 ),
  //                               ),
  //                             ),
  //                           ),
  //                       ],
  //                     ),
  //                   );
  //                 }),
  //         // ListView(
  //         //     padding: EdgeInsets.symmetric(
  //         //       vertical: mq.height * 0.02,
  //         //       horizontal: mq.width * 0.05,
  //         //     ),
  //         //     children: <Widget>[
  //         //       Column(
  //         //           children: scanResults.values
  //         //               .map((r) => GestureDetector(
  //         //                     onTap: () async {
  //         // await r.device
  //         //     .connect(
  //         //         // autoConnect: true,
  //         //         // timeout: Duration(seconds: 5),
  //         //         )
  //         //     .whenComplete(() {
  //         //   print(
  //         //       '-------------Device connected----------------');
  //         // }).catchError((e) {
  //         //   print(e);
  //         // });
  //         // Navigator.of(context).push(
  //         //   MaterialPageRoute(
  //         //     builder: (BuildContext context) {
  //         //       print(
  //         //           "Selected device scan screen= ${r.device.id}");
  //         //       return DevicePairedScreen(
  //         //         r.device,
  //         //       );
  //         //     },
  //         //   ),
  //         // );
  //         //                     },
  //         //                     child: Container(
  //         //                       padding: EdgeInsets.all(8),
  //         //                       margin: EdgeInsets.only(
  //         //                         bottom: 20,
  //         //                         right: 25,
  //         //                         left: 25,
  //         //                       ),
  //         //                       decoration: BoxDecoration(
  //         //                         borderRadius: BorderRadius.circular(25),
  //         //                         color: Theme.of(context).primaryColor,
  //         //                         // boxShadow: [
  //         //                         //   BoxShadow(
  //         //                         //     color: Colors.black45,
  //         //                         //     blurRadius: 1,
  //         //                         //     spreadRadius: 1,
  //         //                         //   )
  //         //                         // ],
  //         //                       ),
  //         //                       child: Row(
  //         //                         children: [
  //         //                           Expanded(
  //         //                             flex: 4,
  //         //                             child: Container(
  //         //                               margin: EdgeInsets.symmetric(
  //         //                                 horizontal: 14,
  //         //                                 vertical: 10,
  //         //                               ),
  //         //                               child: Column(
  //         //                                 mainAxisAlignment:
  //         //                                     MainAxisAlignment.spaceAround,
  //         //                                 crossAxisAlignment:
  //         //                                     CrossAxisAlignment.center,
  //         //                                 children: [
  //         //                                   Text(
  //         //                                     r.device.name,
  //         //                                     style: TextStyle(
  //         //                                         fontSize: 26,
  //         //                                         fontWeight:
  //         //                                             FontWeight.w700),
  //         //                                   ),
  //         //                                   // SizedBox(
  //         //                                   //   height: mq.height * 0.02,
  //         //                                   // ),
  //         //                                   // Text(
  //         //                                   //   r.device.id.toString(),
  //         //                                   //   style:
  //         //                                   //       TextStyle(fontSize: 16),
  //         //                                   // ),
  //         //                                   // SizedBox(
  //         //                                   //   height: mq.height * 0.02,
  //         //                                   // ),
  //         //                                 ],
  //         //                               ),
  //         //                             ),
  //         //                           ),
  //         //                           Expanded(
  //         //                             child: StreamBuilder<
  //         //                                 BluetoothDeviceState>(
  //         //                               stream: r.device.state,
  //         //                               initialData: BluetoothDeviceState
  //         //                                   .disconnected,
  //         //                               builder: (c, snapshot) {
  //         //                                 if (snapshot.data ==
  //         //                                     BluetoothDeviceState
  //         //                                         .connected) {
  //         //                                   Globals.isConnected = true;
  //         //                                   return Icon(
  //         //                                     Icons.bluetooth_connected,
  //         //                                     size: 25,
  //         //                                   );
  //         //                                 }
  //         //                                 return Icon(
  //         //                                   Icons.bluetooth_disabled,
  //         //                                   size: 25,
  //         //                                 );
  //         //                               },
  //         //                             ),
  //         //                             flex: 1,
  //         //                           ),
  //         //                           Expanded(
  //         //                             child: Icon(
  //         //                               Icons.arrow_forward_ios_rounded,
  //         //                             ),
  //         //                             flex: 1,
  //         //                           )
  //         //                         ],
  //         //                       ),
  //         //                     ),
  //         //                   ))
  //         //               .toList()),
  //         //       Column(
  //         //         children: [
  //         //           isScanned
  //         //               ? Text(
  //         //                   "Select the device you wish to pair.",
  //         //                   style: TextStyle(color: Colors.grey[600]),
  //         //                 )
  //         //               : Text(
  //         //                   "Turn on your device and then activate\nBluetooth on your mobile. ",
  //         //                   textAlign: TextAlign.center,
  //         //                   style: TextStyle(color: Colors.grey[600]),
  //         //                 ),
  //         //           SizedBox(
  //         //             height: 25,
  //         //           ),
  //         //           isScanning
  //         //               ? Center(
  //         //                   child: CircularProgressIndicator(),
  //         //                 )
  //         //               : GestureDetector(
  //         //                   onTap: startScan,
  //         //                   child: Container(
  //         //                     height: mq.height * 0.042,
  //         //                     width: mq.width * 0.6,
  //         //                     decoration: BoxDecoration(
  //         //                         borderRadius: BorderRadius.circular(12),
  //         //                         color: Theme.of(context).buttonColor,
  //         //                         boxShadow: [
  //         //                           BoxShadow(
  //         //                               blurRadius: 1,
  //         //                               color: Colors.black26,
  //         //                               spreadRadius: 1.3),
  //         //                         ]),
  //         //                     child: Center(
  //         //                       child: Text(
  //         //                         isScanned
  //         //                             ? "RESCAN FOR DEVICES"
  //         //                             : "PAIR DEVICE",
  //         //                         style: TextStyle(
  //         //                             fontSize: 18,
  //         //                             fontWeight: FontWeight.w400),
  //         //                       ),
  //         //                     ),
  //         //                   ),
  //         //                 ),
  //         //         ],
  //         //       ),
  //         //     ],
  //         //   ),
  //       ),
  //     ),
  //   );
  // }
}

class ScanResultTile extends StatelessWidget {
  const ScanResultTile({Key? key, required this.result, this.onTap})
      : super(key: key);

  final ScanResult result;
  final VoidCallback? onTap;

  Widget _buildTitle(BuildContext context) {
    if (result.device.name.isNotEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            result.device.name,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            result.device.id.toString(),
            style: Theme.of(context).textTheme.caption,
          )
        ],
      );
    } else {
      return Text(result.device.id.toString());
    }
  }

  Widget _buildAdvRow(BuildContext context, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.caption),
          const SizedBox(
            width: 12.0,
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .caption
                  ?.apply(color: Colors.black),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  String getNiceHexArray(List<int> bytes) {
    return '[${bytes.map((i) => i.toRadixString(16).padLeft(2, '0')).join(', ')}]'
        .toUpperCase();
  }

  String getNiceManufacturerData(Map<int, List<int>> data) {
    if (data.isEmpty) {
      return 'N/A';
    }
    List<String> res = [];
    data.forEach((id, bytes) {
      res.add(
          '${id.toRadixString(16).toUpperCase()}: ${getNiceHexArray(bytes)}');
    });
    return res.join(', ');
  }

  String getNiceServiceData(Map<String, List<int>> data) {
    if (data.isEmpty) {
      return 'N/A';
    }
    List<String> res = [];
    data.forEach((id, bytes) {
      res.add('${id.toUpperCase()}: ${getNiceHexArray(bytes)}');
    });
    return res.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: _buildTitle(context),
      leading: Text(result.rssi.toString()),
      trailing: ElevatedButton(
        child: const Text('CONNECT'),
        style: ElevatedButton.styleFrom(
          primary: Colors.black,
          onPrimary: Colors.white,
        ),
        onPressed: (result.advertisementData.connectable) ? onTap : null,
      ),
      children: <Widget>[
        _buildAdvRow(
            context, 'Complete Local Name', result.advertisementData.localName),
        _buildAdvRow(context, 'Tx Power Level',
            '${result.advertisementData.txPowerLevel ?? 'N/A'}'),
        _buildAdvRow(context, 'Manufacturer Data',
            getNiceManufacturerData(result.advertisementData.manufacturerData)),
        _buildAdvRow(
            context,
            'Service UUIDs',
            (result.advertisementData.serviceUuids.isNotEmpty)
                ? result.advertisementData.serviceUuids.join(', ').toUpperCase()
                : 'N/A'),
        _buildAdvRow(context, 'Service Data',
            getNiceServiceData(result.advertisementData.serviceData)),
      ],
    );
  }
}

class ServiceTile extends StatelessWidget {
  final BluetoothService service;
  final List<CharacteristicTile> characteristicTiles;

  const ServiceTile(
      {Key? key, required this.service, required this.characteristicTiles})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (characteristicTiles.isNotEmpty) {
      return ExpansionTile(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Service'),
            Text('0x${service.uuid.toString().toUpperCase().substring(4, 8)}',
                style: Theme.of(context).textTheme.bodyText1?.copyWith(
                    color: Theme.of(context).textTheme.caption?.color))
          ],
        ),
        children: characteristicTiles,
      );
    } else {
      return ListTile(
        title: const Text('Service'),
        subtitle:
            Text('0x${service.uuid.toString().toUpperCase().substring(4, 8)}'),
      );
    }
  }
}

class CharacteristicTile extends StatelessWidget {
  final BluetoothCharacteristic characteristic;
  final List<DescriptorTile> descriptorTiles;
  final VoidCallback? onReadPressed;
  final VoidCallback? onWritePressed;
  final VoidCallback? onNotificationPressed;

  const CharacteristicTile(
      {Key? key,
      required this.characteristic,
      required this.descriptorTiles,
      this.onReadPressed,
      this.onWritePressed,
      this.onNotificationPressed})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<int>>(
      stream: characteristic.value,
      initialData: characteristic.lastValue,
      builder: (c, snapshot) {
        final value = snapshot.data;
        return ExpansionTile(
          title: ListTile(
            title: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Characteristic'),
                Text(
                    '0x${characteristic.uuid.toString().toUpperCase().substring(4, 8)}',
                    style: Theme.of(context).textTheme.bodyText1?.copyWith(
                        color: Theme.of(context).textTheme.caption?.color))
              ],
            ),
            subtitle: Text(value.toString()),
            contentPadding: const EdgeInsets.all(0.0),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                icon: Icon(
                  Icons.file_download,
                  color: Theme.of(context).iconTheme.color?.withOpacity(0.5),
                ),
                onPressed: onReadPressed,
              ),
              IconButton(
                icon: Icon(Icons.file_upload,
                    color: Theme.of(context).iconTheme.color?.withOpacity(0.5)),
                onPressed: onWritePressed,
              ),
              IconButton(
                icon: Icon(
                    characteristic.isNotifying
                        ? Icons.sync_disabled
                        : Icons.sync,
                    color: Theme.of(context).iconTheme.color?.withOpacity(0.5)),
                onPressed: onNotificationPressed,
              )
            ],
          ),
          children: descriptorTiles,
        );
      },
    );
  }
}

class DescriptorTile extends StatelessWidget {
  final BluetoothDescriptor descriptor;
  final VoidCallback? onReadPressed;
  final VoidCallback? onWritePressed;

  const DescriptorTile(
      {Key? key,
      required this.descriptor,
      this.onReadPressed,
      this.onWritePressed})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Descriptor'),
          Text('0x${descriptor.uuid.toString().toUpperCase().substring(4, 8)}',
              style: Theme.of(context)
                  .textTheme
                  .bodyText1
                  ?.copyWith(color: Theme.of(context).textTheme.caption?.color))
        ],
      ),
      subtitle: StreamBuilder<List<int>>(
        stream: descriptor.value,
        initialData: descriptor.lastValue,
        builder: (c, snapshot) => Text(snapshot.data.toString()),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            icon: Icon(
              Icons.file_download,
              color: Theme.of(context).iconTheme.color?.withOpacity(0.5),
            ),
            onPressed: onReadPressed,
          ),
          IconButton(
            icon: Icon(
              Icons.file_upload,
              color: Theme.of(context).iconTheme.color?.withOpacity(0.5),
            ),
            onPressed: onWritePressed,
          )
        ],
      ),
    );
  }
}

class AdapterStateTile extends StatelessWidget {
  const AdapterStateTile({Key? key, required this.state}) : super(key: key);

  final BluetoothState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.redAccent,
      child: ListTile(
        title: Text(
          'Bluetooth adapter is ${state.toString().substring(15)}',
          style: Theme.of(context).primaryTextTheme.subtitle2,
        ),
        trailing: Icon(
          Icons.error,
          color: Theme.of(context).primaryTextTheme.subtitle2?.color,
        ),
      ),
    );
  }
}
