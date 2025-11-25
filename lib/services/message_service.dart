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
  
  String getCurrentUserId() {
    return _auth.currentUser!.uid;
  }

  Future<QuerySnapshot> getUserChatsOnce() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: uid)
        .get();
  }

  /// Sends a message, creates a notification, and updates the chat's timestamp.
  /// MODIFIED to handle text, images, and files via Base64.
  Future<void> sendMessage(
    String chatId, 
    String receiverId, 
    String text, {
    String? base64Data, 
    String? type, // 'text', 'image', 'file'
    String? fileName,
  }) async {
    final String currentUserId = _auth.currentUser!.uid;
    final Timestamp timestamp = Timestamp.now();

    final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
    final senderName = currentUserDoc.data()?['name'] ?? 'Someone';

    final batch = _firestore.batch();

    // Operation 1: Create the message document
    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();

    // Build the message data
    final Map<String, dynamic> messageData = {
      'text': text,
      'senderId': currentUserId,
      'receiverId': receiverId,
      'timestamp': timestamp,
      'type': type ?? 'text', // Default to 'text' if not provided
    };

    // Add Base64 data if it exists
    if (base64Data != null) {
      messageData['base64Data'] = base64Data;
    }
    if (fileName != null) {
      messageData['fileName'] = fileName;
    }

    batch.set(messageRef, messageData);

    // Operation 2: Update the chat's last message timestamp
    final chatRef = _firestore.collection('chats').doc(chatId);
    batch.update(chatRef, {
      'lastMessageTimestamp': timestamp,
    });
    
    // Operation 3: Create the notification document for the receiver
    if (currentUserId != receiverId) {
      final notificationRef = _firestore
          .collection('users')
          .doc(receiverId)
          .collection('notifications')
          .doc();
      
      // Determine notification body based on message type
      String notificationBody;
      if (type == 'image') {
        notificationBody = 'Sent you an image';
      } else if (type == 'file') {
        notificationBody = 'Sent you a file';
      } else {
        notificationBody = text;
      }

      batch.set(notificationRef, {
        'title': senderName,
        'body': notificationBody,
        'type': 'new_message',
        'senderId': currentUserId,
        'chatId': chatId,
        'read': false,
        'timestamp': timestamp,
      });
    }

    await batch.commit();
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
  
  Stream<QuerySnapshot> getLastMessage(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots();
  }
}