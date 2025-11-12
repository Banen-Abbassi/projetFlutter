import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(context, "/login", (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.logout),
      tooltip: "Logout",
      onPressed: () => _logout(context),
    );
  }
}
