import 'dart:async';
import 'package:flutter/material.dart';
import '../services/favorites_service.dart';
import '../services/movie_service.dart';
import 'movie_details.dart';
import 'package:url_launcher/url_launcher.dart';

class Movie {
  final int id;
  final String title;
  final String? posterPath;
  final String? description;
  final int? year;
  final String? runningTime;
  final List<String>? genre;
  final String? slug;
  final double? rating;

  Movie({
    required this.id,
    required this.title,
    this.posterPath,
    this.description,
    this.year,
    this.runningTime,
    this.genre,
    this.slug,
    this.rating,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['movieId'] ?? json['tmdb_id'];
    final id = rawId is int ? rawId : int.tryParse('$rawId') ?? 0;

    final title =
        (json['title'] ?? json['name'] ?? json['original_title'] ?? 'Untitled')
            .toString();

    String? poster;
    if (json['poster'] != null) {
      poster = json['poster'].toString();
    } else if (json['poster_path'] != null) {
      poster = json['poster_path'].toString();
    } else if (json['posterUrl'] != null) {
      poster = json['posterUrl'].toString();
    }

    final description =
        json['description']?.toString() ?? json['overview']?.toString();
    final year = json['year'] is int
        ? json['year'] as int
        : (json['release_date'] != null &&
                  json['release_date'].toString().length >= 4
              ? int.tryParse(json['release_date'].toString().substring(0, 4))
              : int.tryParse('${json['year']}'));
    final runningTime =
        json['runningTime']?.toString() ?? json['runtime']?.toString();
    final genre = (json['genre'] is List)
        ? List<String>.from(json['genre'].map((e) => e.toString()))
        : (json['genres'] is List
              ? List<String>.from(
                  (json['genres'] as List).map(
                    (g) => g is Map && g['name'] != null
                        ? g['name'].toString()
                        : g.toString(),
                  ),
                )
              : null);
    final slug = json['slug']?.toString();
    
    final rating = json['vote_average'] != null 
        ? (json['vote_average'] is double 
            ? json['vote_average'] 
            : double.tryParse(json['vote_average'].toString()))
        : null;

    return Movie(
      id: id,
      title: title,
      posterPath: poster,
      description: description,
      year: year,
      runningTime: runningTime,
      genre: genre,
      slug: slug,
      rating: rating,
    );
  }

  String get posterUrl {
    if (posterPath == null || posterPath!.isEmpty) return '';
    final p = posterPath!;
    if (p.startsWith('http')) return p;
    return 'https://image.tmdb.org/t/p/w500$p';
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Movie>> _moviesFuture;
  List<Movie>? _allMovies;
  List<Movie> _filtered = [];
  String _query = '';
  final _searchCtrl = TextEditingController();
  late FavoritesService _favoritesService;
  final MovieService _movieService = MovieService();
  Set<int> _favoriteIds = {};

  // infinite scroll fields
  final ScrollController _scrollCtrl = ScrollController();
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int currentPage = 1;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _favoritesService = FavoritesService();
    _searchCtrl.addListener(_onSearchChanged);
    _moviesFuture = _fetchMoviesWithErrorHandling(); // loads page 1
    _loadFavorites();

    _scrollCtrl.addListener(() {
      if (!_isLoadingMore &&
          _hasMore &&
          _scrollCtrl.position.pixels >=
              _scrollCtrl.position.maxScrollExtent - 300) {
        // near the bottom -> load more
        _loadMoreMovies();
      }
    });
  }

  Future<void> _loadFavorites() async {
    try {
      final favorites = await _favoritesService.getFavorites();
      if (mounted) {
        setState(() {
          _favoriteIds = favorites.map((m) => m['id'] as int).toSet();
        });
      }
    } catch (e) {
      debugPrint('Error loading favorites: $e');
      // Don't show error to user for favorites, just log it
    }
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (_query == q) return;
    setState(() {
      _query = q;
      _applyFilter();
    });
  }

  void _applyFilter() {
    final source = _allMovies ?? [];
    if (_query.isEmpty) {
      _filtered = List.from(source);
    } else {
      _filtered = source
          .where(
            (m) =>
                m.title.toLowerCase().contains(_query) ||
                (m.description ?? '').toLowerCase().contains(_query) ||
                (m.genre?.join(' ').toLowerCase() ?? '').contains(_query),
          )
          .toList();
    }
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    // reset pagination and reload page 1
    setState(() {
      _hasMore = true;
      _isLoadingMore = false;
      currentPage = 1;
      _allMovies = null;
      _errorMessage = null;
      _moviesFuture = _fetchMoviesWithErrorHandling();
    });
  }

  // Wrapper to handle errors properly
  Future<List<Movie>> _fetchMoviesWithErrorHandling() async {
    try {
      final rawPage = await _movieService.getPopularMovies(currentPage);
      final movies = rawPage
          .map((e) => Movie.fromJson(e as Map<String, dynamic>))
          .toList();
      
      // Set page for next load
      currentPage = 2;
      _allMovies = movies;
      _applyFilter();
      
      // If returned less than typical page size, mark hasMore false
      if (rawPage.length < 20) _hasMore = false;
      
      return movies;
    } catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e);
      });
      throw Exception(_errorMessage);
    }
  }

  // Load next page and append to _allMovies
  Future<void> _loadMoreMovies() async {
    if (_isLoadingMore || !_hasMore) return;
    
    setState(() {
      _isLoadingMore = true;
      _errorMessage = null;
    });

    try {
      final rawPage = await _movieService.getPopularMovies(currentPage);
      final nextMovies = rawPage
          .map((e) => Movie.fromJson(e as Map<String, dynamic>))
          .toList();

      if (nextMovies.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoadingMore = false;
        });
      } else {
        final list = List<Movie>.from(_allMovies ?? []);
        list.addAll(nextMovies);
        
        setState(() {
          _allMovies = list;
          _applyFilter();
          currentPage++;
          _isLoadingMore = false;
        });
        
        // If fewer than expected results, stop further loads
        if (nextMovies.length < 20) {
          setState(() => _hasMore = false);
        }
      }
    } catch (e) {
      debugPrint('Error loading more movies: $e');
      
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _errorMessage = _getErrorMessage(e);
        });
        
        _showErrorSnackBar('Could not load more movies. Please try again.');
      }
    }
  }

  // Centralized error message handler
  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('socketexception') || 
        errorStr.contains('network') ||
        errorStr.contains('connection')) {
      return 'No internet connection. Please check your network.';
    } else if (errorStr.contains('timeout')) {
      return 'Request timed out. Please try again.';
    } else if (errorStr.contains('format')) {
      return 'Unexpected data format received.';
    } else if (errorStr.contains('401') || errorStr.contains('unauthorized')) {
      return 'API authentication failed. Please contact support.';
    } else if (errorStr.contains('404')) {
      return 'Requested resource not found.';
    } else if (errorStr.contains('500') || errorStr.contains('502') || errorStr.contains('503')) {
      return 'Server error. Please try again later.';
    }
    
    return 'An unexpected error occurred. Please try again.';
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'RETRY',
          textColor: Colors.white,
          onPressed: () {
            if (_allMovies == null || _allMovies!.isEmpty) {
              _refresh();
            } else {
              _loadMoreMovies();
            }
          },
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  int _getColumnCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1400) return 6;
    if (width >= 1100) return 5;
    if (width >= 800) return 4;
    if (width >= 500) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Film Explorer'),
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            color: Colors.amber,
            tooltip: 'Find Matches',
            onPressed: () {
              Navigator.pushNamed(context, '/matching');
            },
          ),
          IconButton(
            icon: const Icon(Icons.favorite),
            color: Colors.red,
            onPressed: () {
              Navigator.pushNamed(context, '/favorites');
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search movies...',
                filled: true,
                fillColor: Colors.white10,
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () {
                          _searchCtrl.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          
          // Error banner if there's an error during pagination
          if (_errorMessage != null && _allMovies != null && _allMovies!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red.shade900.withOpacity(0.3),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadMoreMovies,
                    child: const Text('RETRY', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<Movie>>(
                future: _moviesFuture,
                builder: (context, snapshot) {
                  // While initial load is happening, show loader
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      (_allMovies == null || _allMovies!.isEmpty)) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Error state for initial load
                  if (snapshot.hasError &&
                      (_allMovies == null || _allMovies!.isEmpty)) {
                    return ListView(
                      children: [
                        const SizedBox(height: 60),
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              _errorMessage ?? 'Failed to load movies',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  // Use filtered list if searching, otherwise allMovies
                  final source = (_query.isNotEmpty)
                      ? _filtered
                      : (_allMovies ?? []);
                      
                  if (source.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 120),
                        const Icon(
                          Icons.movie_filter_outlined,
                          size: 64,
                          color: Colors.white30,
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            _query.isNotEmpty 
                                ? 'No movies found for "$_query"'
                                : 'No movies available',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return GridView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: source.length + (_isLoadingMore ? 1 : 0),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _getColumnCount(context),
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      childAspectRatio: 0.55,
                    ),
                    itemBuilder: (context, index) {
                      // Show loading indicator as last tile when loading more
                      if (index >= source.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      
                      final movie = source[index];
                      final isFavorite = _favoriteIds.contains(movie.id);

                      return MovieCard(
                        movie: movie,
                        isFavorite: isFavorite,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  MovieDetailsPage(movie: movie),
                            ),
                          ).then((_) {
                            _loadFavorites();
                          });
                        },
                        onFavoriteToggle: () async {
                          try {
                            if (isFavorite) {
                              await _favoritesService
                                  .removeFromFavorites(movie.id);
                              _showSuccessSnackBar('Removed from favorites');
                            } else {
                              await _favoritesService
                                  .addToFavorites(
                                _convertMovieToMovieModel(movie),
                              );
                              _showSuccessSnackBar('Added to favorites');
                            }
                            _loadFavorites();
                          } catch (e) {
                            debugPrint('Favorite toggle error: $e');
                            _showErrorSnackBar(
                              'Failed to update favorites. Please try again.'
                            );
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  dynamic _convertMovieToMovieModel(Movie movie) {
    return {
      'id': movie.id,
      'title': movie.title,
      'posterPath': movie.posterPath,
      'overview': movie.description,
      'releaseDate': movie.year?.toString() ?? '',
      'voteAverage': 0.0,
    };
  }
}

class MovieCard extends StatefulWidget {
  final Movie movie;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  const MovieCard({
    super.key,
    required this.movie,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  bool _isHovered = false;
  bool _isLoadingTrailer = false;

  Future<void> _watchTrailer() async {
    setState(() {
      _isLoadingTrailer = true;
    });

    try {
      final movieService = MovieService();
      final trailerKey = await movieService.getMovieTrailer(widget.movie.id);
      
      if (trailerKey != null) {
        final url = Uri.parse('https://www.youtube.com/watch?v=$trailerKey');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No trailer available for this movie'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load trailer'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTrailer = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()
            ..scale(_isHovered ? 1.08 : 1.0),
          transformAlignment: Alignment.center,
          child: Material(
            color: Colors.transparent,
            elevation: _isHovered ? 16 : 4,
            shadowColor: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: _isHovered
                      ? Border.all(color: Colors.amber, width: 2)
                      : null,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Movie Poster
                    widget.movie.posterUrl.isNotEmpty
                        ? Hero(
                            tag: 'poster-${widget.movie.id}',
                            child: Image.network(
                              widget.movie.posterUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  color: Colors.grey[800],
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[800],
                                  child: const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      color: Colors.white30,
                                      size: 40,
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        : Container(
                            color: Colors.grey[800],
                            child: const Center(
                              child: Icon(
                                Icons.movie,
                                color: Colors.white30,
                                size: 40,
                              ),
                            ),
                          ),

                    // Hover overlay with info
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _isHovered ? 1.0 : 0.0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.7),
                              Colors.black.withOpacity(0.9),
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Rating
                            if (widget.movie.rating != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getRatingColor(widget.movie.rating!),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.movie.rating!.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            
                            const SizedBox(height: 8),
                            
                            // Year
                            if (widget.movie.year != null)
                              Text(
                                '${widget.movie.year}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            
                            const SizedBox(height: 8),
                            
                            // Genres (max 2)
                            if (widget.movie.genre != null && 
                                widget.movie.genre!.isNotEmpty)
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 4,
                                runSpacing: 4,
                                children: widget.movie.genre!
                                    .take(2)
                                    .map((g) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.white30,
                                            ),
                                          ),
                                          child: Text(
                                            g,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ))
                                    .toList(),
                              ),
                            
                            const SizedBox(height: 12),
                            
                            // Trailer button
                            ElevatedButton.icon(
                              onPressed: _isLoadingTrailer ? null : _watchTrailer,
                              icon: _isLoadingTrailer
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Icon(Icons.play_arrow, size: 18),
                              label: Text(
                                _isLoadingTrailer ? 'Loading...' : 'Trailer',
                                style: const TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Title at bottom (always visible)
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _isHovered ? 0.0 : 1.0,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.8),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            widget.movie.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Favorite button
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: widget.onFavoriteToggle,
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
                          child: Icon(
                            widget.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: widget.isFavorite ? Colors.red : Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 8.0) return Colors.green;
    if (rating >= 6.0) return Colors.amber.shade700;
    if (rating >= 4.0) return Colors.orange;
    return Colors.red;
  }
}
