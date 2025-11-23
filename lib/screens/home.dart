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

  @override
  void initState() {
    super.initState();
    _favoritesService = FavoritesService();
    _searchCtrl.addListener(_onSearchChanged);
    _moviesFuture = fetchMovies(); // loads page 1
    _loadFavorites();

    _scrollCtrl.addListener(() {
      if (!_isLoadingMore &&
          _hasMore &&
          _scrollCtrl.position.pixels >=
              _scrollCtrl.position.maxScrollExtent - 300) {
        // near the bottom -> load more
        loadMore();
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
      _moviesFuture = fetchMovies();
    });
    final list = await _moviesFuture;
    if (mounted) {
      setState(() {
        _allMovies = list;
        _applyFilter();
      });
    }
  }

  // fetch page 1 (used on initial load / refresh)
  Future<List<Movie>> fetchMovies() async {
    try {
      final rawPage = await _movie_service_getPopular(currentPage);
      final movies = rawPage
          .map((e) => Movie.fromJson(e as Map<String, dynamic>))
          .toList();
      // set page for next load
      currentPage = 2;
      _allMovies = movies;
      _applyFilter();
      // if returned less than typical page size, mark hasMore false
      if (rawPage.length < 20) _hasMore = false;
      return movies;
    } catch (e) {
      throw Exception('Failed to load movies from MovieService: $e');
    }
  }

  // helper to call movie service correctly (returns List<dynamic>)
  Future<List<dynamic>> _movie_service_getPopular(int page) {
    return _movie_service_call(page);
  }

  Future<List<dynamic>> _movie_service_call(int page) async {
    return await _movie_service_get(page);
  }

  // actual call to MovieService.getPopularMovies(page)
  Future<List<dynamic>> _movie_service_get(int page) async {
    return await _movieService.getPopularMovies(page);
  }

  // load next page and append to _allMovies
  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final raw = await _movie_service_getPopular(currentPage);
      final nextMovies = raw
          .map((e) => Movie.fromJson(e as Map<String, dynamic>))
          .toList();

      if (nextMovies.isEmpty) {
        _hasMore = false;
      } else {
        final list = List<Movie>.from(_allMovies ?? []);
        list.addAll(nextMovies);
        setState(() {
          _allMovies = list;
          _applyFilter();
          currentPage++;
        });
        // if fewer than expected results, stop further loads (TMDB default page size 20)
        if (nextMovies.length < 20) _hasMore = false;
      }
    } catch (e) {
      debugPrint('Error loading more movies: $e');
      // optionally show snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load more movies: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Film Explorer'),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            color: Colors.red,
            onPressed: () {
              Navigator.pushNamed(context, '/favorites');
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
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<Movie>>(
                future: _moviesFuture,
                builder: (context, snapshot) {
                  // while initial load is happening, show loader
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      (_allMovies == null || _allMovies!.isEmpty)) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError &&
                      (_allMovies == null || _allMovies!.isEmpty)) {
                    return ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              'Error loading movies:\n${snapshot.error}',
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: ElevatedButton(
                            onPressed: _refresh,
                            child: const Text('Retry'),
                          ),
                        ),
                      ],
                    );
                  }

                  // use filtered list if searching, otherwise allMovies
                  final source = (_query.isNotEmpty)
                      ? _filtered
                      : (_allMovies ?? []);
                  if (source.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Text(
                            'No movies found',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    );
                  }

                  return GridView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: source.length + (_isLoadingMore ? 1 : 0),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.65,
                        ),
                    itemBuilder: (context, index) {
                      // show loading indicator as last tile when loading more
                      if (index >= source.length) {
                        return const Center(child: CircularProgressIndicator());
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
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
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
                                              return const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              );
                                            },
                                        errorBuilder: (context, _, __) {
                                          return Container(color: Colors.grey);
                                        },
                                      ),
                                    )
                                  : Container(color: Colors.grey),
                              Align(
                                alignment: Alignment.bottomLeft,
                                child: Container(
                                  width: double.infinity,
                                  color: Colors.black54,
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    movie.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white),
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
                                      } else {
                                        await _favoritesService.addToFavorites(
                                          _convertMovieToMovieModel(movie),
                                        );
                                      }
                                      _loadFavorites();
                                    } catch (e) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text('Error: $e')),
                                      );
                                    }
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(
                                      isFavorite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: isFavorite
                                          ? Colors.red
                                          : Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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