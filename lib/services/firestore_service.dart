import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase/firebase.dart';
import 'package:lockstate/model/account.dart';
import 'package:lockstate/services/auth_service.dart';
import 'package:momentum/momentum.dart';

class FirestoreService extends MomentumService {
  final firestore = FirebaseFirestore.instance;

  Account get currentAccount => getCurrentAccount();

  createUserInFirestore(String uid, String email, String username) async {
    await firestore.collection('users').doc(uid).set(
        {'uid': uid, 'email': email, 'username': username}).whenComplete(() {
      print('Created user on firestore');
    });
  }

  //add remaining fields
  addDevice(
    String deviceId,
    String userId,
    String deviceName,
    bool isIndoor,
  ) async {
    await firestore.collection('devices').doc(deviceId).set({
      'deviceId': deviceId,
      'userId': userId,
      'deviceName': deviceName,
      'isIndoor': isIndoor,
      'lockState': '',
      'doorState': '',
      'applicationId': '',
      'dev_eui': '',
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
      'lockState': '',
      'doorState': '',
      'applicationId': '',
      'dev_eui': '',
    });
  }

  getCurrentAccount() async {
    if (AuthService().auth.currentUser != null) {
      DocumentSnapshot doc = await firestore.collection('users').doc().get();
      return Account.fromDocument(doc);
    }
  }

  getAccountDevices() async* {}
}
