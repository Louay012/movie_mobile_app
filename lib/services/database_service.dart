import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _usersCollection = 'users';

  // Create user document in Firestore
  Future<bool> createUser(UserModel user) async {
    try {
      await _firestore.collection(_usersCollection).doc(user.uid).set(
        user.toJson(),
        SetOptions(merge: true),
      );
      return true;
    } catch (e) {
      print('Database error creating user: $e');
      return false;
    }
  }

  // Get user by UID
  Future<UserModel?> getUser(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection(_usersCollection).doc(uid).get();
      if (doc.exists) {
        return UserModel.fromJson(doc.data() as Map<String, dynamic>, uid);
      }
      return null;
    } catch (e) {
      print('Database error getting user: $e');
      return null;
    }
  }

  // Update user data
  Future<bool> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .update(data);
      return true;
    } catch (e) {
      print('Database error updating user: $e');
      return false;
    }
  }

  Future<bool> updateUserWithImage(String uid, String base64Image) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .update({'photoURL': base64Image});
      return true;
    } catch (e) {
      print('Database error updating user image: $e');
      return false;
    }
  }

  // Delete user document
  Future<bool> deleteUser(String uid) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).delete();
      return true;
    } catch (e) {
      print('Database error deleting user: $e');
      return false;
    }
  }
}
