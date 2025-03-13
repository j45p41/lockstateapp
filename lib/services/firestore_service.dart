import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:lockstate/main.dart';
import 'package:lockstate/model/account.dart';
import 'package:momentum/momentum.dart';

class FirestoreService extends MomentumService {
  final firestore = FirebaseFirestore.instance;

  createUserInFirestore(String uid, String email, String username) async {
    var isCreated = false;
    await firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'username': username,
      'fcmId': fcmId,
      'connectionType': "NOT_SELECTED",
    }).whenComplete(() {
      print('Created user on firestore');
      isCreated = true;
    });

    return isCreated;
  }

  addRoom(String userId, String roomName) async {
    await firestore.collection('rooms').add({
      'userId': userId,
      'name': roomName,
      'state': 0,

      // 'lockState': '',
      // 'doorState': '',
      // 'applicationId': '',
      // 'dev_eui': '',
    }).then((doc) {
      firestore.collection('rooms').doc(doc.id).update({
        'roomId': doc.id,

        // 'lockState': '',
        // 'doorState': '',
        // 'applicationId': '',
        // 'dev_eui': '',
      });
    });
  }

  //add remaining fields
  addDevice(
    String deviceId,
    String userId,
    String deviceName,
    bool isIndoor,
    String roomId,
  ) async {
    await firestore.collection('devices').doc(deviceId).set({
      'deviceId': deviceId,
      'userId': userId,
      'deviceName': deviceName,
      'isIndoor': isIndoor,
      'fcmIds': [fcmId],
      'roomId': roomId,
      // 'lockState': '',
      // 'doorState': '',
      // 'applicationId': '',
      // 'dev_eui': '',
    });
    await firestore
        .collection('users')
        .doc(userId)
        .collection('devices')
        .doc(deviceId)
        .set({
      'deviceId': deviceId,
      'userId': userId,
      'deviceName': deviceName,
      'isIndoor': isIndoor,
      'fcmIds': [fcmId],
      'roomId': roomId,
      // 'lockState': '',
      // 'doorState': '',
      // 'applicationId': '',
      // 'dev_eui': '',
    });
  }

  getCurrentAccount() async {
    // if (AuthService().auth.currentUser != null) {
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .get();
    print("get current user doc : ${doc.data()}");
    Account account = Account.fromDocument(doc);
    print("get current user account : ${account.email}");
    return account;
    // }
    // return null;
  }

  getAccountDevices() async* {}
}
