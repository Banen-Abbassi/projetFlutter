import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'message_service.dart';

class FriendService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final MessageService messageService = MessageService();

  // 🔍 Search users by name
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final uid = _auth.currentUser!.uid;
    final res = await _firestore
        .collection('users')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: query + '\uf8ff')
        .get();

    // Exclude yourself
    return res.docs
        .where((doc) => doc.id != uid)
        .map((doc) => {'uid': doc.id, ...doc.data()})
        .toList();
  }
  // 🔍 Search users by name (now used for live search)
Future<List<Map<String, dynamic>>> searchUsersCaseInsensitive(String query) async {
  final uid = _auth.currentUser!.uid;
  // Convert query to lowercase for approximate case-insensitive client-side filtering
  final lowerQuery = query.toLowerCase();

  // Firestore basic search (will still be case-sensitive for the start of the query)
  final res = await _firestore
      .collection('users')
      .where('name', isGreaterThanOrEqualTo: query)
      .where('name', isLessThanOrEqualTo: query + '\uf8ff')
      .get();
  
  // Client-side filtering to handle case-insensitivity and sub-string matching
  return res.docs
      .where((doc) => doc.id != uid)
      .map((doc) => {'uid': doc.id, ...doc.data()})
      .where((user) {
        final userName = user['name']?.toLowerCase() ?? '';
        final userEmail = user['email']?.toLowerCase() ?? '';
        final userPhone = user['phone']?.toLowerCase() ?? ''; // Include phone/email
        
        return userName.contains(lowerQuery) || 
               userEmail.contains(lowerQuery) || 
               userPhone.contains(lowerQuery);
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

// Needed by _buildDiscussionsList to fetch receiver name
Future<DocumentSnapshot> getUserDetails(String userId) {
    return FirebaseFirestore.instance.collection('users').doc(userId).get();
}

  // ➕ Send a friend request
  Future<void> sendRequest(String toUid) async {
    final fromUid = _auth.currentUser!.uid;

    await _firestore.collection('friendRequests').add({
      'from': fromUid,
      'to': toUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ✅ Accept request
  Future<void> acceptRequest(String requestId, String fromUid) async {
    final currentUid = _auth.currentUser!.uid;

    final batch = _firestore.batch();

    // Add each other to "friends" arrays
    final userRef = _firestore.collection('users').doc(currentUid);
    final friendRef = _firestore.collection('users').doc(fromUid);

    batch.update(userRef, {
      'friends': FieldValue.arrayUnion([fromUid])
    });
    batch.update(friendRef, {
      'friends': FieldValue.arrayUnion([currentUid])
    });

    // Delete request
    final reqRef = _firestore.collection('friendRequests').doc(requestId);
    batch.delete(reqRef);

    await batch.commit();
  }

  // ❌ Delete / Reject request
  Future<void> deleteRequest(String requestId) async {
    await _firestore.collection('friendRequests').doc(requestId).delete();
  }

  // 🔎 Check relationship status
  Future<String> checkFriendStatus(String otherUid) async {
    final result = await checkFriendStatusWithId(otherUid);
    return result['status'];
  }
  // 🔎 Check relationship status and return request ID if found
// Change the return type to Map
Future<Map<String, dynamic>> checkFriendStatusWithId(String otherUid) async {
  final uid = _auth.currentUser!.uid;

  // Already friends?
  final userDoc = await _firestore.collection('users').doc(uid).get();
  final friends = List<String>.from(userDoc.data()?['friends'] ?? []);
  if (friends.contains(otherUid)) return {"status": "friends", "requestId": null};

  // Pending sent
  final sent = await _firestore
      .collection('friendRequests')
      .where('from', isEqualTo: uid)
      .where('to', isEqualTo: otherUid)
      .get();
  if (sent.docs.isNotEmpty) return {"status": "sent", "requestId": sent.docs.first.id};

  // Pending received
  final received = await _firestore
      .collection('friendRequests')
      .where('from', isEqualTo: otherUid)
      .where('to', isEqualTo: uid)
      .get();
  if (received.docs.isNotEmpty) return {"status": "received", "requestId": received.docs.first.id};

  return {"status": "none", "requestId": null};
}

  // 📬 Get requests received by current user
  Future<List<Map<String, dynamic>>> getReceivedRequests() async {
    final uid = _auth.currentUser!.uid;
    final res = await _firestore
        .collection('friendRequests')
        .where('to', isEqualTo: uid)
        .get();

    // Add sender info
    List<Map<String, dynamic>> requests = [];
    for (var doc in res.docs) {
      final data = doc.data();
      final fromUser = await _firestore.collection('users').doc(data['from']).get();
      requests.add({
        'requestId': doc.id,
        'fromUid': data['from'],
        'name': fromUser['name'],
        'email': fromUser['email'],
        'imageUrl': fromUser['imageUrl'],
      });
    }

    return requests;
  }
  // ➖ Unfriend a user
 Future<void> unfriend(String friendUid) async {
final currentUid = _auth.currentUser!.uid;

 final batch = _firestore.batch();

  // Remove each other from "friends" arrays
  final userRef = _firestore.collection('users').doc(currentUid);
  final friendRef = _firestore.collection('users').doc(friendUid);

 batch.update(userRef, {
'friends': FieldValue.arrayRemove([friendUid])
 });
 batch.update(friendRef, {
 'friends': FieldValue.arrayRemove([currentUid])
 });

 await batch.commit();
 }
}
