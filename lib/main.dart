import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/loading.dart';
import 'screens/signup.dart';
import 'screens/login.dart';
import 'screens/home.dart';
import 'screens/favorites.dart';
import 'screens/profile_screen.dart';
import 'widgets/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
      home: const LoadingScreen(),
      routes: {
        '/signup': (context) => const GuestWrapper(child: SignUpScreen()),
        '/login': (context) => const GuestWrapper(child: LoginScreen()),
        '/home': (context) => const AuthWrapper(child: HomePage()),
        '/favorites': (context) => const AuthWrapper(child: FavoritesScreen()),
        '/profile': (context) => const AuthWrapper(child: ProfileScreen()),
      },
    );
  }
}
