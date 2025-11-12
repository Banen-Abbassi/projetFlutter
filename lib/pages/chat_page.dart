import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Media & attachment imports (add your packages later)
import 'package:image_picker/image_picker.dart';
import '../services/message_service.dart';
import 'visit_profile_page.dart'; 
class ChatPage extends StatefulWidget {
  final String chatId;
  final String receiverId;
  final String receiverName;
  final String? receiverImageUrl;

  const ChatPage({
    super.key,
    required this.chatId,
    required this.receiverId,
    required this.receiverName,
    this.receiverImageUrl,
  });

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final MessageService _messageService = MessageService();
  final TextEditingController _controller = TextEditingController();

 void _navigateToUserProfile() {
    // Reconstruct the user map required by VisitProfilePage.
    // Note: You may not have all user data here (like email).
    // Pass what you have. If VisitProfilePage needs more, you might need to
    // fetch it first or pass more data to ChatPage initially.
    final user = {
      'uid': widget.receiverId,
      'name': widget.receiverName,
      'imageUrl': widget.receiverImageUrl ?? '',
      // Add other fields with default values if VisitProfilePage requires them
      'email': '', // Assuming email is not available on this screen
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisitProfilePage(user: user),
      ),
    );
  } 
  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _messageService.sendMessage(widget.chatId, widget.receiverId, text);
    _controller.clear();
  }

  void _startVoiceCall() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Voice call feature coming soon!")),
    );
  }

  void _startVideoCall() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Video call feature coming soon!")),
    );
  }

  void _pickAttachment() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Attachment feature coming soon!")),
    );
  }

  void _pickImage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Image picker coming soon!")),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "";
    final date = timestamp.toDate();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
  title: GestureDetector(
          onTap: _navigateToUserProfile, // Call the navigation function on tap
          // Use a transparent behavior to make the whole row area tappable
          behavior: HitTestBehavior.translucent,
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[300],
              backgroundImage: widget.receiverImageUrl != null &&
                      widget.receiverImageUrl!.isNotEmpty
                  ? NetworkImage(widget.receiverImageUrl!)
                  : null,
              child: widget.receiverImageUrl == null ||
                      widget.receiverImageUrl!.isEmpty
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.receiverName,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: _startVoiceCall,
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: _startVideoCall,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messageService.getMessagesStream(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;
                final currentUserId = FirebaseAuth.instance.currentUser?.uid;

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['senderId'] == currentUserId;
                    final timestamp = msg['timestamp'] as Timestamp?;

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: IntrinsicWidth(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.85)
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  msg['text'],
                                  style: TextStyle(
                                      color: isMe ? Colors.white : Colors.black),
                                ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    _formatTimestamp(timestamp),
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white70
                                          : Colors.black54,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file, color: Colors.grey),
                  onPressed: _pickAttachment,
                ),
                IconButton(
                  icon: const Icon(Icons.photo_camera, color: Colors.grey),
                  onPressed: _pickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send,
                      color: Theme.of(context).colorScheme.primary),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
