// import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockstate/data/index.dart';
import 'package:lockstate/model/room.dart';
import 'package:momentum/momentum.dart';

import '../main.dart';
// import 'package:qr_code_scanner/qr_code_scanner.dart';

// class AddDeviceScreen extends StatefulWidget {
//   @override
//   _AddDeviceScreenState createState() => _AddDeviceScreenState();
// }

// class _AddDeviceScreenState extends State<AddDeviceScreen> {
//   final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
//   late Barcode result;
//   late QRViewController controller;

//   // In order to get hot reload to work we need to pause the camera if the platform
//   // is android, or resume the camera if the platform is iOS.
//   @override
//   void reassemble() {
//     super.reassemble();
//     if (Platform.isAndroid) {
//       controller.pauseCamera();
//     } else if (Platform.isIOS) {
//       controller.resumeCamera();
//     }
//   }

//   void _onQRViewCreated(QRViewController controller) {
//     this.controller = controller;
//     controller.scannedDataStream.listen((scanData) {
//       setState(() {
//         result = scanData;
//       });
//     });
//   }

//   @override
//   void dispose() {
//     controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Column(
//         children: <Widget>[
//           Expanded(
//             flex: 5,
//             child: QRView(
//               key: qrKey,
//               onQRViewCreated: _onQRViewCreated,
//             ),
//           ),
//           Expanded(
//             flex: 1,
//             child: Center(
//               child: (result != null)
//                   ? Text('Data: ${result.code}')
//                   : Text('Scan a code'),
//             ),
//           )
//         ],
//       ),
//     );
//   }
// }

class AddDeviceScreen extends StatefulWidget {
  final Room room;
  AddDeviceScreen(this.room);
  @override
  _AddDeviceScreenState createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _formKey = GlobalKey<FormState>();
  String deviceName = '';
  String deviceId = '';
  bool isIndoor = false;
  addDevice() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final dataController = Momentum.controller<DataController>(context);

      dataController.addDevice(deviceId, FirebaseAuth.instance.currentUser!.uid,
          deviceName, isIndoor,widget.room.roomId);
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (context) => Authenticate(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Add Device",
        ),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  hintText: "Device name",
                ),
                onSaved: (newValue) => deviceName = newValue!,
              ),
              TextFormField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  hintText: "Device Id",
                ),
                onSaved: (newValue) => deviceId = newValue!,
              ),
              CupertinoSwitch(
                  value: isIndoor,
                  onChanged: (value) {
                    setState(() {
                      isIndoor = value;
                    });
                  }),
              ElevatedButton(
                onPressed: addDevice,
                child: Text("Add Device"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
