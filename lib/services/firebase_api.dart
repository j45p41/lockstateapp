import 'package:firebase_messaging/firebase_messaging.dart';

class FirebaseApi {
// create an instance of Firebase Messaging
  final _firebaseMessaging = FirebaseMessaging.instance;
// function to initialize notifications

  Future<void> initNotifications() async {
    print('CHECKING PERMISSION');

      final settings = await _firebaseMessaging.requestPermission();

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('Success: User authorized notifications');
  } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
    print('Success: User authorized notifications provisionnal');
  } else {
    print('Fail: User declined notifications');
    // When it fails, open the settings page.
  }




    
    final fCMToken = await _firebaseMessaging.getToken();
    print('TOKEN: $fCMToken');
  }
}
