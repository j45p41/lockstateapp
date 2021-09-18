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
    return Scaffold();
  }
}
