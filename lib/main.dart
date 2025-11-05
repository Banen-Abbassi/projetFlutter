import 'package:chat_app/auth/auth_gate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'themes/light_modes.dart'; // optional, if you have a theme
import 'package:provider/provider.dart';
import 'themes/theme_service.dart';
import 'themes/dark_mode.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
<<<<<<< Updated upstream
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: const MyApp(),
    ),
  );
  }
=======
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAuth.instance.signOut();

  runApp(const MyApp());
}
>>>>>>> Stashed changes

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
      final themeService = Provider.of<ThemeService>(context);

    return MaterialApp(
      title: 'Chat App',
      debugShowCheckedModeBanner: false,
      theme: lightMode,
      darkTheme: darkMode,
      themeMode: themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const AuthGate(),
    );
  }
}
