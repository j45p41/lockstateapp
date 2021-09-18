import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:momentum/momentum.dart';

class FcmService extends MomentumService {
  FirebaseMessaging fcm = FirebaseMessaging.instance;
  Future<void> startFCMService(BuildContext context) async {
    print("Fcm service started");
    try {
      RemoteMessage? initialMessage = await fcm.getInitialMessage();
      if (initialMessage != null) {}
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print("Notification data " + message.notification!.body.toString());
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print("Notification data " + message.notification!.title.toString());
      });
    } catch (e, stack) {
      print("e = $e");
      print("stack = $stack");
    }
  }
}
