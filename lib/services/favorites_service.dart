import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoritesServiceException implements Exception {
  final String message;
  
  FavoritesServiceException(this.message);
  
  @override
  String toString() => message;
}

class FavoritesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _getPosterUrl(String? posterPath) {
    if (posterPath == null || posterPath.isEmpty) return '';
    if (posterPath.startsWith('http')) return posterPath;
    return 'https://image.tmdb.org/t/p/w500$posterPath';
  }

  String? _getCurrentUserId() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw FavoritesServiceException('User not authenticated. Please log in.');
    }
    return userId;
  }

  // Add movie to favorites
  Future<void> addToFavorites(dynamic movie) async {
    try {
      final userId = _getCurrentUserId();
      
      // Validate movie data
      if (movie == null) {
        throw FavoritesServiceException('Invalid movie data');
      }
      
      if (movie['id'] == null) {
        throw FavoritesServiceException('Movie ID is required');
      }
      
      if (movie['title'] == null || movie['title'].toString().isEmpty) {
        throw FavoritesServiceException('Movie title is required');
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(movie['id'].toString())
          .set({
        'movieId': movie['id'],
        'title': movie['title'],
        'posterPath': movie['posterPath'],
        'poster': _getPosterUrl(movie['posterPath']),
        'description': movie['overview'] ?? '',
        'rating': movie['voteAverage'] ?? 0.0,
        'addedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      throw FavoritesServiceException(
        'Authentication error: ${e.message ?? "Unknown error"}',
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw FavoritesServiceException(
          'Permission denied. Please check your account.',
        );
      } else if (e.code == 'unavailable') {
        throw FavoritesServiceException(
          'Service unavailable. Please check your internet connection.',
        );
      }
      throw FavoritesServiceException(
        'Failed to add to favorites: ${e.message ?? "Unknown error"}',
      );
    } on FavoritesServiceException {
      rethrow;
    } catch (e) {
      throw FavoritesServiceException(
        'Unexpected error adding to favorites: ${e.toString()}',
      );
    }
  }

  // Remove movie from favorites
  Future<void> removeFromFavorites(dynamic movieId) async {
    try {
      final userId = _getCurrentUserId();
      
      if (movieId == null) {
        throw FavoritesServiceException('Movie ID is required');
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(movieId.toString())
          .delete();
    } on FirebaseAuthException catch (e) {
      throw FavoritesServiceException(
        'Authentication error: ${e.message ?? "Unknown error"}',
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw FavoritesServiceException(
          'Permission denied. Please check your account.',
        );
      } else if (e.code == 'unavailable') {
        throw FavoritesServiceException(
          'Service unavailable. Please check your internet connection.',
        );
      }
      throw FavoritesServiceException(
        'Failed to remove from favorites: ${e.message ?? "Unknown error"}',
      );
    } on FavoritesServiceException {
      rethrow;
    } catch (e) {
      throw FavoritesServiceException(
        'Unexpected error removing from favorites: ${e.toString()}',
      );
    }
  }

  // Check if movie is in favorites
  Future<bool> isFavorite(dynamic movieId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;
      
      if (movieId == null) return false;

      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(movieId.toString())
          .get();

      return doc.exists;
    } on FirebaseException catch (e) {
      // Silently fail for check operations
      print('Error checking favorite status: ${e.message}');
      return false;
    } catch (e) {
      print('Error checking favorite status: $e');
      return false;
    }
  }

  // Get all favorites
  Future<List<dynamic>> getFavorites() async {
    try {
      final userId = _getCurrentUserId();

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .orderBy('addedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        try {
          final data = doc.data();
          final posterUrl = data.containsKey('poster') && data['poster'] != null
              ? data['poster']
              : _getPosterUrl(data['posterPath']);
          
          return {
            'id': data['movieId'] ?? 0,
            'title': data['title'] ?? 'Unknown',
            'posterPath': data['posterPath'],
            'poster': posterUrl,
            'description': data['description'] ?? '',
            'rating': data['rating'] ?? 0.0,
          };
        } catch (e) {
          print('Error parsing favorite: $e');
          // Return a placeholder for corrupted data
          return {
            'id': 0,
            'title': 'Error loading movie',
            'posterPath': null,
            'poster': '',
            'description': '',
            'rating': 0.0,
          };
        }
      }).toList();
    } on FirebaseAuthException catch (e) {
      throw FavoritesServiceException(
        'Authentication error: ${e.message ?? "Unknown error"}',
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw FavoritesServiceException(
          'Permission denied. Please check your account.',
        );
      } else if (e.code == 'unavailable') {
        throw FavoritesServiceException(
          'Service unavailable. Please check your internet connection.',
        );
      }
      throw FavoritesServiceException(
        'Failed to fetch favorites: ${e.message ?? "Unknown error"}',
      );
    } on FavoritesServiceException {
      rethrow;
    } catch (e) {
      throw FavoritesServiceException(
        'Unexpected error fetching favorites: ${e.toString()}',
      );
    }
  }

  // Get favorites as a stream for real-time updates
  Stream<List<dynamic>> getFavoritesStream() {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return Stream.value([]);
      }

      return _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .orderBy('addedAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              try {
                final data = doc.data();
                final posterUrl = data.containsKey('poster') && data['poster'] != null
                    ? data['poster']
                    : _getPosterUrl(data['posterPath']);
                
                return {
                  'id': data['movieId'] ?? 0,
                  'title': data['title'] ?? 'Unknown',
                  'posterPath': data['posterPath'],
                  'poster': posterUrl,
                  'description': data['description'] ?? '',
                  'rating': data['rating'] ?? 0.0,
                };
              } catch (e) {
                print('Error parsing favorite in stream: $e');
                return {
                  'id': 0,
                  'title': 'Error loading movie',
                  'posterPath': null,
                  'poster': '',
                  'description': '',
                  'rating': 0.0,
                };
              }
            }).toList();
          })
          .handleError((error) {
            print('Stream error: $error');
            return <dynamic>[];
          });
    } catch (e) {
      print('Error creating favorites stream: $e');
      return Stream.value([]);
    }
  }

  // Get count of favorites
  Future<int> getFavoritesCount() async {
    try {
      final userId = _getCurrentUserId();

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting favorites count: $e');
      return 0;
    }
  }
}