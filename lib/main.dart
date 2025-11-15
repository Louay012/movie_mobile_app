// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/loading.dart';

void main() {
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
      home: const LoadingScreen(), // Starts with splash / loading
    );
  }
}
