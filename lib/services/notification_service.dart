import 'package:flutter/material.dart';

class NotificationService {

  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();


  static void showInAppNotification(
      {required String title, required String body, VoidCallback? onTap}) {
    // Ensure the key is attached to the widget tree.
    if (scaffoldMessengerKey.currentState == null) {
      debugPrint("ScaffoldMessengerKey not available.");
      return;
    }

    // Define the interactive content of the SnackBar.
    final snackBarContent = GestureDetector(
      onTap: () {
        // When tapped, immediately hide the SnackBar and execute the callback.
        scaffoldMessengerKey.currentState!.hideCurrentSnackBar();
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // A dark, semi-translucent color for a modern look.
          color: const Color(0xFF333333),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );

    // Create the SnackBar with a transparent background to let our custom container shine.
    final snackBar = SnackBar(
      content: snackBarContent,
      backgroundColor: Colors.transparent, // Important for custom container style.
      elevation: 0, // No shadow.
      duration: const Duration(seconds: 5), // How long it stays on screen if not dismissed.
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );

    // Hide any currently visible SnackBar and then show the new one.
    scaffoldMessengerKey.currentState!
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }
}