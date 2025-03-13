import 'package:cloud_firestore/cloud_firestore.dart';

class Room {
  String userId;

  String name;

  String roomId;
  int state;
  List<String> sharedWith;

  Room(
      {required this.roomId,
      required this.name,
      required this.userId,
      required this.state,
      required this.sharedWith});

  factory Room.fromDocument(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return Room(
      roomId: doc.data()['roomId'],
      name: doc.data()["name"].toString(),
      userId: doc.data()["userId"],
      state: doc.data()['state'] ?? 0,
      sharedWith: List<String>.from(doc.data()['sharedWith'] ?? []),
    );
  }
}
