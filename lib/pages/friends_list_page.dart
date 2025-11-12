// friends_list_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'visit_profile_page.dart';

class FriendsListPage extends StatelessWidget {
  final List<dynamic> friends; // could be a list of uids or maps
  const FriendsListPage({super.key, required this.friends});

  Future<Map<String, dynamic>> _fetchFriendProfile(dynamic friend) async {
    final uid = friend is Map ? friend['uid'] : friend.toString();
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.data() ?? {
      'uid': uid,
      'name': 'Unknown',
      'email': '',
      'imageUrl': '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text("Friends (${friends.length})"),
        centerTitle: true,
      ),
      body: friends.isEmpty
          ? const Center(
              child: Text("You haven't added any friends yet."),
            )
          : ListView.builder(
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final friend = friends[index];

                // Extract name/email/imageUrl if available, else show placeholders
                String displayName = 'Loading...';
                String displayEmail = '';
                String imageUrl = '';

                if (friend is Map) {
                  displayName = friend['name'] ?? 'No Name';
                  displayEmail = friend['email'] ?? '';
                  imageUrl = friend['imageUrl'] ?? '';
                }

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                    child: imageUrl.isEmpty ? const Icon(Icons.person) : null,
                  ),
                  title: Text(displayName),
                  subtitle: displayEmail.isNotEmpty ? Text(displayEmail) : null,
                  onTap: () async {
                    // Fetch full profile from Firestore
                    final profileData = await _fetchFriendProfile(friend);

                    // Navigate to VisitProfilePage
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VisitProfilePage(user: profileData),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
