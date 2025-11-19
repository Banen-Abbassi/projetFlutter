// Path: services/profile_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Attention : Le nom de la classe est "ProfileSercice" pour correspondre à votre code existant.
// La bonne orthographe serait "ProfileService".
class ProfileSercice {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Récupère les données d'un utilisateur depuis Firestore en utilisant son UID.
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      print("Erreur lors de la récupération des données utilisateur : $e");
      return null;
    }
  }

  /// Met à jour les données de l'utilisateur actuellement connecté.
  /// [data] est une map contenant les champs à mettre à jour.
  Future<void> updateUserData(Map<String, dynamic> data) async {
    final String? uid = _auth.currentUser?.uid;

    if (uid == null) {
      print("Aucun utilisateur connecté pour la mise à jour.");
      return;
    }

    try {
      // Utilise .update() pour ne modifier que les champs fournis dans la map [data].
      await _firestore.collection('users').doc(uid).update(data);
    } catch (e) {
      print("Erreur lors de la mise à jour des données utilisateur : $e");
    }
  }
}