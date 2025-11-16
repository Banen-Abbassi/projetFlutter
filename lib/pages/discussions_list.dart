import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/friend_service.dart';
import '../services/message_service.dart';
import 'chat_page.dart';
import 'loading_page.dart';

class DiscussionsList extends StatefulWidget {
  const DiscussionsList({super.key});

  @override
  State<DiscussionsList> createState() => _DiscussionsListState();
}

// Use AutomaticKeepAliveClientMixin to prevent the widget state from being disposed
class _DiscussionsListState extends State<DiscussionsList>
    with AutomaticKeepAliveClientMixin<DiscussionsList> {
  final MessageService _messageService = MessageService();
  final FriendService _friendService = FriendService();

  // This is crucial. It tells Flutter to keep this widget's state alive.
  @override
  bool get wantKeepAlive => true;

  // Navigation logic can be kept here or moved to a utility class
  void _navigateToWithLoadingIndicator(BuildContext context, Widget page) async {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoadingPage()),
    );
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  void _navigateToChat(String chatId, String receiverId, String receiverName,
      {String? receiverImageUrl}) {
    _navigateToWithLoadingIndicator(
      context,
      ChatPage(
        chatId: chatId,
        receiverId: receiverId,
        receiverName: receiverName,
        receiverImageUrl: receiverImageUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Important: Call super.build(context) when using the mixin.
    super.build(context);

    return StreamBuilder<QuerySnapshot>(
      stream: _messageService.getUserChats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        final chatDocs = snapshot.data?.docs ?? [];
        if (chatDocs.isEmpty) {
          return const Center(
              child: Text("Start a discussion by searching for a friend!"));
        }
        return ListView.builder(
          itemCount: chatDocs.length,
          itemBuilder: (context, i) {
            final chat = chatDocs[i].data() as Map<String, dynamic>;
            final chatId = chatDocs[i].id;
            final currentUserId = _messageService.getCurrentUserId();

            // --- START: ROBUST RECEIVER ID EXTRACTION ---
            final participants = List<String>.from(chat['participants'] ?? []);
            String? receiverId;

            try {
            
              receiverId = participants.firstWhere(
                (id) => id != currentUserId && id.isNotEmpty,
              );
            } catch (e) {
              receiverId = null;
            }

            if (receiverId == null) {
  return const SizedBox.shrink();
}

            // Because of the check above, we can now safely use receiverId.
            return FutureBuilder<DocumentSnapshot>(
              // We use receiverId! to tell Dart we are certain it's not null here.
              future: _friendService.getUserDetails(receiverId),
              builder: (context, userSnapshot) {
                String name = "Loading...";
                String? imageUrl;
                if (userSnapshot.connectionState == ConnectionState.done &&
                    userSnapshot.hasData &&
                    userSnapshot.data!.exists) {
                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>;
                  name = userData['name'] ?? 'Unknown User';
                  imageUrl = userData['imageUrl'];
                } else if (userSnapshot.connectionState == ConnectionState.done) {
                  name = 'User Not Found';
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: _messageService.getLastMessage(chatId),
                  builder: (context, messageSnapshot) {
                    String subtitle = "No messages yet";
                    if (messageSnapshot.hasData &&
                        messageSnapshot.data!.docs.isNotEmpty) {
                      final lastMessage = messageSnapshot.data!.docs.first
                          .data() as Map<String, dynamic>;
                      final String messageContent =
                          lastMessage["text"] ?? "Message unavailable";
                      final String? senderId =
                          lastMessage["senderId"] as String?;
                      subtitle = (senderId != null && senderId == currentUserId)
                          ? "You: $messageContent"
                          : messageContent;
                    }
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.purple.shade700,
                        backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                            ? NetworkImage(imageUrl)
                            : null,
                        child: (imageUrl == null || imageUrl.isEmpty)
                            ? const Icon(Icons.person,
                                size: 25, color: Colors.white)
                            : null,
                      ),
                      title: Text(name),
                      subtitle: Text(subtitle,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        _navigateToChat(chatId, receiverId!, name,
                            receiverImageUrl: imageUrl);
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}