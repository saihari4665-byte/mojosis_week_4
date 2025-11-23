// In lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'firebase_options.dart'; // Import your config file

import 'auth_screen.dart';
import 'main_menu_screen.dart';

// 1. main() is now async
Future<void> main() async {
  // 2. Ensure Flutter is ready
  WidgetsFlutterBinding.ensureInitialized();


  // 3. Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChessClan UI',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primarySwatch: Colors.blue,
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.blueAccent,
          surface: Color(0xFF121212),
        ),
        iconTheme: const IconThemeData(
          color: Colors.blueAccent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          elevation: 0,
        ),
        tabBarTheme: const TabBarThemeData(
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(color: Colors.blueAccent, width: 2.0),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.blueAccent,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.black,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade800,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),

      // 4. This StreamBuilder automatically shows the right screen!
      home: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (ctx, userSnapshot) {
          if (userSnapshot.hasData) {
            // User is logged in
            return const MainMenuScreen();
          }
          // User is not logged in
          return const AuthScreen();
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}