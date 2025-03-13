import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:momentum/momentum.dart';

class AuthService extends MomentumService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void init() {}

  @override
  void dispose() {}

  Future<UserCredential> login(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null && userCredential.user != null) {
        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .update({
          'fcmId': [fcmToken],
        });
      }

      return userCredential;
    } catch (e) {
      print('Error in login: $e');
      rethrow;
    }
  }

  Future<UserCredential> signup(
      String email, String password, String username) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String? fcmToken = await FirebaseMessaging.instance.getToken();
      print('FCM Token obtained: $fcmToken');

      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'email': email,
          'username': username,
          'uid': userCredential.user!.uid,
          'connectionType': 'NOT_SELECTED',
          'fcmId': fcmToken != null ? [fcmToken] : [],
        });
      }

      return userCredential;
    } catch (e) {
      print('Error in signup: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error in logout: $e');
      rethrow;
    }
  }

  Future<void> updateFCMToken() async {
    try {
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      print('New FCM Token: $fcmToken');

      if (fcmToken != null && FirebaseAuth.instance.currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .update({
          'fcmId': [fcmToken],
        });
        print('FCM Token updated in Firestore');
      }
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }
}
