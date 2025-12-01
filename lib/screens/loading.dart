import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

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
    await Future.delayed(
      const Duration(seconds: AppConstants.splashDuration),
    );

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
            // App Logo - Updated to match new branding
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.amber.shade600, Colors.orange.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.movie_filter,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            // App Name
            const Text(
              'Film Explorer',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),

            // Tagline
            Text(
              'Discover Your Next Favorite Movie',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 40),

            // Loading Indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ],
        ),
      ),
    );
  }
}
