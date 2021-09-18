import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

class DevicePairedScreen extends StatefulWidget {
  final BluetoothDevice device;
  DevicePairedScreen(this.device);
  @override
  _DevicePairedScreenState createState() => _DevicePairedScreenState();
}

class _DevicePairedScreenState extends State<DevicePairedScreen> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Column(
          children: [
            Center(
              child: Text("DeviceName " + widget.device.name.toString()),
            ),
            Center(
              child: Text("DeviceId" + widget.device.id.id.toString()),
            ),
          ],
        ),
      ),
    );
  }
}
