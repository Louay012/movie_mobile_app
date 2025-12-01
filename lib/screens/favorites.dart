import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/favorites_service.dart';
import '../services/movie_service.dart';
import 'movie_details.dart';
import 'home.dart';
import 'dart:convert';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late FavoritesService _favoritesService;
  final MovieService _movieService = MovieService();

  int _getColumnCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 1400) {
      return 5;
    } else if (screenWidth >= 900) {
      return 4;
    } else if (screenWidth >= 600) {
      return 3;
    } else {
      return 2;
    }
  }

  @override
  void initState() {
    super.initState();
    _favoritesService = FavoritesService();
  }

  Future<String?> _getTrailerUrl(Movie movie) async {
    if (movie.trailerUrl != null && movie.trailerUrl!.isNotEmpty) {
      return movie.trailerUrl;
    }
    // For TMDB movies, fetch trailer from API
    final movieId = int.tryParse(movie.id.toString());
    if (movieId != null && !movie.isCustom) {
      return await _movieService.getMovieTrailer(movieId);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Favorites'),
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: StreamBuilder<List<dynamic>>(
        stream: _favoritesService.getFavoritesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          final favorites = snapshot.data ?? [];

          if (favorites.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: Colors.white30,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No favorites yet',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add movies to your favorites to see them here',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: favorites.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _getColumnCount(context),
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              childAspectRatio: 0.6,
            ),
            itemBuilder: (context, index) {
              final favorite = favorites[index];
              final movie = Movie(
                id: favorite['id'] ?? favorite['movieId'] ?? '',
                title: favorite['title'] ?? 'Untitled',
                posterUrl: favorite['posterUrl'] ?? favorite['poster'] ?? '',
                rating: (favorite['rating'] ?? favorite['vote_average'] ?? 0.0).toDouble(),
                overview: favorite['overview'] ?? favorite['description'] ?? '',
                genreIds: <int>[],
                releaseDate: favorite['releaseDate'] ?? favorite['release_date'] ?? '',
                isCustom: favorite['isCustom'] == true,
                runtime: favorite['runtime'] is int ? favorite['runtime'] : int.tryParse(favorite['runtime']?.toString() ?? ''),
                budget: favorite['budget'] is int ? favorite['budget'] : int.tryParse(favorite['budget']?.toString() ?? ''),
                revenue: favorite['revenue'] is int ? favorite['revenue'] : int.tryParse(favorite['revenue']?.toString() ?? ''),
                tagline: favorite['tagline']?.toString(),
                productions: favorite['productions'] is List 
                    ? List<String>.from(favorite['productions'].map((e) => e.toString()))
                    : null,
                trailerUrl: favorite['trailerUrl']?.toString(),
              );

              return FavoriteMovieCard(
                movie: movie,
                getTrailerUrl: _getTrailerUrl,
                onRemove: () async {
                  try {
                    await _favoritesService.removeFromFavorites(movie.id.toString());
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class FavoriteMovieCard extends StatefulWidget {
  final Movie movie;
  final Future<String?> Function(Movie) getTrailerUrl;
  final VoidCallback onRemove;

  const FavoriteMovieCard({
    super.key,
    required this.movie,
    required this.getTrailerUrl,
    required this.onRemove,
  });

  @override
  State<FavoriteMovieCard> createState() => _FavoriteMovieCardState();
}

class _FavoriteMovieCardState extends State<FavoriteMovieCard> {
  bool _isHovered = false;
  bool _isTrailerHovered = false;
  String? _trailerUrl;
  bool _isLoadingTrailer = false;
  bool _trailerLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadTrailer();
  }

  Future<void> _loadTrailer() async {
    setState(() => _isLoadingTrailer = true);
    try {
      final url = await widget.getTrailerUrl(widget.movie);
      if (mounted) {
        setState(() {
          _trailerUrl = url;
          _isLoadingTrailer = false;
          _trailerLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTrailer = false;
          _trailerLoaded = true;
        });
      }
    }
  }

  Future<void> _launchTrailer() async {
    if (_trailerUrl != null && _trailerUrl!.isNotEmpty) {
      final uri = Uri.tryParse(_trailerUrl!);
      if (uri != null) {
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (e) {
          try {
            await launchUrl(uri, mode: LaunchMode.platformDefault);
          } catch (_) {}
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTrailer = _trailerUrl != null && _trailerUrl!.isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MovieDetailsPage(movie: widget.movie),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()..scale(_isHovered ? 1.02 : 1.0),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: widget.movie.posterUrl.isNotEmpty
                    ? Image.network(
                        widget.movie.posterUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[800],
                            child: const Icon(
                              Icons.movie,
                              color: Colors.grey,
                              size: 50,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.movie,
                          color: Colors.grey,
                          size: 50,
                        ),
                      ),
              ),
              if (_isHovered)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: Colors.black.withOpacity(0.7),
                    ),
                  ),
                ),
              // Bottom gradient
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.9),
                      ],
                    ),
                  ),
                ),
              ),
              // Loading indicator
              if (_isHovered && _isLoadingTrailer && !_trailerLoaded)
                Positioned.fill(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_isHovered && hasTrailer && _trailerLoaded)
                Positioned.fill(
                  child: Center(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) => setState(() => _isTrailerHovered = true),
                      onExit: (_) => setState(() => _isTrailerHovered = false),
                      child: GestureDetector(
                        onTap: _launchTrailer,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: _isTrailerHovered ? Colors.amber.shade600 : Colors.amber,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(_isTrailerHovered ? 0.6 : 0.4),
                                blurRadius: _isTrailerHovered ? 16 : 12,
                                spreadRadius: _isTrailerHovered ? 3 : 2,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_circle_filled, color: Colors.black, size: 20),
                              SizedBox(width: 6),
                              Text(
                                'Watch Trailer',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Movie title and rating at bottom
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.movie.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.movie.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Favorite button (always red since it's in favorites)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: widget.onRemove,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

  