import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../screens/deactivated_screen.dart';
import '../screens/admin_home_screen.dart';

/// A widget that protects routes by checking if user is authenticated.
/// If not authenticated, redirects to welcome screen.
/// If deactivated, shows deactivated screen.
/// If admin accessing regular user pages, redirects to admin home.
class AuthWrapper extends StatelessWidget {
  final Widget child;
  final bool allowAdmin;
  
  const AuthWrapper({super.key, required this.child, this.allowAdmin = true});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    
    if (!authService.isUserLoggedIn()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
      });
      
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.amber),
        ),
      );
    }
    
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(authService.getCurrentUserId())
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator(color: Colors.amber)),
          );
        }
        
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final isActive = data?['isActive'] ?? true;
          final isAdmin = data?['isAdmin'] ?? false;
          
          if (!isActive) {
            return const DeactivatedScreen();
          }
          
          if (isAdmin && !allowAdmin) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushNamedAndRemoveUntil('/admin/home', (route) => false);
            });
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(child: CircularProgressIndicator(color: Colors.amber)),
            );
          }
        }
        
        return child;
      },
    );
  }
}

/// A widget that protects guest-only routes (login/signup/welcome).
/// If user is already authenticated, redirects based on role.
class GuestWrapper extends StatelessWidget {
  final Widget child;
  
  const GuestWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    
    if (authService.isUserLoggedIn()) {
      // Check if admin or regular user
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(authService.getCurrentUserId())
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(child: CircularProgressIndicator(color: Colors.amber)),
            );
          }
          
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            final isAdmin = data?['isAdmin'] ?? false;
            
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (isAdmin) {
                Navigator.of(context).pushNamedAndRemoveUntil('/admin/home', (route) => false);
              } else {
                Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
              }
            });
          }
          
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator(color: Colors.amber)),
          );
        },
      );
    }
    
    return child;
  }
}

/// A widget that protects admin-only routes.
/// If user is not admin, redirects to home screen.
class AdminWrapper extends StatelessWidget {
  final Widget child;
  
  const AdminWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    
    if (!authService.isUserLoggedIn()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
      });
      
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.amber),
        ),
      );
    }
    
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(authService.getCurrentUserId())
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator(color: Colors.amber)),
          );
        }
        
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final isAdmin = data?['isAdmin'] ?? false;
          final isActive = data?['isActive'] ?? true;
          
          if (!isActive) {
            return const DeactivatedScreen();
          }
          
          if (!isAdmin) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Access denied. Admin privileges required.'),
                  backgroundColor: Colors.red,
                ),
              );
            });
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(child: CircularProgressIndicator(color: Colors.amber)),
            );
          }
        }
        
        return child;
      },
    );
  }
}
