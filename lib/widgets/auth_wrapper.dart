import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../screens/deactivated_screen.dart';

/// A widget that protects routes by checking if user is authenticated.
/// If not authenticated, redirects to welcome screen.
/// If deactivated, shows deactivated screen.
/// If admin accessing regular user pages, redirects to admin home.
class AuthWrapper extends StatefulWidget {
  final Widget child;
  final bool allowAdmin;
  
  const AuthWrapper({super.key, required this.child, this.allowAdmin = true});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool _isChecked = false;
  bool _isActive = true;
  bool _isAdmin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkUser();
  }

  Future<void> _checkUser() async {
    if (!_authService.isUserLoggedIn()) {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_authService.getCurrentUserId())
          .get();

      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _isActive = data?['isActive'] ?? true;
          _isAdmin = data?['isAdmin'] ?? false;
          _isChecked = true;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isChecked = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isChecked = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
        ),
      );
    }

    if (!_isActive) {
      return const DeactivatedScreen();
    }

    if (_isAdmin && !widget.allowAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushNamedAndRemoveUntil('/admin/home', (route) => false);
      });
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent)),
      );
    }

    return widget.child;
  }
}

/// A widget that protects guest-only routes (login/signup/welcome).
/// If user is already authenticated, redirects based on role.
class GuestWrapper extends StatefulWidget {
  final Widget child;
  
  const GuestWrapper({super.key, required this.child});

  @override
  State<GuestWrapper> createState() => _GuestWrapperState();
}

class _GuestWrapperState extends State<GuestWrapper> {
  final AuthService _authService = AuthService();
  bool _isChecked = false;
  bool _shouldRedirect = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkUser();
  }

  Future<void> _checkUser() async {
    if (!_authService.isUserLoggedIn()) {
      if (mounted) {
        setState(() => _isChecked = true);
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_authService.getCurrentUserId())
          .get();

      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _isAdmin = data?['isAdmin'] ?? false;
          _shouldRedirect = true;
          _isChecked = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isChecked = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isChecked) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
        ),
      );
    }

    if (_shouldRedirect) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isAdmin) {
          Navigator.of(context).pushNamedAndRemoveUntil('/admin/home', (route) => false);
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        }
      });
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent)),
      );
    }

    return widget.child;
  }
}

/// A widget that protects admin-only routes.
/// If user is not admin, redirects to home screen.
class AdminWrapper extends StatefulWidget {
  final Widget child;
  
  const AdminWrapper({super.key, required this.child});

  @override
  State<AdminWrapper> createState() => _AdminWrapperState();
}

class _AdminWrapperState extends State<AdminWrapper> {
  final AuthService _authService = AuthService();
  bool _isChecked = false;
  bool _isAdmin = false;
  bool _isActive = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkUser();
  }

  Future<void> _checkUser() async {
    if (!_authService.isUserLoggedIn()) {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_authService.getCurrentUserId())
          .get();

      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _isAdmin = data?['isAdmin'] ?? false;
          _isActive = data?['isActive'] ?? true;
          _isChecked = true;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isChecked = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isChecked = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
        ),
      );
    }

    if (!_isActive) {
      return const DeactivatedScreen();
    }

    if (!_isAdmin) {
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
        body: Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent)),
      );
    }

    return widget.child;
  }
}
