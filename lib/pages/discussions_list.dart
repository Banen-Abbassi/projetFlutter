import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
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

class _DiscussionsListState extends State<DiscussionsList>
    with AutomaticKeepAliveClientMixin<DiscussionsList> {
  final MessageService _messageService = MessageService();
  final FriendService _friendService = FriendService();

  @override
  bool get wantKeepAlive => true;

  // <-- CHANGEMENT : Ajout de la fonction d'aide pour décoder l'image
  ImageProvider? _getImageProvider(String base64String) {
    if (base64String.isEmpty) return null;
    try {
      final Uint8List imageBytes = base64Decode(base64String);
      return MemoryImage(imageBytes);
    } catch (e) {
      print("Erreur de décodage dans DiscussionsList : $e");
      return null;
    }
  }

  void _navigateToWithLoadingIndicator(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoadingPage()),
    );
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      }
    });
  }

  void _navigateToChat(
    String chatId,
    String receiverId,
    String receiverName, {
    String? receiverImageBase64,
  }) {
    // On passe la chaîne Base64
    _navigateToWithLoadingIndicator(
      context,
      ChatPage(
        chatId: chatId,
        receiverId: receiverId,
        receiverName: receiverName,
        receiverImageUrl: receiverImageBase64, // ChatPage attend ce paramètre
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            child: Text("Start a discussion by searching for a friend!"),
          );
        }
        return ListView.builder(
          itemCount: chatDocs.length,
          itemBuilder: (context, i) {
            final chat = chatDocs[i].data() as Map<String, dynamic>;
            final chatId = chatDocs[i].id;
            final currentUserId = _messageService.getCurrentUserId();

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

            return FutureBuilder<DocumentSnapshot>(
              future: _friendService.getUserDetails(receiverId),
              builder: (context, userSnapshot) {
                String name = "Loading...";
                String imageBase64 = "";

                if (userSnapshot.connectionState == ConnectionState.done &&
                    userSnapshot.hasData &&
                    userSnapshot.data!.exists) {
                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>;
                  name = userData['name'] ?? 'Unknown User';
                  imageBase64 = userData['imageUrlBase64'] ?? '';
                } else if (userSnapshot.connectionState ==
                    ConnectionState.done) {
                  name = 'User Not Found';
                }

                final imageProvider = _getImageProvider(imageBase64);

                return StreamBuilder<QuerySnapshot>(
                  stream: _messageService.getLastMessage(chatId),
                  builder: (context, messageSnapshot) {
                    String subtitle = "No messages yet";
                    if (messageSnapshot.hasData &&
                        messageSnapshot.data!.docs.isNotEmpty) {
                      final lastMessage =
                          messageSnapshot.data!.docs.first.data()
                              as Map<String, dynamic>;
                      final String messageContent =
                          lastMessage["text"] ?? "Message unavailable";
                      final String? senderId =
                          lastMessage["senderId"] as String?;
                      subtitle = (senderId != null && senderId == currentUserId)
                          ? "You: $messageContent"
                          : messageContent;
                    }

                    return ListTile(
                      leading: StreamBuilder(
                        stream: FirebaseDatabase.instance
                            .ref('status/$receiverId')
                            .onValue,
                        builder: (context, snapshot) {
                          bool isOnline = false;
                          if (snapshot.hasData &&
                              !snapshot.hasError &&
                              snapshot.data!.snapshot.value != null) {
                            final data =
                                snapshot.data!.snapshot.value
                                    as Map<dynamic, dynamic>;
                            isOnline = data['state'] == 'online';
                          }

                          return Stack(
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundColor: Colors.purple.shade700,
                                backgroundImage: imageProvider,
                                child: imageProvider == null
                                    ? const Icon(
                                        Icons.person,
                                        size: 25,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              if (isOnline)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    height: 15,
                                    width: 15,
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Theme.of(
                                          context,
                                        ).scaffoldBackgroundColor,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      title: Text(name),
                      subtitle: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        _navigateToChat(
                          chatId,
                          receiverId!,
                          name,
                          receiverImageBase64: imageBase64,
                        );
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
