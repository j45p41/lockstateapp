import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockstate/model/device.dart';
import 'package:lockstate/model/history.dart';
import 'package:lockstate/utils/color_utils.dart';

class DeviceDetailScreen extends StatefulWidget {
  final Device device;
  DeviceDetailScreen({required this.device});
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
          var length = snapshot.data!.docs.length;
          var data = snapshot.data!.docs;
          print("data " + data[length - 1].data().toString());
          var latestDocData =
              historyFromJson(json.encode(data[length - 1].data()));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          // print(latestDocData.toString());
          return Scaffold(
            appBar: AppBar(
              elevation: 0,
              title: Text(
                "Bedroom",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
              backgroundColor: Theme.of(context).backgroundColor,
              leading: Icon(
                Icons.arrow_back,
                color: Colors.white70,
              ),
            ),
            backgroundColor: Theme.of(context).backgroundColor,
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
                                Icons.king_bed,
                                size: 300,
                                color: isOn
                                    ? Colors.white
                                    : Color(
                                        ColorUtils.color3,
                                      ),
                              ),
                              Positioned(
                                left: -40,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Icon(
                                      Icons.battery_full,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    Text(
                                      "${latestDocData.message.uplinkMessage.decodedPayload.batVolts.toString()}%",
                                      style: TextStyle(
                                        color: Theme.of(context).accentColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Divider(
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
                  Text(
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
                      print("index " + index.toString());
                      var historyItem =
                          historyFromJson(json.encode(data[index].data()));

                      return ListTile(
                        title: Text(
                          "Event Type : ${historyItem.message.uplinkMessage.decodedPayload.lockState.toString() == "1" ? "Open" : "Close"}",
                          style: TextStyle(color: Colors.white70),
                        ),
                        subtitle: Text(
                          DateTime.parse(historyItem
                                  .message.uplinkMessage.receivedAt
                                  .toString())
                              .toString(),
                          style: TextStyle(color: Colors.white70),
                        ),
                        trailing: Text(
                          "State Count : " +
                              historyItem.message.uplinkMessage.decodedPayload
                                  .lockCount
                                  .toString(),
                          style: TextStyle(color: Colors.white70),
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
