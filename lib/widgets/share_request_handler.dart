import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ShareRequestHandler extends StatelessWidget {
  const ShareRequestHandler({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    print('ShareRequestHandler listening for user: $currentUserId'); // Debug print

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('shareRequests')
          .where('recipientId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        print('ShareRequestHandler snapshot: ${snapshot.hasData}'); // Debug print
        if (snapshot.hasData) {
          print('Documents count: ${snapshot.data!.docs.length}'); // Debug print
        }

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          print('Found pending request!'); // Debug print
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showShareRequestDialog(context, snapshot.data!.docs.first);
          });
        }
        return const SizedBox.shrink();
      },
    );
  }

  Future<void> _showShareRequestDialog(BuildContext context, DocumentSnapshot request) async {
    final data = request.data() as Map<String, dynamic>;
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Share Request'),
          content: Text('${data['senderEmail']} wants to share a room with you.'),
          actions: [
            TextButton(
              child: const Text('Decline'),
              onPressed: () async {
                await request.reference.update({'status': 'rejected'});
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Accept'),
              onPressed: () async {
                await request.reference.update({'status': 'accepted'});
                // Update room's sharedWith array
                await FirebaseFirestore.instance
                    .collection('rooms')
                    .doc(data['roomId'])
                    .update({
                  'sharedWith': FieldValue.arrayUnion([data['recipientId']])
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Share request accepted')),
                );
              },
            ),
          ],
        );
      },
    );
  }
} 