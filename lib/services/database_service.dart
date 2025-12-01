import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class DatabaseServiceException implements Exception {
  final String message;
  
  DatabaseServiceException(this.message);
  
  @override
  String toString() => message;
}

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _usersCollection = 'users';

  // Create user document in Firestore
  Future<bool> createUser(UserModel user) async {
    try {
      // Validate user data
      if (user.uid.isEmpty) {
        throw DatabaseServiceException('User ID is required');
      }
      
      if (user.email.isEmpty) {
        throw DatabaseServiceException('Email is required');
      }
      
      if (user.fullName.isEmpty) {
        throw DatabaseServiceException('Full name is required');
      }

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .set(
            user.toJson(),
            SetOptions(merge: true),
          );
      
      return true;
    } on FirebaseException catch (e) {
      print('Firebase error creating user: ${e.code} - ${e.message}');
      
      if (e.code == 'permission-denied') {
        throw DatabaseServiceException(
          'Permission denied. Please check your account.',
        );
      } else if (e.code == 'unavailable') {
        throw DatabaseServiceException(
          'Service unavailable. Please check your internet connection.',
        );
      }
      
      throw DatabaseServiceException(
        'Failed to create user: ${e.message ?? "Unknown error"}',
      );
    } on DatabaseServiceException {
      rethrow;
    } catch (e) {
      print('Unexpected error creating user: $e');
      throw DatabaseServiceException(
        'Unexpected error creating user: ${e.toString()}',
      );
    }
  }

  // Get user by UID
  Future<UserModel?> getUser(String uid) async {
    try {
      if (uid.isEmpty) {
        throw DatabaseServiceException('User ID is required');
      }

      DocumentSnapshot doc = await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        if (data == null) {
          print('User document exists but data is null');
          return null;
        }
        
        try {
          return UserModel.fromJson(data as Map<String, dynamic>, uid);
        } catch (e) {
          print('Error parsing user data: $e');
          throw DatabaseServiceException('Failed to parse user data');
        }
      }
      
      return null;
    } on FirebaseException catch (e) {
      print('Firebase error getting user: ${e.code} - ${e.message}');
      
      if (e.code == 'permission-denied') {
        throw DatabaseServiceException(
          'Permission denied. Please check your account.',
        );
      } else if (e.code == 'unavailable') {
        throw DatabaseServiceException(
          'Service unavailable. Please check your internet connection.',
        );
      }
      
      throw DatabaseServiceException(
        'Failed to get user: ${e.message ?? "Unknown error"}',
      );
    } on DatabaseServiceException {
      rethrow;
    } catch (e) {
      print('Unexpected error getting user: $e');
      throw DatabaseServiceException(
        'Unexpected error getting user: ${e.toString()}',
      );
    }
  }

  Future<UserModel?> getUserById(String uid) async {
    return await getUser(uid);
  }

  // Update user data
  Future<bool> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      if (uid.isEmpty) {
        throw DatabaseServiceException('User ID is required');
      }
      
      if (data.isEmpty) {
        throw DatabaseServiceException('Update data cannot be empty');
      }

      // Validate that we're not trying to update with null/empty critical fields
      if (data.containsKey('email') && 
          (data['email'] == null || data['email'].toString().isEmpty)) {
        throw DatabaseServiceException('Email cannot be empty');
      }
      
      if (data.containsKey('fullName') && 
          (data['fullName'] == null || data['fullName'].toString().isEmpty)) {
        throw DatabaseServiceException('Full name cannot be empty');
      }

      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .update(data);
      
      return true;
    } on FirebaseException catch (e) {
      print('Firebase error updating user: ${e.code} - ${e.message}');
      
      if (e.code == 'permission-denied') {
        throw DatabaseServiceException(
          'Permission denied. Please check your account.',
        );
      } else if (e.code == 'not-found') {
        throw DatabaseServiceException(
          'User not found. Please try logging in again.',
        );
      } else if (e.code == 'unavailable') {
        throw DatabaseServiceException(
          'Service unavailable. Please check your internet connection.',
        );
      }
      
      throw DatabaseServiceException(
        'Failed to update user: ${e.message ?? "Unknown error"}',
      );
    } on DatabaseServiceException {
      rethrow;
    } catch (e) {
      print('Unexpected error updating user: $e');
      throw DatabaseServiceException(
        'Unexpected error updating user: ${e.toString()}',
      );
    }
  }

  Future<bool> updateUserProfile({
    required String userId,
    required String fullName,
    required DateTime birthDate,
    String? photoURL,
  }) async {
    try {
      if (userId.isEmpty) {
        throw DatabaseServiceException('User ID is required');
      }
      
      if (fullName.isEmpty) {
        throw DatabaseServiceException('Full name is required');
      }

      final Map<String, dynamic> updateData = {
        'fullName': fullName,
        'birthDate': birthDate.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (photoURL != null) {
        updateData['photoURL'] = photoURL;
      }

      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .update(updateData);
      
      return true;
    } on FirebaseException catch (e) {
      print('Firebase error updating user profile: ${e.code} - ${e.message}');
      
      if (e.code == 'permission-denied') {
        throw DatabaseServiceException(
          'Permission denied. Please check your account.',
        );
      } else if (e.code == 'not-found') {
        throw DatabaseServiceException(
          'User not found. Please try logging in again.',
        );
      }
      
      throw DatabaseServiceException(
        'Failed to update profile: ${e.message ?? "Unknown error"}',
      );
    } on DatabaseServiceException {
      rethrow;
    } catch (e) {
      print('Unexpected error updating user profile: $e');
      throw DatabaseServiceException(
        'Unexpected error updating profile: ${e.toString()}',
      );
    }
  }

  // Update user with image (base64)
  Future<bool> updateUserWithImage(String uid, String base64Image) async {
    try {
      if (uid.isEmpty) {
        throw DatabaseServiceException('User ID is required');
      }
      
      if (base64Image.isEmpty) {
        throw DatabaseServiceException('Image data is required');
      }

      // Check if base64 image is too large (Firestore has 1MB limit per document)
      // Base64 is roughly 1.37x the original size
      final imageSizeBytes = base64Image.length;
      final imageSizeKB = imageSizeBytes / 1024;
      
      if (imageSizeKB > 800) { // Leave some room for other fields
        throw DatabaseServiceException(
          'Image is too large (${imageSizeKB.toStringAsFixed(0)} KB). Please use a smaller image.',
        );
      }

      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .update({
            'photoURL': base64Image,
            'updatedAt': DateTime.now().toIso8601String(),
          });
      
      return true;
    } on FirebaseException catch (e) {
      print('Firebase error updating user image: ${e.code} - ${e.message}');
      
      if (e.code == 'permission-denied') {
        throw DatabaseServiceException(
          'Permission denied. Please check your account.',
        );
      } else if (e.code == 'not-found') {
        throw DatabaseServiceException(
          'User not found. Please try logging in again.',
        );
      } else if (e.code == 'unavailable') {
        throw DatabaseServiceException(
          'Service unavailable. Please check your internet connection.',
        );
      }
      
      throw DatabaseServiceException(
        'Failed to update image: ${e.message ?? "Unknown error"}',
      );
    } on DatabaseServiceException {
      rethrow;
    } catch (e) {
      print('Unexpected error updating user image: $e');
      throw DatabaseServiceException(
        'Unexpected error updating image: ${e.toString()}',
      );
    }
  }

  // Delete user document
  Future<bool> deleteUser(String uid) async {
    try {
      if (uid.isEmpty) {
        throw DatabaseServiceException('User ID is required');
      }

      // First, delete all favorites
      try {
        final favoritesSnapshot = await _firestore
            .collection(_usersCollection)
            .doc(uid)
            .collection('favorites')
            .get();
        
        for (var doc in favoritesSnapshot.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        print('Error deleting favorites: $e');
        // Continue with user deletion even if favorites deletion fails
      }

      // Then delete user document
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .delete();
      
      return true;
    } on FirebaseException catch (e) {
      print('Firebase error deleting user: ${e.code} - ${e.message}');
      
      if (e.code == 'permission-denied') {
        throw DatabaseServiceException(
          'Permission denied. Please check your account.',
        );
      } else if (e.code == 'unavailable') {
        throw DatabaseServiceException(
          'Service unavailable. Please check your internet connection.',
        );
      }
      
      throw DatabaseServiceException(
        'Failed to delete user: ${e.message ?? "Unknown error"}',
      );
    } on DatabaseServiceException {
      rethrow;
    } catch (e) {
      print('Unexpected error deleting user: $e');
      throw DatabaseServiceException(
        'Unexpected error deleting user: ${e.toString()}',
      );
    }
  }

  // Check if user exists
  Future<bool> userExists(String uid) async {
    try {
      if (uid.isEmpty) {
        return false;
      }

      final doc = await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .get();
      
      return doc.exists;
    } catch (e) {
      print('Error checking if user exists: $e');
      return false;
    }
  }
}
