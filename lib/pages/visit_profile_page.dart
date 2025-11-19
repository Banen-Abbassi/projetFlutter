import 'dart:convert'; // <-- CHANGEMENT : Import pour le décodage
import 'dart:typed_data'; // <-- CHANGEMENT : Import pour les données de l'image
import 'package:flutter/material.dart';
import '../services/friend_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:chat_app/pages/chat_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VisitProfilePage extends StatefulWidget {
  final Map<String, dynamic> user;
  const VisitProfilePage({super.key, required this.user});

  @override
  State<VisitProfilePage> createState() => _VisitProfilePageState();
}

class _VisitProfilePageState extends State<VisitProfilePage> {
  final FriendService _friendService = FriendService();
  String _status = "none";
  String? _requestId;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  // <-- CHANGEMENT : Ajout de la fonction d'aide pour décoder l'image
  ImageProvider? _getImageProvider(String base64String) {
    if (base64String.isEmpty) return null;
    try {
      final Uint8List imageBytes = base64Decode(base64String);
      return MemoryImage(imageBytes);
    } catch (e) {
      print("Erreur de décodage dans VisitProfilePage : $e");
      return null;
    }
  }

  void _handleMessage() async {
    // ... (cette fonction ne change pas, mais attention, ChatPage devra aussi être mise à jour)
    final chatId = await _friendService.messageService.getOrCreateChat(
      widget.user['uid'],
    );
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          chatId: chatId,
          receiverId: widget.user['uid'],
          receiverName: widget.user['name'] ?? 'Chat',
          // On passe la chaîne Base64 à la page de chat
          receiverImageUrl: widget.user['imageUrlBase64'],
        ),
      ),
    );
  }

  void _loadStatus() async {
    final result = await _friendService.checkFriendStatusWithId(
      widget.user['uid'],
    );
    if (mounted) {
      setState(() {
        _status = result['status'] as String;
        _requestId = result['requestId'] as String?;
      });
    }
  }

  void _handleSendRequest() async {
    if (_status == 'none') {
      await _friendService.sendRequest(widget.user['uid']);
      _loadStatus();
    }
  }

  void _handleDeleteRequest() async {
    if (_status == 'sent' && _requestId != null) {
      await _friendService.deleteRequest(_requestId!);
      if (mounted) {
        setState(() {
          _status = 'none';
          _requestId = null;
        });
      }
    }
  }

  void _handleUnfriend() async {
    await _friendService.unfriend(widget.user['uid']);
    if (mounted) {
      setState(() => _status = 'none');
      Navigator.of(context).pop();
    }
  }

  void _showUnfriendConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Unfriend"),
        content: Text(
          "Are you sure you want to unfriend ${widget.user['name']}?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: _handleUnfriend,
            child: const Text("Unfriend", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _handleAcceptRequest() async {
    if (_status == 'received' && _requestId != null) {
      await _friendService.acceptRequest(_requestId!, widget.user['uid']);
      if (mounted) {
        setState(() => _status = 'friends');
      }
    }
  }

  Widget _buildActionButtons() {
    Widget friendButton;

    switch (_status) {
      case 'sent':
        friendButton = OutlinedButton(
          onPressed: _handleDeleteRequest,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
          ),
          child: const Text("Cancel Request"),
        );
        break;
      case 'received':
        friendButton = ElevatedButton(
          onPressed: _handleAcceptRequest,
          child: const Text("Accept Request"),
        );
        break;
      case 'friends':
        friendButton = OutlinedButton(
          onPressed: _showUnfriendConfirmationDialog,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.grey),
          ),
          child: const Text("Friends"),
        );
        break;
      default: // 'none'
        friendButton = ElevatedButton(
          onPressed: _handleSendRequest,
          child: const Text("Add Friend"),
        );
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _handleMessage,
            child: const Text("Message"),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: friendButton),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: () {}, child: const Text("More")),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String? text, {bool isEmail = false}) {
    final display = text?.isNotEmpty == true ? text! : 'N/A';
    if (display == 'N/A' && !isEmail) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.purple),
          const SizedBox(width: 15),
          Text(display, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildOnlineStatus() {
    return StreamBuilder(
      stream: FirebaseDatabase.instance
          .ref('status/${widget.user['uid']}')
          .onValue,
      builder: (context, snapshot) {
        bool isOnline = false;
        if (snapshot.hasData &&
            !snapshot.hasError &&
            snapshot.data!.snapshot.value != null) {
          final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          isOnline = data['state'] == 'online';
        }

        return Text(
          isOnline ? 'Online now' : 'Offline',
          style: TextStyle(
            fontSize: 14,
            color: isOnline ? Colors.green : Colors.grey,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final phone = user['phone'] as String? ?? '';
    final email = user['email'] as String? ?? '';
    final joined = user['createdAt'] != null
        ? 'Joined: ${(user['createdAt'] as Timestamp).toDate().toString().substring(0, 10)}'
        : 'Joined: N/A';

    // <-- CHANGEMENT : On prépare l'image en appelant notre nouvelle fonction
    final String imageBase64 = user['imageUrlBase64'] ?? '';
    final imageProvider = _getImageProvider(imageBase64);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Visit Account"),
        centerTitle: true,
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Column(
                  children: [
                    // <-- CHANGEMENT : Le CircleAvatar est modifié pour utiliser l'image décodée
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: imageProvider,
                      backgroundColor: Colors.purple.shade200,
                      child: imageProvider == null
                          ? const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  user['name'] ?? 'User Name',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Center(
                child: Text(
                  '@${user['email'] ?? 'user_handle'}',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ),
              Center(child: _buildOnlineStatus()),
              const SizedBox(height: 20),
              _buildActionButtons(),
              const SizedBox(height: 30),
              _buildInfoTile(Icons.phone, phone),
              _buildInfoTile(Icons.email, email, isEmail: true),
              _buildInfoTile(Icons.calendar_today, joined),
              const SizedBox(height: 30),
              TextButton(
                onPressed: () {},
                child: const Text(
                  "Block User",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  "Report User",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
