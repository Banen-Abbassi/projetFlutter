// Path: pages/profile_page.dart

import 'dart:convert';
import 'dart:typed_data';
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
import 'friends_list_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final profileService = ProfileSercice();
  Map<String, dynamic>? userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  /// Recharge les données de l'utilisateur depuis Firestore.
  void _reloadUser() => _loadUser();

  Future<void> _loadUser() async {
    if (mounted) setState(() => _isLoading = true);

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final data = await profileService.getUserData(uid);

    final List<dynamic> friendsList = List<dynamic>.from(data?['friends'] ?? []);
    // Prépare les données locales avec des valeurs par défaut
    final processedData = (data ?? <String, dynamic>{})
      ..addAll({
        "uid": uid,
        "name": (data?['name'] ?? FirebaseAuth.instance.currentUser?.displayName ?? "User Name"),
        "email": (data?['email'] ?? FirebaseAuth.instance.currentUser?.email ?? ""),
        "bio": (data?['bio'] ?? "Set your bio!"),
        "phone": (data?['phone'] ?? "+216 XX XXX XXX"),
        "imageUrlBase64": (data?['imageUrlBase64'] ?? ""),
        "friends": friendsList,
        "friendsCount": friendsList.length.toString(),
        "createdAt": (data?['createdAt'] ?? Timestamp.now()),
      });

    if (mounted) {
      setState(() {
        userData = processedData;
        _isLoading = false;
      });
    }
  }

  /// Fonction utilitaire pour obtenir une chaîne de caractères de manière sûre.
  String safeString(Map<String, dynamic>? data, String key) {
    if (data == null) return "";
    return data[key]?.toString() ?? "";
  }

  /// Décode la chaîne Base64 et retourne un ImageProvider pour l'affichage.
  ImageProvider? _getImageProvider(String base64String) {
    if (base64String.isEmpty) return null;
    try {
      final Uint8List imageBytes = base64Decode(base64String);
      return MemoryImage(imageBytes);
    } catch (e) {
      print("Erreur de décodage de l'image Base64 : $e");
      return null;
    }
  }

  /// Formate un Timestamp Firestore en une date lisible.
  String _formatTimestamp(Map<String, dynamic>? data, String key) {
    if (data == null) return "";
    final value = data[key];
    if (value == null) return "";
    DateTime dt;
    if (value is Timestamp) {
      dt = value.toDate();
    } else if (value is DateTime) {
      dt = value;
    } else {
      return value.toString();
    }
    return DateFormat('dd MMM yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color tertiaryColor = Theme.of(context).colorScheme.tertiary;

    if (_isLoading || userData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("My Profile")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final imageProvider = _getImageProvider(safeString(userData, "imageUrlBase64"));

    Widget statBox(String value, String label) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black)),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile", style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: const [LogoutButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryColor.withOpacity(0.5), width: 3),
                    boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.2), blurRadius: 10, spreadRadius: 2)],
                  ),
                  child: CircleAvatar(
                    radius: 55,
                    backgroundImage: imageProvider,
                    backgroundColor: primaryColor.withOpacity(0.1),
                    child: imageProvider == null
                        ? Icon(Icons.person, size: 60, color: primaryColor)
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                Text(safeString(userData, "name"), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Chip(
                  label: Text(
                    safeString(userData, "bio").isNotEmpty ? safeString(userData, "bio") : "No status set",
                    style: TextStyle(color: primaryColor),
                  ),
                  backgroundColor: primaryColor.withOpacity(0.1),
                ),
                const SizedBox(height: 15),
                ElevatedButton(
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfilePage(userData!)));
                    _reloadUser();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: tertiaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  ),
                  child: const Text("Edit Profile"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          final List<dynamic> friendsList = userData?['friends'] ?? [];
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FriendsListPage(friends: friendsList),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: statBox(safeString(userData, "friendsCount"), "Friends"),
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1, color: Colors.grey),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: statBox(_formatTimestamp(userData, "createdAt"), "Join Date"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text("Account Information", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor)),
          const SizedBox(height: 10),
          ListTile(
            leading: Icon(Icons.phone, color: primaryColor),
            title: Text(safeString(userData, "phone").isEmpty ? "No phone provided" : safeString(userData, "phone")),
            trailing: Icon(Icons.edit, color: primaryColor, size: 18),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfilePage(userData!)));
              _reloadUser();
            },
          ),
          ListTile(
            leading: Icon(Icons.email, color: primaryColor),
            title: Text(safeString(userData, "email")),
          ),
          const SizedBox(height: 20),
          Text("App Settings", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor)),
          const SizedBox(height: 10),
          ListTile(
            leading: Icon(Icons.brightness_6, color: primaryColor),
            title: const Text("Dark Mode"),
            trailing: Switch(
              value: context.watch<ThemeService>().isDarkMode,
              onChanged: (value) => context.read<ThemeService>().toggleTheme(value),
              activeColor: primaryColor,
            ),
          ),
          ListTile(
            leading: Icon(Icons.security, color: primaryColor),
            title: const Text("Privacy Settings"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacySettingsPage()));
            },
          ),
        ],
      ),
    );
  }
}