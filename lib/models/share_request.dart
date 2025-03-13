class ShareRequest {
  final String id;
  final String roomId;
  final String roomName;
  final String senderUid;
  final String senderEmail;
  final String recipientEmail;
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime timestamp;

  ShareRequest({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.senderUid,
    required this.senderEmail,
    required this.recipientEmail,
    required this.status,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'roomName': roomName,
      'senderUid': senderUid,
      'senderEmail': senderEmail,
      'recipientEmail': recipientEmail,
      'status': status,
      'timestamp': timestamp,
    };
  }
} 