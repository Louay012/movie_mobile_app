import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoritesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _getPosterUrl(String? posterPath) {
    if (posterPath == null || posterPath.isEmpty) return '';
    if (posterPath.startsWith('http')) return posterPath;
    return 'https://image.tmdb.org/t/p/w500$posterPath';
  }

  // Add movie to favorites - accept dynamic movie data
  Future<void> addToFavorites(dynamic movie) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

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
        'description': movie['overview'],
        'rating': movie['voteAverage'] ?? 0.0,
        'addedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to add to favorites: $e');
    }
  }

  Future<void> removeFromFavorites(dynamic movieId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(movieId.toString())
          .delete();
    } catch (e) {
      throw Exception('Failed to remove from favorites: $e');
    }
  }

  // Check if movie is in favorites
  Future<bool> isFavorite(dynamic movieId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(movieId.toString())
          .get();

      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Get all favorites - return as dynamic map
  Future<List<dynamic>> getFavorites() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .orderBy('addedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            final posterUrl = data.containsKey('poster') && data['poster'] != null
                ? data['poster']
                : _getPosterUrl(data['posterPath']);
            return {
              'id': data['movieId'],
              'title': data['title'],
              'posterPath': data['posterPath'],
              'poster': posterUrl,
              'description': data['description'],
              'rating': data['rating'],
            };
          })
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch favorites: $e');
    }
  }

  Stream<List<dynamic>> getFavoritesStream() {
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
        .map((snapshot) => snapshot.docs
            .map((doc) {
              final data = doc.data();
              final posterUrl = data.containsKey('poster') && data['poster'] != null
                  ? data['poster']
                  : _getPosterUrl(data['posterPath']);
              return {
                'id': data['movieId'],
                'title': data['title'],
                'posterPath': data['posterPath'],
                'poster': posterUrl,
                'description': data['description'],
                'rating': data['rating'],
              };
            })
            .toList());
  }
}
