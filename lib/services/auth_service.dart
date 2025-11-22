import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return cred.user;
    } on FirebaseAuthException catch (e) {
      print('Auth signUp error: $e');
      rethrow;
    }
  }

  // Sign in and return the Firebase User
  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final userCred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCred.user;
  }

  Future<void> updateProfile({
    required User user,
    String? displayName,
    String? photoURL,
  }) async {
    await user.updateDisplayName(displayName);
    if (photoURL != null) await user.updatePhotoURL(photoURL);
    await user.reload();
  }

  Future<void> signOut() async => _auth.signOut();
}
