import 'dart:io';

import 'package:flutter/material.dart';

import 'package:lockstate/screens/device_paired_screen.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class AddHubScreen extends StatefulWidget {
  @override
  _AddHubScreenState createState() => _AddHubScreenState();
}

class _AddHubScreenState extends State<AddHubScreen> {
  bool isDeviceFound = false;
  bool isLoading = false;
  test() async {
    print("**** TEST FUNCTION ****");
    setState(() {
      isLoading = true;
    });
    var flutterBluePlusInstance = FlutterBluePlus.instance;
    await flutterBluePlusInstance
        .startScan(timeout: Duration(seconds: 3))
        .then((value) {
      setState(() {
        isLoading = false;
      });
    });
    var connectedDevices = await flutterBluePlusInstance.connectedDevices;
    List<ScanResult> scanResults = [];
    await flutterBluePlusInstance.scanResults.listen((scanResultList) {
      scanResults = scanResultList;
    });

    scanResults.forEach((res) {
      print(res);
    });

    print("**** SCAN RESULTS ****");
    print("scanresults: " + scanResults.length.toString());
    print("connectedDevices: " + connectedDevices.length.toString());
    // print(scanResults.length);

    for (var device in connectedDevices) {
      // print("device.toString()");
      // print(device.toString());
      print("10A");
      if (device.name == "locksure") {
        print("11A");
        if (device.state == BluetoothDeviceState.connected) {
          print("12A");
          Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => DevicePairedScreen(device)));
        } else {
          print("14A");
          await device.connect();
          // if (device.state == BluetoothDeviceState.connected) {
          print("13A");
          Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => DevicePairedScreen(device)));
          // }
        }
        break;
      }
    }

    for (var scanResult in scanResults) {
      print("scanResult.device.name.toString()");
      print(scanResult.device.name.toString());
      if (scanResult.device.name == "locksure") {
        await scanResult.device.connect();
        print("1A");
        // if (scanResult.device.state == BluetoothDeviceState.connected) {
        print("1");

        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => DevicePairedScreen(scanResult.device)));
        print("2");
        // }
        break;
      }
    }
    setState(() {
      print("3");
      isDeviceFound = false;
      isLoading = false;
    });
  }

  @override
  void initState() {
    print("5");
    super.initState();
    test();
  }

  @override
  Widget build(BuildContext context) {
    print("4");
    return Scaffold(
        appBar: AppBar(
          title: const Text('Find Devices'),
          actions: [
            ElevatedButton(
              child: const Text('TURN OFF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              onPressed: Platform.isAndroid
                  ? () => FlutterBluePlus.instance.turnOff()
                  : null,
            ),
          ],
        ),
        body: isLoading
            ? Center(
                child: CircularProgressIndicator(),
              )
            : Center(
                child: Text("Minihub not found"),
              ));
  }
}
