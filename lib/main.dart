import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';   // Add this
import 'firebase_options.dart';                      // Add this
import 'screens/loading.dart';
import 'screens/home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();        // Required for async initialization
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Initialize Firebase
  );
  runApp(const MovieApp());
}

class MovieApp extends StatelessWidget {
  const MovieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MovieFlix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: HomePage(), // Starts with splash / loading
    );
  }
}
