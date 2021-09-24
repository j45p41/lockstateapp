import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockstate/model/history.dart';
import 'package:lockstate/utils/color_utils.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    print("user id " + FirebaseAuth.instance.currentUser!.uid.toString());
    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: AppBar(
        title: Text("Notifications"),
        backgroundColor: Theme.of(context).backgroundColor,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('notifications')
              .where(
                "userId",
                isEqualTo: FirebaseAuth.instance.currentUser!.uid,
              )
              .snapshots(),
          builder: (context, snapshot) {
            print("snapshot " + snapshot.toString());
            if (snapshot.data == null || snapshot.data!.docs.length == 0) {
              return Center(
                child: Text(
                  "No notifications",
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
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

            // print(latestDocData.toString());
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
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
            );
          }),
    );
  }
}
