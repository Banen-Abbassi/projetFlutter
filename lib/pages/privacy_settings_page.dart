import 'package:flutter/material.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  bool onlineStatus = true;
  bool lastSeenVisible = true;

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Privacy Settings",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            "Online Status",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          _buildSwitchTile(
            title: "Who can see my online status",
            value: onlineStatus,
            onChanged: (val) => setState(() => onlineStatus = val),
          ),
          _buildSwitchTile(
            title: "Who can see my last seen",
            value: lastSeenVisible,
            onChanged: (val) => setState(() => lastSeenVisible = val),
          ),
          _buildNavigationTile(
            title: "Last seen",
            subtitle: "Everyone",
            icon: Icons.visibility,
            onTap: () {},
          ),
          const SizedBox(height: 20),

          const Text(
            "Blocked Users",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          _buildNavigationTile(
            title: "Blocked contacts",
            icon: Icons.block,
            onTap: () {},
          ),
          const SizedBox(height: 20),

          const Text(
            "Data & Security",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          _buildNavigationTile(
            title: "Two-step verification",
            subtitle: "On",
            icon: Icons.verified_user,
            onTap: () {},
          ),
          _buildNavigationTile(
            title: "Account deletion",
            subtitle: "Two-step verification",
            icon: Icons.delete_forever,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  // 🔹 Helper: build a tile with a switch
  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required Function(bool) onChanged,
  }) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 Helper: build a navigation tile with an icon
  Widget _buildNavigationTile({
    required String title,
    String? subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
