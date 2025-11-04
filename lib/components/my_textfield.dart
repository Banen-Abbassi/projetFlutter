import 'package:flutter/material.dart';

class MyTextfield extends StatelessWidget {
  final String holderPlace;
  final bool obscurtext;
  final TextEditingController controller;

  const MyTextfield({
    super.key,
    required this.holderPlace,
    required this.obscurtext,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    // No need for the extra Padding widget here, as it's better to
    // handle padding on the page itself for consistent spacing.
    // If you want it, you can wrap the TextField again.
    return TextField(
      controller: controller,
      obscureText: obscurtext,
      decoration: InputDecoration(
        // 1. CHANGED: Use labelText to get the floating label effect from the design.
        labelText: holderPlace,
        labelStyle: const TextStyle(color: Colors.grey),
        
        // 2. ADDED: Padding inside the text field for better visuals.
        contentPadding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),

        // 3. REMOVED: `fillColor` and `filled` properties to match the white background.

        // 4. UPDATED: Borders to have rounded corners.
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.0), // Rounded corners
          borderSide: const BorderSide(color: Colors.grey, width: 1.0), // Consistent grey border
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.0), // Rounded corners
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2.0),
        ),
      ),
    );
  }
}