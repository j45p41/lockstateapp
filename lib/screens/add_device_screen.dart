// // import 'dart:io';

// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:lockstate/data/index.dart';
// import 'package:lockstate/model/room.dart';
// import 'package:lockstate/utils/color_utils.dart';
// import 'package:momentum/momentum.dart';

// import '../main.dart';
// // import 'package:qr_code_scanner/qr_code_scanner.dart';

// // class AddDeviceScreen extends StatefulWidget {
// //   @override
// //   _AddDeviceScreenState createState() => _AddDeviceScreenState();
// // }

// // class _AddDeviceScreenState extends State<AddDeviceScreen> {
// //   final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
// //   late Barcode result;
// //   late QRViewController controller;

// //   // In order to get hot reload to work we need to pause the camera if the platform
// //   // is android, or resume the camera if the platform is iOS.
// //   @override
// //   void reassemble() {
// //     super.reassemble();
// //     if (Platform.isAndroid) {
// //       controller.pauseCamera();
// //     } else if (Platform.isIOS) {
// //       controller.resumeCamera();
// //     }
// //   }

// //   void _onQRViewCreated(QRViewController controller) {
// //     this.controller = controller;
// //     controller.scannedDataStream.listen((scanData) {
// //       setState(() {
// //         result = scanData;
// //       });
// //     });
// //   }

