import 'package:cloud_firestore/cloud_firestore.dart';

class Account {
  String username;
  String email;
  String uid;
  String fcmId;
  Account({
    required this.email,
    required this.uid,
    required this.username,
    required this.fcmId,
  });
  factory Account.fromDocument(DocumentSnapshot doc) {
    return Account(
      email: doc['email'],
      uid: doc['uid'],
      username: doc['username'],
      fcmId: doc['fcmId'],
    );
  }
}
