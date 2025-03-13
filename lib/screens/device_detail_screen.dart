import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lockstate/model/device.dart';
import 'package:lockstate/model/history.dart';
import 'package:lockstate/utils/color_utils.dart';

class DeviceDetailScreen extends StatefulWidget {
  final Device device;
  const DeviceDetailScreen({Key? key, required this.device}) : super(key: key);
  @override
  _DeviceDetailScreenState createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  bool isOn = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('devices')
            .doc(widget.device.deviceId)
            .collection('history')
            .snapshots(),
        builder: (context, snapshot) {
          print("snapshot $snapshot");
          if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
            return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              appBar: AppBar(
                elevation: 0,
                centerTitle: false,
                title: Text(
                  widget.device.deviceName,
                  style: const TextStyle(
                    fontSize: 20,
                    // fontWeight: FontWeight.w700,
                  ),
                ),
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              ),
              body: const Center(
                child: Text(
                  "No history",
                  style: TextStyle(color: Color(ColorUtils.color4)),
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          var length = snapshot.data!.docs.length;
          var data = snapshot.data!.docs;
          // print("data " + data[length - 1].data().toString());
          var latestDocData =
              historyFromJson(json.encode(data[length - 1].data()));

          print("latestDocData.toString()");
          print(latestDocData.toString());

          // print(latestDocData.toString());
          return Scaffold(
            appBar: AppBar(
              elevation: 0,
              centerTitle: false,
              title: Text(
                widget.device.deviceName,
                style: const TextStyle(
                  fontSize: 20,
                  // fontWeight: FontWeight.w700,
                ),
              ),
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              leading: GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                },
                child: const Icon(
                  Icons.arrow_back_ios,
                ),
              ),
            ),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                Icons.sensors,
                                size: 300,
                                color: isOn
                                    ? Colors.white
                                    : const Color(
                                        ColorUtils.color3,
                                      ),
                              ),
                              Positioned(
                                left: -40,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Icon(
                                      Icons.battery_full,
                                      size: 20,
                                    ),
                                    Text(
                                      "${latestDocData.message.uplinkMessage.decodedPayload.batVolts.toString()}%",
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(
                            thickness: 1,
                            color: Color(
                              ColorUtils.color3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // flex: 3,
                  ),
                  const Text(
                    "History",
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                      fontSize: 30,
                    ),
                  ),
                  Expanded(
                      child: ListView.builder(
                    itemCount: length,
                    itemBuilder: (context, index) {
                      print("index $index");
                      var historyItem =
                          historyFromJson(json.encode(data[index].data()));

                      return ListTile(
                        title: Text(
                          "Event Type : ${historyItem.message.uplinkMessage.decodedPayload.lockState.toString() == "1" ? "Open" : "Close"}",
                          style: const TextStyle(color: Colors.white70),
                        ),
                        subtitle: Text(
                          DateTime.parse(
                                  historyItem.message.receivedAt.toString())
                              .toString(),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: Text(
                          "State Count : ${historyItem.message.uplinkMessage.decodedPayload
                                  .lockCount}",
                          style: const TextStyle(color: Colors.white70),
                        ),
                      );
                    },
                  )),
                ],
              ),
            ),
          );
        });
  }
}
