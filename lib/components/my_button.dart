import 'package:flutter/material.dart';

class MyButton extends StatelessWidget {
  final String text;
  final void Function()? onTap;

  const MyButton({
    super.key,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // 1. UPDATED: Padding is now vertical to control the height.
        padding: const EdgeInsets.symmetric(vertical: 16),
        
        // 2. UPDATED: Decoration for color and shape.
        decoration: BoxDecoration(
          // Use the primary theme color for a consistent look.
          color: Theme.of(context).colorScheme.primary, 
          // Make it fully rounded to match the pill-shape in the design.
          borderRadius: BorderRadius.circular(30),
        ),

        // 3. REMOVED: The 'margin' property has been removed.
        
        child: Center(
          child: Text(
            text,
            // 4. ADDED: Text style for white, bold, and larger text.
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }
}