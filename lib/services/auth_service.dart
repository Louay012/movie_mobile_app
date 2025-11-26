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
      // Validate inputs
      if (email.isEmpty || password.isEmpty) {
        return AuthResponse(
          success: false,
          message: 'Email and password are required',
        );
      }

      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      return AuthResponse(success: true, uid: cred.user?.uid);
    } on FirebaseAuthException catch (e) {
      return AuthResponse(
        success: false,
        message: _getErrorMessage(e.code),
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Signup failed: ${e.toString()}',
      );
    }
  }

  // Sign in with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // Validate inputs
      if (email.isEmpty || password.isEmpty) {
        return AuthResponse(
          success: false,
          message: 'Email and password are required',
        );
      }

      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      return AuthResponse(success: true, uid: cred.user?.uid);
    } on FirebaseAuthException catch (e) {
      return AuthResponse(
        success: false,
        message: _getErrorMessage(e.code),
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Login failed: ${e.toString()}',
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
      if (displayName != null && displayName.isNotEmpty) {
        await user.updateDisplayName(displayName);
      }
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }
      await user.reload();
      
      return AuthResponse(success: true);
    } on FirebaseAuthException catch (e) {
      return AuthResponse(
        success: false,
        message: _getErrorMessage(e.code),
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Failed to update profile: ${e.toString()}',
      );
    }
  }

  // Send password reset email
  Future<AuthResponse> sendPasswordResetEmail(String email) async {
    try {
      if (email.isEmpty) {
        return AuthResponse(
          success: false,
          message: 'Email is required',
        );
      }

      await _auth.sendPasswordResetEmail(email: email);
      
      return AuthResponse(
        success: true,
        message: 'Password reset email sent',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResponse(
        success: false,
        message: _getErrorMessage(e.code),
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Failed to send reset email: ${e.toString()}',
      );
    }
  }

  // Sign out
  Future<AuthResponse> signOut() async {
    try {
      await _auth.signOut();
      return AuthResponse(success: true);
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Failed to sign out: ${e.toString()}',
      );
    }
  }

  // Delete user account
  Future<AuthResponse> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResponse(
          success: false,
          message: 'No user logged in',
        );
      }

      await user.delete();
      
      return AuthResponse(
        success: true,
        message: 'Account deleted successfully',
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return AuthResponse(
          success: false,
          message: 'Please log in again before deleting your account',
        );
      }
      return AuthResponse(
        success: false,
        message: _getErrorMessage(e.code),
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Failed to delete account: ${e.toString()}',
      );
    }
  }

  // Reauthenticate user (useful before sensitive operations)
  Future<AuthResponse> reauthenticate({
    required String email,
    required String password,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResponse(
          success: false,
          message: 'No user logged in',
        );
      }

      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      
      return AuthResponse(success: true);
    } on FirebaseAuthException catch (e) {
      return AuthResponse(
        success: false,
        message: _getErrorMessage(e.code),
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Reauthentication failed: ${e.toString()}',
      );
    }
  }

  // Get comprehensive error message from Firebase auth error code
  String _getErrorMessage(String code) {
    switch (code) {
      // Password errors
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      
      // Email errors
      case 'email-already-in-use':
        return 'This email is already registered. Please log in instead.';
      case 'invalid-email':
        return 'Invalid email address format.';
      
      // User errors
      case 'user-not-found':
        return 'No account found with this email.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      
      // Network errors
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      
      // Rate limiting
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      
      // Credential errors
      case 'invalid-credential':
        return 'Invalid credentials. Please check your email and password.';
      case 'operation-not-allowed':
        return 'This operation is not allowed. Contact support.';
      case 'requires-recent-login':
        return 'Please log in again to perform this action.';
      
      // Account management
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using a different sign-in method.';
      
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}