import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../widgets/movieflix_logo.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(const Duration(seconds: AppConstants.splashDuration));

    if (!mounted) return;

    if (_auth.isUserLoggedIn()) {
      try {
        final userId = _auth.getCurrentUserId();
        if (userId != null) {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

          if (doc.exists) {
            final data = doc.data();
            final isActive = data?['isActive'] ?? true;
            final isAdmin = data?['isAdmin'] ?? false;

            if (!mounted) return;

            if (!isActive) {
              Navigator.pushReplacementNamed(context, '/deactivated');
            } else if (isAdmin) {
              Navigator.pushReplacementNamed(context, '/admin/home');
            } else {
              Navigator.pushReplacementNamed(context, '/home');
            }
            return;
          }
        }
      } catch (e) {
        // Fallback to home on error
      }
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const MovieFlixLogo(size: 100),
            const SizedBox(height: 8),

            // Tagline
            Text(
              'Discover Your Next Favorite Movie',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 40),

            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.deepPurpleAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
