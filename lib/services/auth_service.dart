import 'package:firebase_auth/firebase_auth.dart';
import '../models/auth_response.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  // Get current user ID
  String? getCurrentUserId() => _auth.currentUser?.uid;

  // Check if user is logged in
  bool isUserLoggedIn() => _auth.currentUser != null;

  // Sign up with email and password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return AuthResponse(success: true, uid: cred.user?.uid);
    } on FirebaseAuthException catch (e) {
      return AuthResponse(success: false, message: _getErrorMessage(e.code));
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'An unexpected error occurred',
      );
    }
  }

  // Sign in with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return AuthResponse(success: true, uid: cred.user?.uid);
    } on FirebaseAuthException catch (e) {
      return AuthResponse(success: false, message: _getErrorMessage(e.code));
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'An unexpected error occurred',
      );
    }
  }

  // Update user profile
  Future<AuthResponse> updateProfile({
    required User user,
    String? displayName,
    String? photoURL,
  }) async {
    try {
      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }
      await user.reload();
      return AuthResponse(success: true);
    } catch (e) {
      return AuthResponse(success: false, message: 'Failed to update profile');
    }
  }

  // Sign out
  Future<void> signOut() => _auth.signOut();

  // Get error message from Firebase auth error code
  String _getErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'Password is too weak';
      case 'email-already-in-use':
        return 'Email already in use';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-not-found':
        return 'User not found';
      case 'wrong-password':
        return 'Wrong password';
      case 'too-many-requests':
        return 'Too many login attempts. Try again later';
      default:
        return 'Authentication failed';
    }
  }
}
