import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/loading.dart';
import 'screens/signup.dart';
import 'screens/login.dart';
import 'screens/home.dart';
import 'screens/favorites.dart';
import 'screens/profile_screen.dart';
import 'screens/matching_screen.dart';
import 'screens/admin_users_screen.dart';
import 'screens/admin_movies_screen.dart';
import 'screens/admin_home_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/deactivated_screen.dart';
import 'screens/admin_profile_screen.dart';
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
      initialRoute: '/',
      routes: {
        '/': (context) => const LoadingScreen(),
        '/welcome': (context) => const GuestWrapper(child: WelcomeScreen()),
        '/signup': (context) => const GuestWrapper(child: SignUpScreen()),
        '/login': (context) => const GuestWrapper(child: LoginScreen()),
        '/home': (context) => const AuthWrapper(child: HomePage(), allowAdmin: false),
        '/favorites': (context) => const AuthWrapper(child: FavoritesScreen(), allowAdmin: false),
        '/profile': (context) => const AuthWrapper(child: ProfileScreen(), allowAdmin: false),
        '/matching': (context) => const AuthWrapper(child: MatchingScreen(), allowAdmin: false),
        '/admin/home': (context) => const AdminWrapper(child: AdminHomeScreen()),
        '/admin/users': (context) => const AdminWrapper(child: AdminUsersScreen()),
        '/admin/movies': (context) => const AdminWrapper(child: AdminMoviesScreen()),
        '/admin/profile': (context) => const AdminWrapper(child: AdminProfileScreen()),
        '/deactivated': (context) => const DeactivatedScreen(),
      },
    );
  }
}
