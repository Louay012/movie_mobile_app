import 'dart:async';
import 'package:flutter/material.dart';
import '../services/favorites_service.dart';
import '../services/movie_service.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import 'movie_details.dart';
import 'favorites.dart';
import 'package:url_launcher/url_launcher.dart';

class Movie {
  final dynamic id;
  final String title;
  final String posterUrl;
  final double rating;
  final String overview;
  final List<int> genreIds;
  final String releaseDate;
  final bool isCustom;
  final int? runtime;
  final int? budget;
  final int? revenue;
  final String? tagline;
  final List<String>? productions;
  final String? trailerUrl;

  double get voteAverage => rating;

  Movie({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.rating,
    required this.overview,
    required this.genreIds,
    required this.releaseDate,
    this.isCustom = false,
    this.runtime,
    this.budget,
    this.revenue,
    this.tagline,
    this.productions,
    this.trailerUrl,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['movieId'] ?? json['tmdb_id'];
    final id = rawId is int ? rawId : (int.tryParse('$rawId') ?? rawId);

    final title =
        (json['title'] ?? json['name'] ?? json['original_title'] ?? 'Untitled')
            .toString();

    String posterUrl = '';
    final posterPath = json['poster_path']?.toString();
    final poster = json['poster']?.toString();
    final posterUrlField = json['posterUrl']?.toString();

    if (posterUrlField != null && posterUrlField.isNotEmpty) {
      posterUrl = posterUrlField;
    } else if (poster != null && poster.isNotEmpty) {
      if (poster.startsWith('http')) {
        posterUrl = poster;
      } else {
        posterUrl = 'https://image.tmdb.org/t/p/w500$poster';
      }
    } else if (posterPath != null && posterPath.isNotEmpty) {
      if (posterPath.startsWith('http')) {
        posterUrl = posterPath;
      } else {
        posterUrl = 'https://image.tmdb.org/t/p/w500$posterPath';
      }
    }

    final overview =
        json['description']?.toString() ?? json['overview']?.toString() ?? '';
    final releaseDate =
        json['release_date']?.toString() ??
        json['releaseDate']?.toString() ??
        '';

    double rating = 0.0;
    if (json['vote_average'] != null) {
      rating = json['vote_average'] is double
          ? json['vote_average']
          : double.tryParse(json['vote_average'].toString()) ?? 0.0;
    } else if (json['voteAverage'] != null) {
      rating = json['voteAverage'] is double
          ? json['voteAverage']
          : double.tryParse(json['voteAverage'].toString()) ?? 0.0;
    } else if (json['rating'] != null) {
      rating = json['rating'] is double
          ? json['rating']
          : double.tryParse(json['rating'].toString()) ?? 0.0;
    }

    final genreIds = (json['genre_ids'] is List)
        ? List<int>.from(
            (json['genre_ids'] as List).map(
              (e) => e is int ? e : int.tryParse(e.toString()) ?? 0,
            ),
          )
        : (json['genreIds'] is List
              ? List<int>.from(
                  (json['genreIds'] as List).map(
                    (e) => e is int ? e : int.tryParse(e.toString()) ?? 0,
                  ),
                )
              : <int>[]);
    final isCustom = json['isCustom'] == true;

    final runtime = json['runtime'] is int
        ? json['runtime']
        : int.tryParse(json['runtime']?.toString() ?? '');
    final budget = json['budget'] is int
        ? json['budget']
        : int.tryParse(json['budget']?.toString() ?? '');
    final revenue = json['revenue'] is int
        ? json['revenue']
        : int.tryParse(json['revenue']?.toString() ?? '');
    final tagline = json['tagline']?.toString();
    final productions = json['productions'] is List
        ? List<String>.from(json['productions'].map((e) => e.toString()))
        : null;
    final trailerUrl =
        json['trailerUrl']?.toString() ??
        json['trailer_url']?.toString() ??
        json['trailer']?.toString();

    return Movie(
      id: id,
      title: title,
      posterUrl: posterUrl,
      overview: overview,
      releaseDate: releaseDate,
      rating: rating,
      genreIds: genreIds,
      isCustom: isCustom,
      runtime: runtime,
      budget: budget,
      revenue: revenue,
      tagline: tagline,
      productions: productions,
      trailerUrl: trailerUrl,
    );
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
  final AdminService _adminService = AdminService();
  final AuthService _authService = AuthService();
  Set<String> _favoriteIds = {};

  final ScrollController _scrollCtrl = ScrollController();
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int currentPage = 1;
  String? _errorMessage;
  final Map<dynamic, String> _trailerCache = {};

  @override
  void initState() {
    super.initState();
    _favoritesService = FavoritesService();
    _searchCtrl.addListener(_onSearchChanged);
    _moviesFuture = _fetchMoviesWithErrorHandling();
    _loadFavorites();

    _scrollCtrl.addListener(() {
      if (!_isLoadingMore &&
          _hasMore &&
          _scrollCtrl.position.pixels >=
              _scrollCtrl.position.maxScrollExtent - 300) {
        _loadMoreMovies();
      }
    });
  }

  Future<void> _loadFavorites() async {
    try {
      final favorites = await _favoritesService.getFavorites();
      if (mounted) {
        setState(() {
          _favoriteIds = favorites.map((m) => m['id'].toString()).toSet();
        });
      }
    } catch (e) {
      debugPrint('Error loading favorites: $e');
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
                m.overview.toLowerCase().contains(_query) ||
                m.genreIds
                    .map((id) => id.toString())
                    .join(' ')
                    .toLowerCase()
                    .contains(_query),
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
    setState(() {
      _hasMore = true;
      _isLoadingMore = false;
      currentPage = 1;
      _allMovies = null;
      _errorMessage = null;
      _moviesFuture = _fetchMoviesWithErrorHandling();
    });
  }

  Future<List<Movie>> _fetchMoviesWithErrorHandling() async {
    try {
      List<Movie> customMovies = [];
      try {
        final customMoviesData = await _adminService.getCustomMovies();
        customMovies = customMoviesData
            .map((e) => Movie.fromJson({...e, 'isCustom': true}))
            .toList();
      } catch (e) {
        debugPrint('Error loading custom movies: $e');
      }

      final rawPage = await _movieService.getPopularMovies(currentPage);
      final tmdbMovies = rawPage
          .map((e) => Movie.fromJson(e as Map<String, dynamic>))
          .toList();

      final movies = [...customMovies, ...tmdbMovies];

      currentPage = 2;
      _allMovies = movies;
      _applyFilter();

      if (rawPage.length < 20) _hasMore = false;

      return movies;
    } catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e);
      });
      throw Exception(_errorMessage);
    }
  }

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
    } else if (errorStr.contains('500') ||
        errorStr.contains('502') ||
        errorStr.contains('503')) {
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

  Future<String?> _getTrailerUrl(Movie movie) async {
    if (movie.isCustom) {
      return movie.trailerUrl;
    }

    // Check cache first
    if (_trailerCache.containsKey(movie.id)) {
      return _trailerCache[movie.id];
    }

    try {
      final movieIdInt = int.tryParse(movie.id.toString());
      if (movieIdInt == null) {
        return null;
      }
      final trailerKey = await _movieService.getMovieTrailer(movieIdInt);
      if (trailerKey != null) {
        final url = 'https://www.youtube.com/watch?v=$trailerKey';
        _trailerCache[movie.id] = url;
        return url;
      }
    } catch (e) {
      // Ignore errors
    }
    return null;
  }

  Widget _buildMovieGrid(List<Movie> movies) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 900
            ? 5
            : MediaQuery.of(context).size.width > 600
            ? 4
            : 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final movie = movies[index];
        final isFavorite = _favoriteIds.contains(movie.id.toString());
        return MovieCard(
          movie: movie,
          isFavorite: isFavorite,
          getTrailerUrl: _getTrailerUrl,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MovieDetailsPage(movie: movie),
              ),
            ).then((_) {
              _loadFavorites();
            });
          },
          onFavoriteToggle: () => _toggleFavorite(movie),
        );
      }, childCount: movies.length),
    );
  }

  void _toggleFavorite(Movie movie) async {
    try {
      if (_favoriteIds.contains(movie.id.toString())) {
        await _favoritesService.removeFromFavorites(movie.id);
        _showSuccessSnackBar('Removed from favorites');
      } else {
        await _favoritesService.addToFavorites(
          _convertMovieToMovieModel(movie),
        );
        _showSuccessSnackBar('Added to favorites');
      }
      _loadFavorites();
    } catch (e) {
      debugPrint('Favorite toggle error: $e');
      _showErrorSnackBar('Failed to update favorites. Please try again.');
    }
  }

  dynamic _convertMovieToMovieModel(Movie movie) {
    return {
      'id': movie.id,
      'title': movie.title,
      'posterUrl': movie.posterUrl,
      'overview': movie.overview,
      'releaseDate': movie.releaseDate,
      'rating': movie.rating,
      'isCustom': movie.isCustom,
      'trailerUrl': movie.trailerUrl,
      'runtime': movie.runtime,
      'budget': movie.budget,
      'revenue': movie.revenue,
      'tagline': movie.tagline,
      'productions': movie.productions,
    };
  }

  void _navigateToFavorites() async {
    final shouldRefresh = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => FavoritesScreen()),
    );
    if (shouldRefresh == true && mounted) {
      _loadFavorites();
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
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
            icon: const Icon(Icons.people),
            color: Colors.deepPurpleAccent,
            tooltip: 'Find Matches',
            onPressed: () {
              Navigator.pushNamed(context, '/matching');
            },
          ),
          IconButton(
            icon: const Icon(Icons.favorite),
            color: Colors.red,
            onPressed: _navigateToFavorites,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.person),
            color: Colors.grey.shade900,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'profile') {
                Navigator.pushNamed(context, '/profile');
              } else if (value == 'signout') {
                _signOut();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      color: Colors.deepPurpleAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Profile',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'signout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red.shade400, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Sign Out',
                      style: TextStyle(color: Colors.red.shade400),
                    ),
                  ],
                ),
              ),
            ],
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

          if (_errorMessage != null &&
              _allMovies != null &&
              _allMovies!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red.shade900.withOpacity(0.3),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: Colors.deepPurpleAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
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
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      (_allMovies == null || _allMovies!.isEmpty)) {
                    return const Center(child: CircularProgressIndicator());
                  }

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

                  return CustomScrollView(
                    controller: _scrollCtrl,
                    slivers: [
                      _buildMovieGrid(source),
                      if (_isLoadingMore)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MovieCard extends StatefulWidget {
  final Movie movie;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final Future<String?> Function(Movie) getTrailerUrl;

  const MovieCard({
    super.key,
    required this.movie,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteToggle,
    required this.getTrailerUrl,
  });

  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  bool _isHovered = false;
  bool _isTrailerHovered = false;
  String? _trailerUrl;
  bool _isLoadingTrailer = false;
  bool _trailerLoaded = false; // Track if trailer fetch completed

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
          _trailerLoaded = true; // Mark as loaded
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
    final showTrailerButton =
        _isHovered && (_isLoadingTrailer || hasTrailer || !_trailerLoaded);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
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
                    child: Container(color: Colors.black.withOpacity(0.7)),
                  ),
                ),
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
                          color: Colors.deepPurpleAccent,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _isTrailerHovered
                                ? Colors.purple.shade700
                                : Colors.deepPurpleAccent,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepPurpleAccent.withOpacity(
                                  _isTrailerHovered ? 0.6 : 0.4,
                                ),
                                blurRadius: _isTrailerHovered ? 16 : 12,
                                spreadRadius: _isTrailerHovered ? 3 : 2,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_circle_filled,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Watch Trailer',
                                style: TextStyle(
                                  color: Colors.white,
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
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          widget.movie.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        if (widget.movie.isCustom)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.deepPurpleAccent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: widget.onFavoriteToggle,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: widget.isFavorite ? Colors.red : Colors.white,
                      size: 20,
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
