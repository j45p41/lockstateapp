import 'dart:async'; // This imports the library containing StreamSubscription

import 'package:flutter/material.dart';

import 'package:lockstate/screens/device_paired_screen.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:lockstate/screens/home_screen.dart';

class AddHubScreen extends StatefulWidget {
  const AddHubScreen({Key? key}) : super(key: key);

  @override
  _AddHubScreenState createState() => _AddHubScreenState();
}

class _AddHubScreenState extends State<AddHubScreen> {
  bool isDeviceFound = false;
  bool isLoading = false;
  List<ScanResult> _scanResults = [];
  int counter = 0;
  StreamSubscription<List<ScanResult>>? scanSubscription;
  test() async {
    print("**** TEST FUNCTION ****");
    setState(() {
      isLoading = true;
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 3));
    bool isPushed = false;
    // Listen for scan results
    scanSubscription =
        FlutterBluePlus.scanResults.listen((scanResultList) async {
      _scanResults = scanResultList;

      for (var scanResult in scanResultList) {
        // print(scanResult);
        if (scanResult.device.platformName == "locksure") {
          try {
            await scanResult.device.connect();

            print("LOCKSURE FOUND");

            counter++;
            // Check if connection was successful before navigating
            // if (scanResult.device.connectionState == BluetoothConnectionState.connected) {

            print("NAVIGATOR PUSH");

            scanSubscription?.cancel(); // Cancel the scan subscription
try{
     if(!isPushed)    {   Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => DevicePairedScreen(scanResult.device)));
            isPushed = true;}
            break;
}

catch (e) {
            print("Error NAVIGATOR PUSH: $e");
          }


            // }
          } catch (e) {
            print("Error connecting to device: $e");
          }
        }
      }
    });
    print("OUT OF LOOP");

    // Check connected devices
    var connectedDevices = FlutterBluePlus.connectedDevices;
    for (var device in connectedDevices) {
      if (device.name == "locksure" &&
          device.state == BluetoothConnectionState.connected) {
        print("LOCKSURE FOUND AND CONNECTED");
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => DevicePairedScreen(device)));
        break;
      }
    }

    setState(() {
      isLoading = false;
      isDeviceFound =
          _scanResults.any((result) => result.device.name == "locksure") ||
              connectedDevices.any((device) => device.name == "locksure");
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
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                const SizedBox(
                  height: 20,
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 50),
                  child: const Center(
                    heightFactor: 5,
                    child: Text(
                      "Check if Hub is in Pairing mode",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 50),
                  child: const Center(
                    heightFactor: 5,
                    child: Text(
                      "and Bluetooth is Switched On",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 50),
                  child: Center(
                    heightFactor: 5,
                    child: ElevatedButton(
                      onPressed: () {
                        print('Retry Pressed');
                        // Navigate back to HomeScreen and then to AddHubScreen
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const HomeScreen()),
                          (route) => false, // Remove all previous routes
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const AddHubScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(73, 255, 7, 7),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 50, vertical: 20),
                          textStyle: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold)),
                      child: const Text("START PAIRING"),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
