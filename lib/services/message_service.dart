import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get or create a chat between two users
  Future<String> getOrCreateChat(String otherUserId) async {
    final currentUserId = _auth.currentUser!.uid;

    // Try to find an existing chat
    final chatQuery = await _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .get();

    for (var doc in chatQuery.docs) {
      final participants = List<String>.from(doc['participants']);
      if (participants.contains(otherUserId)) {
        return doc.id; // existing chat
      }
    }

    // If not found → create a new one
    final newChat = await _firestore.collection('chats').add({
      'participants': [currentUserId, otherUserId],
      'createdAt': FieldValue.serverTimestamp(),
    });

    return newChat.id;
  }
  // Needed by _buildDiscussionsList
String getCurrentUserId() {
  return _auth.currentUser!.uid;
}

  /// Send a message
  Future<void> sendMessage(String chatId, String receiverId, String text) async {
    final senderId = _auth.currentUser!.uid;

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Stream messages (for real-time updates)
  Stream<QuerySnapshot> getMessagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Get all chats for current user
  Stream<QuerySnapshot> getUserChats() {
    final uid = _auth.currentUser!.uid;
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots();
  }
}
