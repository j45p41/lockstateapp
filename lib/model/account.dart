import 'package:cloud_firestore/cloud_firestore.dart';

class Account {
  String username;
  String email;
  String uid;
  Account({
    required this.email,
    required this.uid,
    required this.username,
  });
  factory Account.fromDocument(DocumentSnapshot doc) {
    return Account(
      email: doc['email'],
      uid: doc['uid'],
      username: doc['username'],
    );
  }
}
