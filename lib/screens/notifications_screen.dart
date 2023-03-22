import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lockstate/model/history.dart';
import 'package:lockstate/utils/color_utils.dart';
import 'package:lockstate/utils/globals_jas.dart' as globals;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    print("user id " + FirebaseAuth.instance.currentUser!.uid.toString());
    // globals.currentUser = FirebaseAuth.instance.currentUser!.uid.toString();
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 43, 43, 43),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Color.fromARGB(255, 43, 43, 43),
        title: Text(
          'History',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Color(
              ColorUtils.colorWhite,
            ),
          ),
        ),
        actions: [
          Container(
            margin: EdgeInsets.symmetric(
              vertical: 1,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: 20,
            ),
            width: 200,
            height: 100,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(5)),
            child: Image.asset(
              "assets/images/logo.png",
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(
            width: 10,
          )
        ],
        centerTitle: false,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('notifications')
              .orderBy('received_at', descending: true)
              .where(
                "userId",
                isEqualTo: FirebaseAuth.instance.currentUser!.uid,
              )
              // .orderBy("state", descending: false)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.data == null || snapshot.data!.docs.length == 0) {
              return Center(
                child: Text(
                  "No notifications",
                  style: TextStyle(),
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
            // var latestDocData =
            //     historyFromJRson(json.encode(data[length - 1].data()));

            // print(latestDocData.toString());
            return Container(
              margin: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                      child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 15.0),
                    itemCount: length,
                    itemBuilder: (context, index) {
                      print("index " + index.toString());

                      var historyItem =
                          historyFromJson(json.encode(data[index].data()));

                      return Container(
                        // elevation: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey,
                              offset: Offset(4.0, 10.0), //(x,y)
                              blurRadius: 8.0,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        margin: EdgeInsets.only(top: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Color(historyItem.message.uplinkMessage
                                              .decodedPayload.lockState ==
                                          0
                                      ? ColorUtils.colorGrey
                                      : historyItem.message.uplinkMessage
                                                  .decodedPayload.lockState ==
                                              2
                                          ? ColorUtils.colorRed
                                          : historyItem
                                                      .message
                                                      .uplinkMessage
                                                      .decodedPayload
                                                      .lockState ==
                                                  1
                                              ? ColorUtils.colorGreen
                                              : historyItem
                                                          .message
                                                          .uplinkMessage
                                                          .decodedPayload
                                                          .lockState ==
                                                      3
                                                  ? ColorUtils.colorRed
                                                  : ColorUtils.colorRed),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(6),
                                    bottomLeft: Radius.circular(6),
                                  ),
                                  // boxShadow: [
                                  //   BoxShadow(
                                  //     color: Colors.grey,
                                  //     offset: Offset(4.0, 10.0), //(x,y)
                                  //     blurRadius: 6.0,
                                  //   ),
                                  // ],
                                ),
                                height: 60,
                                child: Center(
                                  child: Text(
                                    historyItem.message.uplinkMessage
                                                .decodedPayload.lockState ==
                                            0
                                        ? "Not Set"
                                        : historyItem.message.uplinkMessage
                                                    .decodedPayload.lockState ==
                                                2
                                            ? "Unlocked"
                                            : historyItem
                                                        .message
                                                        .uplinkMessage
                                                        .decodedPayload
                                                        .lockState ==
                                                    1
                                                ? "Locked"
                                                : historyItem
                                                            .message
                                                            .uplinkMessage
                                                            .decodedPayload
                                                            .lockState ==
                                                        3
                                                    ? "Opened"
                                                    : "Closed",
                                    style: TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              flex: 3,
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    historyItem.deviceName,
                                    textAlign: TextAlign.start,
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    historyItem.message.receivedAt.toString(),
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                              flex: 8,
                            )
                          ],
                        ),
                        // child: ListTile(
                        //   contentPadding:
                        //       EdgeInsets.only(left: 0, top: 0, bottom: 0),
                        //   minLeadingWidth: 0,
                        //   leading: Container(
                        //     width: 100,
                        //     color: Color(historyItem.message.uplinkMessage
                        //                 .decodedPayload.lockState ==
                        //             0
                        //         ? ColorUtils.colorGrey
                        //         : historyItem.message.uplinkMessage
                        //                     .decodedPayload.lockState ==
                        //                 1
                        //             ? ColorUtils.colorRed
                        //             : historyItem.message.uplinkMessage
                        //                         .decodedPayload.lockState ==
                        //                     2
                        //                 ? ColorUtils.colorGreen
                        //                 : historyItem.message.uplinkMessage
                        //                             .decodedPayload.lockState ==
                        //                         3
                        //                     ? ColorUtils.colorRed
                        //                     : ColorUtils.colorRed),
                        //     child: Center(
                        //       child: Text(
                        //         historyItem.message.uplinkMessage.decodedPayload
                        //                     .lockState ==
                        //                 0
                        //             ? "Not Set"
                        //             : historyItem.message.uplinkMessage
                        //                         .decodedPayload.lockState ==
                        //                     1
                        //                 ? "Unlocked"
                        //                 : historyItem.message.uplinkMessage
                        //                             .decodedPayload.lockState ==
                        //                         2
                        //                     ? "Locked"
                        //                     : historyItem
                        //                                 .message
                        //                                 .uplinkMessage
                        //                                 .decodedPayload
                        //                                 .lockState ==
                        //                             3
                        //                         ? "Opened"
                        //                         : "Closed",
                        //         style: TextStyle(
                        //           color: Colors.white,
                        //         ),
                        //       ),
                        //     ),
                        //   ),
                        // title: Text(
                        //   historyItem.deviceName,
                        //   style: TextStyle(
                        //       color: Colors.black,
                        //       fontWeight: FontWeight.bold),
                        // ),
                        // subtitle: Text(
                        //   DateTime.parse(
                        //           historyItem.message.receivedAt.toString())
                        //       .toString(),
                        //   style: TextStyle(color: Colors.black),
                        // ),
                        // ),
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
