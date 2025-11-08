// ProfilePage.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/profile_service.dart';
import 'edit_profile_page.dart';
import 'package:provider/provider.dart';
import '../themes/theme_service.dart';
import 'privacy_settings_page.dart';
import '../components/logout_button.dart';
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final profileService = ProfileSercice();
  Map<String, dynamic>? userData;
  // Initialize with a default value to prevent a crash if the document is missing
  // This helps handle the 'User document does not exist!' case gracefully.
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  String _formatTimestamp(Map<String, dynamic>? data, String key) {
    if (data == null) return "";
    final value = data[key];

    if (value == null) return "";

    // Convert Firestore Timestamp to DateTime
    DateTime dateTime;
    if (value is Timestamp) {
      dateTime = value.toDate();
    } else if (value is DateTime) {
      dateTime = value;
    } else {
      return value.toString();
    }

    // Format as "04 Nov 2025"
    return DateFormat('dd MMM yyyy').format(dateTime);
  }

  // Reload user data when coming back from the EditProfilePage
  void _reloadUser() {
    _loadUser();
  }

  void _loadUser() async {
    // Start loading
    if (mounted) setState(() => _isLoading = true);

    final uid = FirebaseAuth.instance.currentUser!.uid;
    // Note: The original 'ProfileSercice' is expected to return null if no doc is found.
    final data = await profileService.getUserData(uid);

    // Graceful handling for missing data: set defaults
    final processedData =
        data ??
        {
          "uid": uid,
          "name": "User Name",
          "email": FirebaseAuth.instance.currentUser!.email ?? "user@email.com",
          "bio": "Set your bio!",
          "phone": "+216 XX XXX XXX",
          "imageUrl": "",
          "friendsCount": "0",
          "createdAt": "N/A",
        };

    if (mounted) {
      setState(() {
        userData = processedData;
        _isLoading = false;
      });
    }
  }

  // Helper to safely get a string from userData
  String safeString(Map<String, dynamic>? data, String key) {
    if (data == null) return "";
    final value = data[key];
    return value != null && value is! Map ? value.toString() : "";
  }

  @override
  Widget build(BuildContext context) {
    // Use the primary color from your provided lightMode for visual consistency
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color tertiaryColor = Theme.of(context).colorScheme.tertiary;

    if (_isLoading || userData == null) {
      // Show loading indicator while fetching data
      return Scaffold(
        appBar: AppBar(title: const Text("My Profile")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Helper function for the stat boxes (Friends/Messages/Date)
    Widget _buildStatBox(String value, String label) {
      return Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
    "My Profile",
    style: TextStyle(color: Colors.white),
  ),
  backgroundColor: primaryColor,
  centerTitle: true,
  iconTheme: const IconThemeData(color: Colors.white),

  actions: const [
    LogoutButton(), // ✅ No Expanded, no padding, just place it here
  ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // --- Profile Header ---
          Center(
            child: Column(
              children: [
                // Profile Avatar
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primaryColor.withOpacity(0.5),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 55,
                    backgroundImage: safeString(userData, "imageUrl").isNotEmpty
                        ? NetworkImage(safeString(userData, "imageUrl"))
                        : null,
                    backgroundColor: primaryColor.withOpacity(0.1),
                    child: safeString(userData, "imageUrl").isEmpty
                        ? Icon(Icons.person, size: 60, color: primaryColor)
                        : null,
                  ),
                ),
                const SizedBox(height: 10),

                // Name and Username
                Text(
                  safeString(userData, "name"),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Status Chip (Bio)
                Chip(
                  label: Text(
                    safeString(userData, "bio").isNotEmpty
                        ? safeString(userData, "bio")
                        : "No status set",
                    style: TextStyle(color: primaryColor),
                  ),
                  backgroundColor: primaryColor.withOpacity(0.1),
                ),
                const SizedBox(height: 15),

                // Edit Profile Button
                ElevatedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditProfilePage(userData!),
                      ),
                    );
                    _reloadUser(); // Reload data after returning from edit page
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: tertiaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 12,
                    ),
                  ),
                  child: const Text("Edit Profile"),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // --- Stats Card (Friends/Messages/Date) ---
          Card(
            elevation: 2,
            color: Colors.white, // Ensure white background
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
              child: IntrinsicHeight(
                child: Row(
                  // Use MainAxisAlignment.spaceEvenly to distribute the two items evenly
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 1. Friends/Contacts Stat
                    _buildStatBox(
                      safeString(userData, "friendsCount"),
                      "Friends",
                    ),

                    // Single Vertical Divider
                    const VerticalDivider(width: 1, color: Colors.grey),

                    // 2. App Join Date Stat
                    _buildStatBox(
                      // Uses the helper to format the Firestore Timestamp
                      _formatTimestamp(userData, "createdAt"),
                      "App Join Date",
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // --- Account Information ---
          Text(
            "Account Information",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 10),

          // Phone Number
          ListTile(
            leading: Icon(Icons.phone, color: primaryColor),
            title: Text(
              safeString(userData, "phone").isNotEmpty
                  ? safeString(userData, "phone")
                  : "No phone provided",
            ),
            trailing: Icon(Icons.edit, color: primaryColor, size: 18),
            onTap: () async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EditProfilePage(userData!),
    ),
  );
  _reloadUser(); // reload data after returning
},
          ),

          // Email
          ListTile(
            leading: Icon(Icons.email, color: primaryColor),
            title: Text(safeString(userData, "email")),
            // trailing: Icon(Icons.edit, color: primaryColor, size: 18),
            onTap: () {
              /* Navigate to edit email field */
            },
          ),

          const SizedBox(height: 20),

          // --- App Settings ---
          Text(
            "App Settings",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 10),

          // Notifications / Light Mode Toggle
          ListTile(
            leading: Icon(Icons.brightness_6, color: primaryColor),
            title: const Text("Dark Mode"),
            trailing: Switch(
              value: context.watch<ThemeService>().isDarkMode,
              onChanged: (value) => context.read<ThemeService>().toggleTheme(value),
              activeColor: primaryColor,
            ),
          ),

          // Privacy Settings
          ListTile(
            leading: Icon(Icons.security, color: primaryColor),
            title: const Text("Privacy Settings"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrivacySettingsPage(),
                ),
              );
            },
          ),

          // Help & Support
          ListTile(
            leading: Icon(Icons.help_outline, color: primaryColor),
            title: const Text("Help & Support"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              /* Navigate to help/support page */
            },
          ),
        ],
      ),
    );
  }
}
