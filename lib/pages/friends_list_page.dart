import 'dart:convert'; // <-- CHANGEMENT : Import pour le décodage
import 'dart:typed_data'; // <-- CHANGEMENT : Import pour les données de l'image
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'visit_profile_page.dart';

class FriendsListPage extends StatelessWidget {
  final List<dynamic> friends;
  const FriendsListPage({super.key, required this.friends});

  // <-- CHANGEMENT : Ajout de la fonction d'aide pour décoder l'image
  ImageProvider? _getImageProvider(String base64String) {
    if (base64String.isEmpty) return null;
    try {
      final Uint8List imageBytes = base64Decode(base64String);
      return MemoryImage(imageBytes);
    } catch (e) {
      print("Erreur de décodage dans FriendsListPage : $e");
      return null;
    }
  }

  Future<Map<String, dynamic>> _fetchFriendProfile(String uid) async {
    if (uid.isEmpty) {
      return {'name': 'Invalid ID', 'uid': ''};
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        data['uid'] = doc.id;
        return data;
      } else {
        return {'name': 'User Not Found', 'uid': uid};
      }
    } catch (e) {
      print("Error fetching friend profile for UID: $uid. Error: $e");
      return {'name': 'Error loading', 'uid': uid};
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text("Friends (${friends.length})"),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: friends.isEmpty
          ? const Center(child: Text("You haven't added any friends yet."))
          : ListView.builder(
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final String friendUid = friends[index].toString();

                return FutureBuilder<Map<String, dynamic>>(
                  future: _fetchFriendProfile(friendUid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.purple,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0),
                        ),
                        title: Text("Loading..."),
                      );
                    }

                    if (snapshot.hasError || !snapshot.hasData || snapshot.data == null || snapshot.data!['uid'] == '') {
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.red,
                          child: Icon(Icons.error_outline, color: Colors.white),
                        ),
                        title: Text(snapshot.data?['name'] ?? "Error"),
                        subtitle: const Text("Could not load user."),
                      );
                    }

                    final friendData = snapshot.data!;
                    final String displayName = friendData['name'] ?? 'No Name';
                    final String displayEmail = friendData['email'] ?? '';
                    // <-- CHANGEMENT : On lit le champ 'imageUrlBase64'
                    final String imageBase64 = friendData['imageUrlBase64'] ?? '';

                    // <-- CHANGEMENT : On prépare l'image en appelant notre fonction
                    final imageProvider = _getImageProvider(imageBase64);

                    return ListTile(
                      // <-- CHANGEMENT : Le CircleAvatar utilise maintenant l'imageProvider
                      leading: CircleAvatar(
                        backgroundImage: imageProvider,
                        backgroundColor: Colors.purple.shade100,
                        child: imageProvider == null ? const Icon(Icons.person, color: Colors.purple) : null,
                      ),
                      title: Text(displayName),
                      subtitle: displayEmail.isNotEmpty ? Text(displayEmail) : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VisitProfilePage(user: friendData),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}