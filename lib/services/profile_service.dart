import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileSercice {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final users = FirebaseFirestore.instance.collection("users");
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

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

  Future updateUserData(Map<String, dynamic> newData) async {
    try {
      await users.doc(uid).update(newData);
    } catch (e) {
      throw Exception("Failed to update user data: $e");
    }
  }
}
