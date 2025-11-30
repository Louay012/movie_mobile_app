import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// A widget that protects routes by checking if user is authenticated.
/// If not authenticated, redirects to login screen.
class AuthWrapper extends StatelessWidget {
  final Widget child;
  
  const AuthWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    
    if (!authService.isUserLoggedIn()) {
      // Redirect to login after build completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      });
      
      // Show loading while redirecting
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return child;
  }
}

/// A widget that protects guest-only routes (login/signup).
/// If user is already authenticated, redirects to home screen.
class GuestWrapper extends StatelessWidget {
  final Widget child;
  
  const GuestWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    
    if (authService.isUserLoggedIn()) {
      // Redirect to home after build completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      });
      
      // Show loading while redirecting
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return child;
  }
}
