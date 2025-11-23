import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/favorites_service.dart';
import 'movie_details.dart';

const String MOVIES_API_URL = 'https://www.api.andrespecht.dev/v1/movies';

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

    final description = json['description']?.toString();
    final year = json['year'] is int
        ? json['year'] as int
        : int.tryParse('${json['year']}');
    final runningTime = json['runningTime']?.toString();
    final genre = (json['genre'] is List)
        ? List<String>.from(json['genre'])
        : null;
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
  Set<int> _favoriteIds = {};

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

  Future<List<Movie>> fetchMovies() async {
    final uri = Uri.parse(MOVIES_API_URL);
    debugPrint('Requesting movies: $uri');

    try {
      final res = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      debugPrint('Status: ${res.statusCode}');
      debugPrint('Body: ${res.body}');

      if (res.statusCode != 200) {
        throw Exception(
          'Failed to load movies: ${res.statusCode} — ${res.body}',
        );
      }

      final body = json.decode(res.body);

      List<dynamic> items;
      if (body is Map<String, dynamic> && body['movies'] is List) {
        items = body['movies'] as List<dynamic>;
      } else if (body is List) {
        items = body;
      } else if (body is Map<String, dynamic> && body['response'] is List) {
        items = body['response'] as List<dynamic>;
      } else if (body is Map<String, dynamic> && body['results'] is List) {
        items = body['results'] as List<dynamic>;
      } else {
        final firstList = body is Map<String, dynamic>
            ? body.values.firstWhere((v) => v is List, orElse: () => null)
            : null;
        if (firstList is List) {
          items = firstList;
        } else {
          throw Exception('Unexpected response shape from movies API');
        }
      }

      final movies = items
          .map((e) => Movie.fromJson(e as Map<String, dynamic>))
          .toList();
      _allMovies = movies;
      _applyFilter();
      return movies;
    } on SocketException catch (e) {
      throw Exception('Network error: $e');
    } on TimeoutException catch (e) {
      throw Exception('Request timed out: $e');
    } on FormatException catch (e) {
      throw Exception('Invalid JSON: $e');
    } catch (e) {
      throw Exception('Fetch error: $e');
    }
  }

  int _getColumnCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 1400) {
      return 5; // Large screens: 5 columns
    } else if (screenWidth >= 900) {
      return 4; // Medium-large screens: 4 columns
    } else if (screenWidth >= 600) {
      return 3; // Medium screens: 3 columns
    } else {
      return 2; // Small screens: 2 columns
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
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _getColumnCount(context),
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      childAspectRatio: 0.6,
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
                                                  return const Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  );
                                                },
                                            errorBuilder: (context, _, __) {
                                              return Container(
                                                color: Colors.grey[800],
                                              );
                                            },
                                          ),
                                        )
                                      : Container(color: Colors.grey[800]),
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
                                          } else {
                                            await _favoritesService
                                                .addToFavorites(
                                              _convertMovieToMovieModel(movie),
                                            );
                                          }
                                          _loadFavorites();
                                        } catch (e) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                            ),
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
