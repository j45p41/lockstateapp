import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lockstate/utils/globals_jas.dart' as globals;

class ShareRoomPage extends StatefulWidget {
  final String roomId;
  final String roomName;

  const ShareRoomPage({Key? key, required this.roomId, required this.roomName})
      : super(key: key);

  @override
  _ShareRoomPageState createState() => _ShareRoomPageState();
}

class _ShareRoomPageState extends State<ShareRoomPage> {
  final _formKey = GlobalKey<FormState>();
  final _userEmailController = TextEditingController();
  List<String> _sharedEmails = []; // List to store shared emails

  Future<void> sendShareRequest() async {
    try {
      final recipientEmail = _userEmailController.text.trim();

      // Check if email exists in database
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: recipientEmail)
          .get();

      if (userQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This Is Not A Valid Locksure User')),
        );
        return;
      }

      // Check if user already has access
      if (_sharedEmails.contains(recipientEmail)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('This User Already Has Access To This Door')),
        );
        return;
      }

      final currentUser = FirebaseAuth.instance.currentUser!;

      // Create share request
      final request = {
        'roomId': widget.roomId,
        'roomName': widget.roomName + ' DOOR',
        'senderUid': currentUser.uid,
        'senderEmail': currentUser.email!,
        'recipientEmail': recipientEmail,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('shareRequests').add(request);

      // Store the last used email in global variable
      globals.email = recipientEmail;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Share request sent and awaiting confirmation')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No rooms currently shared')),
      );
    }
  }

  Future<void> fetchSharedUsers() async {
    try {
      // Fetch the specific room by ID
      final roomDoc = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .get();

      if (roomDoc.exists) {
        final sharedWith =
            roomDoc.data()?['sharedWith'] as List<dynamic>? ?? [];

        // Fetch email addresses for each shared user
        List<String> sharedEmails = [];
        if (sharedWith.isNotEmpty) {
          final sharedUserDocs = await FirebaseFirestore.instance
              .collection('users')
              .where('uid', whereIn: sharedWith)
              .get();

          sharedEmails = sharedUserDocs.docs
              .map((doc) => doc.data()['email'] as String)
              .toList();
        }

        setState(() {
          _sharedEmails = sharedEmails;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No Rooms Currently Shared')),
      );
    }
  }

  void removeSharedUser(String email) async {
    try {
      // Show confirmation dialog
      bool confirmDelete = await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Confirm Removal'),
                content:
                    Text('Are you sure you want to remove access for $email?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Remove',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (!confirmDelete) return;

      // Get user ID from email
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (userDoc.docs.isEmpty) {
        print('User not found for email: $email'); // Debug print
        throw Exception('User not found');
      }

      final userId = userDoc.docs.first.id;
      print('User ID for $email: $userId'); // Debug print

      // Update the room document
      final roomDocRef =
          FirebaseFirestore.instance.collection('rooms').doc(widget.roomId);
      final roomDoc = await roomDocRef.get();

      if (!roomDoc.exists) {
        print('Room not found for ID: ${widget.roomId}'); // Debug print
        throw Exception('Room not found');
      }

      // Check if the user is actually in the sharedWith list
      final sharedWith = roomDoc.data()?['sharedWith'] as List<dynamic>? ?? [];
      print('Current sharedWith list: $sharedWith'); // Debug print

      if (!sharedWith.contains(userId)) {
        print('User ID $userId not found in sharedWith list'); // Debug print
        throw Exception('User not shared with this room');
      }

      // Remove user from the room's sharedWith list
      await roomDocRef.update({
        'sharedWith': FieldValue.arrayRemove([userId]),
      });

      // Remove room from the user's shared rooms list
      final userDocRef =
          FirebaseFirestore.instance.collection('users').doc(userId);
      await userDocRef.update({
        'sharedRooms': FieldValue.arrayRemove([widget.roomId]),
      });

      // Refresh the list
      setState(() {
        _sharedEmails.remove(email);
      });

      print('Access removed successfully for $email'); // Debug print
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Access removed successfully')),
      );
    } catch (e) {
      print('Error removing access: ${e.toString()}'); // Debug print
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing access: ${e.toString()}')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    print('initState() called');
    fetchSharedUsers(); // Call fetchSharedUsers() here to load shared users initially
    // Autofill from global variable if available
    if (globals.email.isNotEmpty) {
      _userEmailController.text = globals.email;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Share Door')),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Text field for entering recipient email
            Padding(
              padding: const EdgeInsets.all(10),
              child: TextFormField(
                controller: _userEmailController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an email';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'Email Of Person To Share With',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  sendShareRequest();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text('Send Share Request'),
            ),
            // Display shared users as a list of selectable items
            const SizedBox(
              height: 25,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                "This Door Is Already Shared With:",
                style: TextStyle(color: Colors.black, fontSize: 15),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _sharedEmails.length,
                itemBuilder: (context, index) {
                  final sharedEmail = _sharedEmails[index];
                  return ListTile(
                    title: Text(sharedEmail),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => removeSharedUser(sharedEmail),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
