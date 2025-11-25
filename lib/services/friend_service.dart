import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'message_service.dart';

class FriendService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final MessageService messageService = MessageService();

  // --- MODIFIED METHOD: Now creates a notification on send ---
  Future<void> sendRequest(String toUid) async {
    final fromUid = _auth.currentUser!.uid;

    // Get the sender's details to include in the notification message
    final fromUserDoc = await _firestore.collection('users').doc(fromUid).get();
    final fromUserData = fromUserDoc.data();
    final fromUserName = fromUserData?['name'] ?? 'Someone';

    // A batch write ensures both operations succeed or fail together.
    final batch = _firestore.batch();

    // Operation 1: Create the actual friend request
    final requestRef = _firestore.collection('friendRequests').doc();
    batch.set(requestRef, {
      'from': fromUid,
      'to': toUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Operation 2: Create the notification document for the receiver
    final notificationRef = _firestore
        .collection('users')
        .doc(toUid)
        .collection('notifications')
        .doc(); // Firestore will auto-generate a unique ID

    batch.set(notificationRef, {
      'title': 'New Friend Request',
      'body': '$fromUserName sent you a friend request.',
      'type': 'friend_request', // Helps if you add other notification types later
      'senderId': fromUid,
      'read': false, // Every new notification is unread
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Commit both operations
    await batch.commit();
  }
  
  // --- NEW METHOD: Counts unread notifications for the bell icon badge ---
  Stream<int> getUnreadNotificationCountStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(0);

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false) 
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
  Stream<QuerySnapshot> getNewNotificationsStream() {
    final uid = _auth.currentUser!.uid;

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(1) 
        .snapshots();
  }
  Stream<QuerySnapshot> getReceivedRequestsStream() {
    final uid = _auth.currentUser!.uid;
    return _firestore
        .collection('friendRequests')
        .where('to', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(1) // We only care about the latest added request for the pop-up
        .snapshots();
  }


  Future<List<Map<String, dynamic>>> searchUsersCaseInsensitive(String query) async {
    final uid = _auth.currentUser!.uid;
    final lowerQuery = query.toLowerCase();
    final res = await _firestore
        .collection('users')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: query + '\uf8ff')
        .get();
    return res.docs
        .where((doc) => doc.id != uid)
        .map((doc) => {'uid': doc.id, ...doc.data()})
        .where((user) {
          final userName = user['name']?.toLowerCase() ?? '';
          final userEmail = user['email']?.toLowerCase() ?? '';
          return userName.contains(lowerQuery) || userEmail.contains(lowerQuery);
        })
        .toList();
  }

  Stream<int> getIncomingRequestsCountStream() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('requests') 
        .where('status', isEqualTo: 'received')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<DocumentSnapshot> getUserDetails(String userId) {
    return FirebaseFirestore.instance.collection('users').doc(userId).get();
  }

  Future<void> acceptRequest(String requestId, String fromUid) async {
    final currentUid = _auth.currentUser!.uid;
    final batch = _firestore.batch();
    final userRef = _firestore.collection('users').doc(currentUid);
    final friendRef = _firestore.collection('users').doc(fromUid);
    batch.update(userRef, {'friends': FieldValue.arrayUnion([fromUid])});
    batch.update(friendRef, {'friends': FieldValue.arrayUnion([currentUid])});
    final reqRef = _firestore.collection('friendRequests').doc(requestId);
    batch.delete(reqRef);
    await batch.commit();
  }

  Future<void> deleteRequest(String requestId) async {
    await _firestore.collection('friendRequests').doc(requestId).delete();
  }

  Future<Map<String, dynamic>> checkFriendStatusWithId(String otherUid) async {
    final uid = _auth.currentUser!.uid;
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final friends = List<String>.from(userDoc.data()?['friends'] ?? []);
    if (friends.contains(otherUid)) return {"status": "friends", "requestId": null};
    final sent = await _firestore.collection('friendRequests').where('from', isEqualTo: uid).where('to', isEqualTo: otherUid).get();
    if (sent.docs.isNotEmpty) return {"status": "sent", "requestId": sent.docs.first.id};
    final received = await _firestore.collection('friendRequests').where('from', isEqualTo: otherUid).where('to', isEqualTo: uid).get();
    if (received.docs.isNotEmpty) return {"status": "received", "requestId": received.docs.first.id};
    return {"status": "none", "requestId": null};
  }

  Future<List<Map<String, dynamic>>> getReceivedRequests() async {
    final uid = _auth.currentUser!.uid;
    final res = await _firestore.collection('friendRequests').where('to', isEqualTo: uid).get();
    List<Map<String, dynamic>> requests = [];
    for (var doc in res.docs) {
      final data = doc.data();
      final fromUser = await _firestore.collection('users').doc(data['from']).get();
      if(fromUser.exists) {
        requests.add({
          'requestId': doc.id,
          'fromUid': data['from'],
          'name': fromUser['name'],
          'email': fromUser['email'],
          'imageUrl': fromUser['imageUrl'],
        });
      }
    }
    return requests;
  }

  Future<void> unfriend(String friendUid) async {
    final currentUid = _auth.currentUser!.uid;
    final batch = _firestore.batch();
    final userRef = _firestore.collection('users').doc(currentUid);
    final friendRef = _firestore.collection('users').doc(friendUid);
    batch.update(userRef, {'friends': FieldValue.arrayRemove([friendUid])});
    batch.update(friendRef, {'friends': FieldValue.arrayRemove([currentUid])});
    await batch.commit();
  }
}