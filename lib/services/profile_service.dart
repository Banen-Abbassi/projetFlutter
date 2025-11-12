import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileSercice {
  final _firestore = FirebaseFirestore.instance;

  // This method remains the same. It's used to get a single user's profile.
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(userId).get();

      if (doc.exists && doc.data() != null) {
        return doc.data() as Map<String, dynamic>;
      } else {
        print("User document does not exist!");
        return null;
      }
    } catch (e) {
      print("Failed to fetch user data: $e");
      return null;
    }
  }

  // This method also remains the same.
  Future<void> updateUserData(Map<String, dynamic> newData) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await _firestore.collection('users').doc(uid).update(newData);
    } catch (e) {
      throw Exception("Failed to update user data: $e");
    }
  }

  // ✅ ADD THIS NEW METHOD
  // This method gets all friends for a given user and returns their profile data.
  Future<List<Map<String, dynamic>>> getFriendsList(String userId) async {
    try {
      // 1. Get the snapshot of the 'friends' subcollection for the user.
      QuerySnapshot friendsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('friends')
          .get();

      // If the user has no friends, return an empty list immediately.
      if (friendsSnapshot.docs.isEmpty) {
        return [];
      }

      // 2. Extract the UIDs of the friends from the document IDs.
      List<String> friendUids =
          friendsSnapshot.docs.map((doc) => doc.id).toList();

      List<Map<String, dynamic>> friendsData = [];

      // 3. Loop through each friend's UID to fetch their user data.
      for (String friendUid in friendUids) {
        // We reuse the getUserData method here.
        Map<String, dynamic>? friendData = await getUserData(friendUid);
        if (friendData != null) {
          friendsData.add(friendData);
        }
      }

      return friendsData;
    } catch (e) {
      print("Failed to fetch friends list: $e");
      // Return an empty list if an error occurs.
      return [];
    }
  }
}