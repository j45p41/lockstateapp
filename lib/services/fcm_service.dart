import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:momentum/momentum.dart';

class FcmService extends MomentumService {
  FirebaseMessaging fcm = FirebaseMessaging.instance;
  Future<void> startFCMService(BuildContext context) async {
    print('CHECKING PERMISSION');
      print('BEFORE RP');

      
    final settings = await fcm.requestPermission();


      print('AFTER RP');
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Success: User authorized notifications');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('Success: User authorized notifications provisionnal');
    } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
      print('Fail: User positively denied notifications');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.notDetermined) {
      print('Fail: User status not determined notifications');
    } else {
      print('Fail: User declined notifications');
      // When it fails, open the settings page.
    }
    // fetch the FCM token for this device
    final fCMToken = await fcm.getToken();
// print the token (normally you would send this to your server)
    print('TOKEN: $fCMToken');

    print("Fcm service started");
    try {
      RemoteMessage? initialMessage = await fcm.getInitialMessage();
      if (initialMessage != null) {}
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print("Notification data ${message.notification!.body}");
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print("Notification data ${message.notification!.title}");
      });
    } catch (e, stack) {
      print('LOGIN STATUS:');
      print("e = $e");
      print("stack = $stack");
    }
  }
}
