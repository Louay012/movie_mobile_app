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
      
      if (movie == null) {
        throw FavoritesServiceException('Invalid movie data');
      }
      
      if (movie['id'] == null) {
        throw FavoritesServiceException('Movie ID is required');
      }
      
      if (movie['title'] == null || movie['title'].toString().isEmpty) {
        throw FavoritesServiceException('Movie title is required');
      }

      final movieIdStr = movie['id'].toString();
      
      // Resolve poster URL
      String posterUrl = '';
      if (movie['posterUrl'] != null && movie['posterUrl'].toString().isNotEmpty) {
        posterUrl = movie['posterUrl'].toString();
      } else if (movie['poster'] != null && movie['poster'].toString().isNotEmpty) {
        posterUrl = movie['poster'].toString();
      } else {
        posterUrl = _getPosterUrl(movie['posterPath']?.toString());
      }

      // Store only canonical field names - no duplicates
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(movieIdStr)
          .set({
        'id': movieIdStr,
        'title': movie['title'],
        'posterUrl': posterUrl,
        'overview': movie['overview'] ?? movie['description'] ?? '',
        'rating': (movie['rating'] ?? movie['voteAverage'] ?? movie['vote_average'] ?? 0.0).toDouble(),
        'releaseDate': movie['releaseDate'] ?? movie['release_date'] ?? '',
        'isCustom': movie['isCustom'] == true,
        'trailerUrl': movie['trailerUrl'] ?? '',
        'runtime': movie['runtime'],
        'budget': movie['budget'],
        'revenue': movie['revenue'],
        'tagline': movie['tagline'],
        'productions': movie['productions'],
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
          
          // Resolve poster URL from various possible field names
          String posterUrl = '';
          if (data['posterUrl'] != null && data['posterUrl'].toString().isNotEmpty) {
            posterUrl = data['posterUrl'].toString();
          } else if (data['poster'] != null && data['poster'].toString().isNotEmpty) {
            posterUrl = data['poster'].toString();
          } else {
            posterUrl = _getPosterUrl(data['posterPath']?.toString());
          }
          
          return {
            'id': data['id'] ?? doc.id,
            'title': data['title'] ?? 'Unknown',
            'posterUrl': posterUrl,
            'overview': data['overview'] ?? data['description'] ?? '',
            'rating': (data['rating'] ?? data['vote_average'] ?? data['voteAverage'] ?? 0.0).toDouble(),
            'releaseDate': data['releaseDate'] ?? data['release_date'] ?? '',
            'isCustom': data['isCustom'] ?? false,
            'trailerUrl': data['trailerUrl'] ?? '',
            'runtime': data['runtime'],
            'budget': data['budget'],
            'revenue': data['revenue'],
            'tagline': data['tagline'],
            'productions': data['productions'],
          };
        } catch (e) {
          print('Error parsing favorite: $e');
          return {
            'id': doc.id,
            'title': 'Error loading movie',
            'posterUrl': '',
            'overview': '',
            'rating': 0.0,
            'isCustom': false,
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
                
                String posterUrl = '';
                if (data['posterUrl'] != null && data['posterUrl'].toString().isNotEmpty) {
                  posterUrl = data['posterUrl'].toString();
                } else if (data['poster'] != null && data['poster'].toString().isNotEmpty) {
                  posterUrl = data['poster'].toString();
                } else {
                  posterUrl = _getPosterUrl(data['posterPath']?.toString());
                }
                
                return {
                  'id': data['id'] ?? doc.id,
                  'title': data['title'] ?? 'Unknown',
                  'posterUrl': posterUrl,
                  'overview': data['overview'] ?? data['description'] ?? '',
                  'rating': (data['rating'] ?? data['vote_average'] ?? data['voteAverage'] ?? 0.0).toDouble(),
                  'releaseDate': data['releaseDate'] ?? data['release_date'] ?? '',
                  'isCustom': data['isCustom'] ?? false,
                  'trailerUrl': data['trailerUrl'] ?? '',
                  'runtime': data['runtime'],
                  'budget': data['budget'],
                  'revenue': data['revenue'],
                  'tagline': data['tagline'],
                  'productions': data['productions'],
                };
              } catch (e) {
                print('Error parsing favorite in stream: $e');
                return {
                  'id': doc.id,
                  'title': 'Error loading movie',
                  'posterUrl': '',
                  'overview': '',
                  'rating': 0.0,
                  'isCustom': false,
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
