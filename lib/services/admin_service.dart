import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Check if current user is admin
  Future<bool> isCurrentUserAdmin(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        return data?['isAdmin'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  // Get all users (for admin)
  Future<List<UserModel>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      return snapshot.docs.map((doc) {
        return UserModel.fromJson(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch users: $e');
    }
  }

  // Stream all users
  Stream<List<UserModel>> getUsersStream() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return UserModel.fromJson(doc.data(), doc.id);
      }).toList();
    });
  }

  // Toggle user active status (deactivate/activate)
  Future<void> toggleUserStatus(String userId, bool isActive) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isActive': isActive,
      });
    } catch (e) {
      throw Exception('Failed to update user status: $e');
    }
  }

  Future<void> createAdminAccount({
    required String email,
    required String password,
    required String fullName,
    required DateTime birthDate,
    String? photoURL,
  }) async {
    try {
      // Create user in Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Create user document with admin privileges
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'email': email,
          'fullName': fullName,
          'birthDate': birthDate.toIso8601String(),
          'photoURL': photoURL,
          'isAdmin': true,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'favoriteMovies': [],
          'matchedUsers': [],
        });
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'weak-password':
          message = 'The password is too weak';
          break;
        case 'email-already-in-use':
          message = 'An account already exists with this email';
          break;
        case 'invalid-email':
          message = 'Invalid email address';
          break;
        default:
          message = e.message ?? 'An error occurred';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('Failed to create admin account: $e');
    }
  }

  Future<String> addMovie({
    required String title,
    required String overview,
    required String posterUrl,
    required String trailerUrl,
    required double rating,
    required String releaseDate,
    required List<String> genres,
    List<String>? productions,
    int? runtime,
    int? budget,
    int? revenue,
    String? tagline,
    String? status,
    String? originalLanguage,
  }) async {
    try {
      final docRef = await _firestore.collection('custom_movies').add({
        'title': title,
        'overview': overview,
        'posterUrl': posterUrl,
        'trailerUrl': trailerUrl,
        'rating': rating,
        'releaseDate': releaseDate,
        'genres': genres,
        'productions': productions ?? [],
        'runtime': runtime,
        'budget': budget,
        'revenue': revenue,
        'tagline': tagline,
        'status': status ?? 'Released',
        'originalLanguage': originalLanguage ?? 'en',
        'isCustom': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add movie: $e');
    }
  }

  // Get all custom movies
  Future<List<Map<String, dynamic>>> getCustomMovies() async {
    try {
      final snapshot = await _firestore
          .collection('custom_movies')
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch custom movies: $e');
    }
  }

  // Stream custom movies
  Stream<List<Map<String, dynamic>>> getCustomMoviesStream() {
    return _firestore
        .collection('custom_movies')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  // Update a custom movie
  Future<void> updateMovie(String movieId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('custom_movies').doc(movieId).update(data);
    } catch (e) {
      throw Exception('Failed to update movie: $e');
    }
  }

  // Delete a custom movie
  Future<void> deleteMovie(String movieId) async {
    try {
      await _removeMovieFromAllFavorites(movieId);
      
      // Then delete the movie itself
      await _firestore.collection('custom_movies').doc(movieId).delete();
    } catch (e) {
      throw Exception('Failed to delete movie: $e');
    }
  }

  Future<void> _removeMovieFromAllFavorites(String movieId) async {
    try {
      // Get all users
      final usersSnapshot = await _firestore.collection('users').get();
      
      // Create a batch for efficient deletion
      final batch = _firestore.batch();
      
      for (final userDoc in usersSnapshot.docs) {
        // Check if this user has this movie in favorites
        final favoriteDoc = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('favorites')
            .doc(movieId)
            .get();
        
        if (favoriteDoc.exists) {
          batch.delete(favoriteDoc.reference);
        }
      }
      
      // Commit the batch
      await batch.commit();
    } catch (e) {
      print('Error removing movie from favorites: $e');
      // Don't throw here, we still want to delete the movie even if this fails
    }
  }
}
