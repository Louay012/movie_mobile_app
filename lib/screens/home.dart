import 'dart:async';
import 'package:flutter/material.dart';
// removed direct http usage — using MovieService instead
import 'movie_details.dart';
import '../services/movie_service.dart';

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
    // Support both the custom API shape and TMDB v3 shape (from MovieService)
    final rawId = json['id'] ?? json['movieId'] ?? json['tmdb_id'];
    final id = rawId is int ? rawId : int.tryParse('$rawId') ?? 0;

    final title =
        (json['title'] ??
                json['name'] ??
                json['original_title'] ??
                json['movie_title'] ??
                '')
            .toString();

    // description / overview
    final description = (json['description'] ?? json['overview'])?.toString();

    // year from 'year' or from TMDB 'release_date'
    int? year;
    if (json['year'] is int) {
      year = json['year'] as int;
    } else if (json['release_date'] != null) {
      final date = json['release_date'].toString();
      if (date.length >= 4) {
        year = int.tryParse(date.substring(0, 4));
      }
    }

    final runningTime =
        json['runningTime']?.toString() ?? json['runtime']?.toString();

    // genre: either list of names or list of ids (we keep names if provided)
    List<String>? genre;
    if (json['genre'] is List) {
      genre = List<String>.from(json['genre'].map((e) => e.toString()));
    } else if (json['genres'] is List) {
      // TMDB sometimes returns list of objects [{id,name},...]
      final gs = json['genres'] as List;
      genre = gs.map((g) {
        if (g is Map && g['name'] != null) return g['name'].toString();
        return g.toString();
      }).toList();
    }

    // poster: prefer full url, otherwise TMDB poster_path
    String? poster;
    if (json['poster'] != null) {
      poster = json['poster'].toString();
    } else if (json['poster_path'] != null) {
      poster = json['poster_path'].toString();
    } else if (json['posterUrl'] != null) {
      poster = json['posterUrl'].toString();
    } else if (json['backdrop_path'] != null) {
      poster = json['backdrop_path'].toString();
    }

    final slug = json['slug']?.toString();

    return Movie(
      id: id,
      title: title.isNotEmpty ? title : 'Untitled',
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
    // assume TMDB path if not a full URL
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

  final MovieService _movieService = MovieService(); // use movie service

  @override
  void initState() {
    super.initState();
    _favoritesService = FavoritesService();
    _moviesFuture = fetchMovies();
    _searchCtrl.addListener(_onSearchChanged);
    _loadFavorites();
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
    if (_allMovies == null) {
      _filtered = [];
      return;
    }
    if (_query.isEmpty) {
      _filtered = List.from(_allMovies!);
    } else {
      _filtered = _allMovies!
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
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _moviesFuture = fetchMovies();
      _allMovies = null;
    });
    final list = await _moviesFuture;
    if (mounted) {
      setState(() {
        _allMovies = list;
        _applyFilter();
      });
    }
  }

  // replaced direct HTTP call with MovieService.getPopularMovies()
  Future<List<Movie>> fetchMovies() async {
    try {
      final raw = await _movieService
          .getPopularMovies(); // List<dynamic> from TMDB
      final movies = raw
          .map((e) => Movie.fromJson(e as Map<String, dynamic>))
          .toList();

      _allMovies = movies;
      _applyFilter();
      return movies;
    } catch (e) {
      throw Exception('Failed to load movies from MovieService: $e');
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
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      _allMovies == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError && _allMovies == null) {
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

                  final moviesToShow = (_allMovies == null || _query.isNotEmpty)
                      ? _filtered
                      : _allMovies!;

                  if (moviesToShow.isEmpty) {
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
                    padding: const EdgeInsets.all(16),
                    itemCount: moviesToShow.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.65,
                        ),
                    itemBuilder: (context, index) {
                      final movie = moviesToShow[index];
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
