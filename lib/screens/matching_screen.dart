import 'package:flutter/material.dart';
import '../services/matching_service.dart';

class MatchingScreen extends StatefulWidget {
  const MatchingScreen({super.key});

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> {
  final MatchingService _matchingService = MatchingService();
  List<MatchedUser>? _matchedUsers;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final matches = await _matchingService.findMatchingUsers();
      setState(() {
        _matchedUsers = matches;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load matches: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Movie Matches'),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Colors.deepPurple.shade900.withOpacity(0.3),
              Colors.black,
            ],
          ),
        ),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.amber),
            SizedBox(height: 16),
            Text(
              'Finding your movie matches...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadMatches,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_matchedUsers == null || _matchedUsers!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 80,
                color: Colors.amber.withOpacity(0.5),
              ),
              const SizedBox(height: 24),
              const Text(
                'No Matches Found',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Add more movies to your favorites to find users with similar taste!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Matches require at least 75% common favorites.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.amber.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/home'),
                icon: const Icon(Icons.movie),
                label: const Text('Browse Movies'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMatches,
      color: Colors.amber,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _matchedUsers!.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                children: [
                  Icon(
                    Icons.favorite,
                    size: 40,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_matchedUsers!.length} Match${_matchedUsers!.length > 1 ? 'es' : ''} Found',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Users who share your movie taste',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            );
          }

          final match = _matchedUsers![index - 1];
          return _buildMatchCard(match);
        },
      ),
    );
  }

  Widget _buildMatchCard(MatchedUser match) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.amber.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // User info header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Profile picture
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.amber, Colors.orange.shade700],
                    ),
                    border: Border.all(color: Colors.amber, width: 2),
                  ),
                  child: ClipOval(
                    child: match.user.photoURL != null &&
                            match.user.photoURL!.isNotEmpty
                        ? Image.network(
                            match.user.photoURL!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                match.user.fullName.isNotEmpty
                                    ? match.user.fullName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              match.user.fullName.isNotEmpty
                                  ? match.user.fullName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                // User details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        match.user.fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${match.user.age} years old',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                // Match percentage badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _getMatchColors(match.matchPercentage),
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${match.matchPercentage.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'Match',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Common movies section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.movie,
                      size: 16,
                      color: Colors.amber.withOpacity(0.8),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${match.commonMovies.length} Common Favorite${match.commonMovies.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Common movies horizontal list
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: match.commonMovies.length,
                    itemBuilder: (context, index) {
                      final movie = match.commonMovies[index];
                      return Container(
                        width: 70,
                        margin: const EdgeInsets.only(right: 10),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                movie['poster'] ?? '',
                                width: 70,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 70,
                                  height: 80,
                                  color: Colors.grey.shade800,
                                  child: const Icon(
                                    Icons.movie,
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getMatchColors(double percentage) {
    if (percentage >= 90) {
      return [Colors.green, Colors.green.shade700];
    } else if (percentage >= 80) {
      return [Colors.amber, Colors.orange];
    } else {
      return [Colors.orange, Colors.deepOrange];
    }
  }
}
