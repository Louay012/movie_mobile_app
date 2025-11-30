import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class MatchedUser {
  final UserModel user;
  final double matchPercentage;
  final List<Map<String, dynamic>> commonMovies;

  MatchedUser({
    required this.user,
    required this.matchPercentage,
    required this.commonMovies,
  });
}

class MatchingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user's favorites movie IDs
  Future<Set<int>> _getCurrentUserFavorites() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return {};

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .get();

    return snapshot.docs.map((doc) => doc.data()['movieId'] as int).toSet();
  }

  // Get a user's favorites
  Future<List<Map<String, dynamic>>> _getUserFavorites(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': data['movieId'] ?? 0,
        'title': data['title'] ?? 'Unknown',
        'poster': data['poster'] ?? '',
        'posterPath': data['posterPath'],
      };
    }).toList();
  }

  // Find users with matching preferences (>= 75% match) - SYMMETRIC VERSION
  Future<List<MatchedUser>> findMatchingUsers() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return [];

    // Get current user's favorites
    final currentUserFavorites = await _getCurrentUserFavorites();
    if (currentUserFavorites.isEmpty) return [];

    // Get all users
    final usersSnapshot = await _firestore.collection('users').get();

    List<MatchedUser> matchedUsers = [];

    for (final userDoc in usersSnapshot.docs) {
      // Skip current user
      if (userDoc.id == currentUserId) continue;

      // Get this user's favorites
      final userFavorites = await _getUserFavorites(userDoc.id);
      final userFavoriteIds = userFavorites.map((m) => m['id'] as int).toSet();

      if (userFavoriteIds.isEmpty) continue;

      // Calculate match percentage (SYMMETRIC: based on union of both users' favorites)
      final commonMovieIds = currentUserFavorites.intersection(userFavoriteIds);
      final totalUniqueMovies = currentUserFavorites
          .union(userFavoriteIds)
          .length;

      // Jaccard similarity: intersection / union
      final matchPercentage = (commonMovieIds.length / totalUniqueMovies) * 100;

      // Only include users with >= 75% match
      if (matchPercentage >= 75) {
        final userData = userDoc.data();
        final user = UserModel.fromJson(userData, userDoc.id);

        // Get common movies details
        final commonMovies = userFavorites
            .where((m) => commonMovieIds.contains(m['id']))
            .toList();

        matchedUsers.add(
          MatchedUser(
            user: user,
            matchPercentage: matchPercentage,
            commonMovies: commonMovies,
          ),
        );
      }
    }

    // Sort by match percentage (highest first)
    matchedUsers.sort((a, b) => b.matchPercentage.compareTo(a.matchPercentage));

    return matchedUsers;
  }
}
