class ShareRoomScreen extends StatefulWidget {
  final String roomId;
  final String roomName;

  const ShareRoomScreen({
    Key? key,
    required this.roomId,
    required this.roomName,
  }) : super(key: key);

  @override
  State<ShareRoomScreen> createState() => _ShareRoomScreenState();
}

class _ShareRoomScreenState extends State<ShareRoomScreen> {
  final TextEditingController _emailController = TextEditingController();

  Future<void> sendShareRequest() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser!;
      
      // Create share request
      final request = {
        'roomId': widget.roomId,
        'roomName': widget.roomName,
        'senderUid': currentUser.uid,
        'senderEmail': currentUser.email!,
        'recipientEmail': _emailController.text.trim(),
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('shareRequests')
          .add(request);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Share request sent and awaiting confirmation')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No rooms currently shared')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Share Room')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Enter email address',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: sendShareRequest,
              child: const Text('Send Share Request'),
            ),
          ],
        ),
      ),
    );
  }
} 