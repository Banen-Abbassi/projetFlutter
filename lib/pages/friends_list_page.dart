// friends_list_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'visit_profile_page.dart';

class FriendsListPage extends StatelessWidget {
  final List<dynamic> friends; // This is a list of String UIDs
  const FriendsListPage({super.key, required this.friends});

  // --- STEP 1: A dedicated function to fetch a single friend's profile ---
  // This function will be called by the FutureBuilder for each list item.
  Future<Map<String, dynamic>> _fetchFriendProfile(String uid) async {
    // Safety check for empty UIDs
    if (uid.isEmpty) {
      return {'name': 'Invalid ID', 'uid': ''}; // Return a map indicating an error
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        // The critical step: Manually add the UID to the map so VisitProfilePage works.
        data['uid'] = doc.id;
        return data;
      } else {
        // Handle case where friend UID exists in list but user doc is deleted.
        return {'name': 'User Not Found', 'uid': uid};
      }
    } catch (e) {
      print("Error fetching friend profile for UID: $uid. Error: $e");
      // Return an error map
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
          ? const Center(
              child: Text("You haven't added any friends yet."),
            )
          // --- STEP 2: The ListView.builder now uses a FutureBuilder ---
          : ListView.builder(
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final String friendUid = friends[index].toString();

                // Each item in the list is now a FutureBuilder.
                return FutureBuilder<Map<String, dynamic>>(
                  // It calls our fetch function for each friend's UID.
                  future: _fetchFriendProfile(friendUid),
                  builder: (context, snapshot) {
                    
                    // --- Handle the LOADING state ---
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.purple,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0),
                        ),
                        title: Text("Loading..."),
                      );
                    }

                    // --- Handle the ERROR state ---
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

                    // --- Handle the SUCCESS state ---
                    // Once the data has arrived, we build the final ListTile.
                    final friendData = snapshot.data!;
                    final String displayName = friendData['name'] ?? 'No Name';
                    final String displayEmail = friendData['email'] ?? '';
                    final String imageUrl = friendData['imageUrl'] ?? '';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                        backgroundColor: Colors.purple.shade100,
                        child: imageUrl.isEmpty ? const Icon(Icons.person, color: Colors.purple) : null,
                      ),
                      title: Text(displayName),
                      subtitle: displayEmail.isNotEmpty ? Text(displayEmail) : null,
                      onTap: () {
                        // The onTap is now very simple. All the data is already here.
                        // We just pass the complete 'friendData' map.
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