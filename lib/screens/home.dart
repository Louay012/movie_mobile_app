// ...existing code...
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/favorites_service.dart';
import '../services/movie_service.dart';
import 'movie_details.dart';

class Movie {
  final int id;
  final String title;
  final String? posterPath;
  final String? description;
  final int? year;
  final String? runningTime;
  final List<String>? genre;
  final String? slug;

  Movie({
    required this.id,
    required this.title,
    this.posterPath,
    this.description,
    this.year,
    this.runningTime,
    this.genre,
    this.slug,
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

    return Movie(
      id: id,
      title: title,
      posterPath: poster,
      description: description,
      year: year,
      runningTime: runningTime,
      genre: genre,
      slug: slug,
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Film Explorer'),
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
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
                      childAspectRatio: 0.6,
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

                      return GestureDetector(
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
                        child: Material(
                          color: Colors.transparent,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  movie.posterUrl.isNotEmpty
                                      ? Hero(
                                          tag: 'poster-${movie.id}',
                                          child: Image.network(
                                            movie.posterUrl,
                                            fit: BoxFit.cover,
                                            loadingBuilder:
                                                (context, child, progress) {
                                              if (progress == null)
                                                return child;
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
                                              debugPrint('Image load error: $error');
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
                                  Align(
                                    alignment: Alignment.bottomLeft,
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
                                        movie.title,
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
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () async {
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
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.5),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        padding: const EdgeInsets.all(8),
                                        child: Icon(
                                          isFavorite
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: isFavorite
                                              ? Colors.red
                                              : Colors.white,
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
// ...existing code...