// //   @override
// //   void dispose() {
// //     controller.dispose();
// //     super.dispose();
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       body: Column(
// //         children: <Widget>[
// //           Expanded(
// //             flex: 5,
// //             child: QRView(
// //               key: qrKey,
// //               onQRViewCreated: _onQRViewCreated,
// //             ),
// //           ),
// //           Expanded(
// //             flex: 1,
// //             child: Center(
// //               child: (result != null)
// //                   ? Text('Data: ${result.code}')
// //                   : Text('Scan a code'),
// //             ),
// //           )
// //         ],
// //       ),
// //     );
// //   }
// // }

// class AddDeviceScreen extends StatefulWidget {
//   final Room room;
//   AddDeviceScreen(this.room);
//   @override
//   _AddDeviceScreenState createState() => _AddDeviceScreenState();
// }

// class _AddDeviceScreenState extends State<AddDeviceScreen> {
//   final _formKey = GlobalKey<FormState>();
//   String deviceName = '';
//   String deviceId = '';
//   bool isIndoor = false;
// addDevice() {
//   if (_formKey.currentState!.validate()) {
//     _formKey.currentState!.save();
//     final dataController = Momentum.controller<DataController>(context);

//     dataController.addDevice(deviceId, FirebaseAuth.instance.currentUser!.uid,
//         deviceName, isIndoor, widget.room.roomId);
//     Navigator.of(context).pushReplacement(MaterialPageRoute(
//       builder: (context) => Authenticate(),
//     ));
//   }
// }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Theme.of(context).backgroundColor,
//       appBar: AppBar(
//         backgroundColor: Theme.of(context).backgroundColor,
//         title: Text(
//           "Add Device",
//         ),
//         centerTitle: false,
//       ),
//       body: Form(
//         key: _formKey,
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
//           child: Column(
//             children: [
//               SizedBox(
//                 height: 40,
//               ),
//               TextFormField(
//                 style: TextStyle(color: Color(ColorUtils.color4)),
//                 decoration: InputDecoration(
//                   fillColor: Color(ColorUtils.color2),
//                   filled: true,
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   hintText: "Enter Device name",
//                   hintStyle: TextStyle(color: Color(ColorUtils.color4)),
//                 ),
//                 onSaved: (newValue) => deviceName = newValue!,
//               ),
//               SizedBox(
//                 height: 5,
//               ),
//               TextFormField(
//                 style: TextStyle(color: Color(ColorUtils.color4)),
//                 decoration: InputDecoration(
//                   fillColor: Color(ColorUtils.color2),
//                   filled: true,
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   hintText: "Enter Device Id",
//                   hintStyle: TextStyle(color: Color(ColorUtils.color4)),
//                 ),
//                 onSaved: (newValue) => deviceId = newValue!,
//               ),
//               SizedBox(
//                 height: 10,
//               ),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   isIndoor
//                       ? Text(
//                           "Indoor  ",
//                           style: TextStyle(
//                             color: Color(
//                               ColorUtils.color4,
//                             ),
//                           ),
//                         )
//                       : Text(
//                           "Outdoor  ",
//                           style: TextStyle(
//                             color: Color(
//                               ColorUtils.color4,
//                             ),
//                           ),
//                         ),
//                   CupertinoSwitch(
//                       value: isIndoor,
//                       onChanged: (value) {
//                         setState(() {
//                           isIndoor = value;
//                         });
//                       }),
//                 ],
//               ),
//               SizedBox(
//                 height: 40,
//               ),
//               GestureDetector(
//                 onTap: addDevice,
//                 child: Container(
//                   child: Center(
//                     child: Text(
//                       "Add Device",
//                       style: TextStyle(
//                         color: Color(
//                           ColorUtils.color4,
//                         ),
//                       ),
//                     ),
//                   ),
//                   padding: EdgeInsets.all(10),
//                   width: double.infinity,
//                   decoration: BoxDecoration(
//                       color: Color(ColorUtils.color3),
//                       borderRadius: BorderRadius.circular(10)),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// import 'dart:io';

import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockstate/data/index.dart';
import 'package:lockstate/model/room.dart';
import 'package:momentum/momentum.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

import '../main.dart';
// import 'package:qr_code_scanner/qr_code_scanner.dart';

class AddDeviceScreen extends StatefulWidget {
  final Room room;
  const AddDeviceScreen(this.room, {Key? key}) : super(key: key);
  @override
  _AddDeviceScreenState createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  Barcode? result;
  QRViewController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller!.pauseCamera();
    }
    controller!.resumeCamera();
  }

  addDevice(String deviceId) {
    final dataController = Momentum.controller<DataController>(context);

    dataController.addDevice(deviceId, FirebaseAuth.instance.currentUser!.uid,
        "deviceName", true, widget.room.roomId);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (context) => const Authenticate(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          Expanded(flex: 4, child: _buildQrView(context)),
          Expanded(
            flex: 1,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  if (result != null)
                    Text(
                        'Barcode Type: ${(result!.format)}   Data: ${result!.code}')
                  else
                    const Text('Scan a code'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        margin: const EdgeInsets.all(8),
                        child: ElevatedButton(
                            onPressed: () async {
                              await controller?.toggleFlash();
                              setState(() {});
                            },
                            child: FutureBuilder(
                              future: controller?.getFlashStatus(),
                              builder: (context, snapshot) {
                                return Text('Flash: ${snapshot.data}');
                              },
                            )),
                      ),
                      Container(
                        margin: const EdgeInsets.all(8),
                        child: ElevatedButton(
                            onPressed: () async {
                              await controller?.flipCamera();
                              setState(() {});
                            },
                            child: FutureBuilder(
                              future: controller?.getCameraInfo(),
                              builder: (context, snapshot) {
                                if (snapshot.data != null) {
                                  return Text(
                                      'Camera facing ${(snapshot.data!)}');
                                } else {
                                  return const Text('loading');
                                }
                              },
                            )),
                      )
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        margin: const EdgeInsets.all(8),
                        child: ElevatedButton(
                          onPressed: () async {
                            await controller?.pauseCamera();
                          },
                          child: const Text('pause', style: TextStyle(fontSize: 20)),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(8),
                        child: ElevatedButton(
                          onPressed: () async {
                            await controller?.resumeCamera();
                          },
                          child: const Text('resume', style: TextStyle(fontSize: 20)),
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQrView(BuildContext context) {
    // For this example we check how width or tall the device is and change the scanArea and overlay accordingly.
    var scanArea = (MediaQuery.of(context).size.width < 400 ||
            MediaQuery.of(context).size.height < 400)
        ? 150.0
        : 300.0;
    // To ensure the Scanner view is properly sizes after rotation
    // we need to listen for Flutter SizeChanged notification and update controller
    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
          borderColor: Colors.red,
          borderRadius: 10,
          borderLength: 30,
          borderWidth: 10,
          cutOutSize: scanArea),
      onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });
    controller.scannedDataStream.listen((scanData) {
      setState(() {
        result = scanData;
      });
      addDevice(result!.code.toString());
    });
  }

  void _onPermissionSet(BuildContext context, QRViewController ctrl, bool p) {
    print('${DateTime.now().toIso8601String()}_onPermissionSet $p');
    if (!p) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('no Permission')),
      );
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
