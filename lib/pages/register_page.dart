import 'package:flutter/material.dart';
import '../components/my_button.dart'; // Assuming you want to keep this
import '../components/my_textfield.dart'; // Assuming you want to keep this
import 'package:chat_app/auth/auth_service.dart'; // Assuming auth service is needed

class RegisterPage extends StatelessWidget {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pswController = TextEditingController();
  final TextEditingController _confirmpswController = TextEditingController();
  final void Function()? onTap;

  RegisterPage({super.key, required this.onTap});

  // Register method
  void register(BuildContext context) async {
    // Get auth service
    final _auth = AuthService();
    FocusScope.of(context).unfocus();
    // Check if passwords match
    if (_pswController.text == _confirmpswController.text) {
      try {
        // Create the user
        await _auth.registerEP(
          _emailController.text,
          _pswController.text,
        );
      await _auth.signOut(); 

      } catch (e) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Registration Failed"),
            content: Text(e.toString()),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"))
            ],
          ),
        );
      }
    }
    // If passwords don't match, show an error
    else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Password Mismatch"),
          content: const Text("The passwords do not match."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            )
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch, // Make children stretch to fill width
              children: [
                const SizedBox(height: 50),

                // Logo
                Image.asset(
                  'assets/images/logo216.png', // Assuming this is your logo from the image
                  height: 100,
                ),
                const SizedBox(height: 40),

                // Title: "Create your account"
                const Text(
                  "Create your account",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),

                // Subtitle
                const Text(
                  "Join us! Enter your details to get started.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 40),

                // --- TEXT FIELDS ---
                // Full Name TextField
                MyTextfield(
                  holderPlace: "Full Name",
                  obscurtext: false,
                  controller: _nameController,
                ),
                const SizedBox(height: 20),

                // Email TextField
                MyTextfield(
                  holderPlace: "Email",
                  obscurtext: false,
                  controller: _emailController,
                ),
                const SizedBox(height: 20),

                // Password TextField
                MyTextfield(
                  holderPlace: "Password",
                  obscurtext: true,
                  controller: _pswController,
                ),
                const SizedBox(height: 20),

                // Confirm Password TextField
                MyTextfield(
                  holderPlace: "Confirm Password",
                  obscurtext: true,
                  controller: _confirmpswController,
                ),
                const SizedBox(height: 40),

                // --- BUTTON AND NAVIGATION ---
                // Register Button using your MyButton component
                MyButton(
                  text: "Create Account", // Changed text to match UI
                  onTap: () => register(context),
                ),
                const SizedBox(height: 25),

                // "Already have an account? Log In"
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Already have your account? ",
                      style: TextStyle(color: Colors.grey,fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Text(
            "Log In",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}