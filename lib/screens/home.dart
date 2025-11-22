// ...existing code...
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String TMDB_API_KEY =
    'YOUR_TMDB_API_KEY'; // <-- replace with your TMDB key

class Movie {
  final int id;
  final String title;
  final String? posterPath;

  Movie({required this.id, required this.title, this.posterPath});

  factory Movie.fromJson(Map<String, dynamic> json) => Movie(
    id: json['id'] as int,
    title: (json['title'] ?? json['name']) as String,
    posterPath: json['poster_path'] as String?,
  );

  String get posterUrl =>
      posterPath != null ? 'https://image.tmdb.org/t/p/w500$posterPath' : '';
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Movie>> _moviesFuture;

  @override
  void initState() {
    super.initState();
    _moviesFuture = fetchPopularMovies();
  }

  Future<List<Movie>> fetchPopularMovies({int page = 1}) async {
    final uri = Uri.https('api.themoviedb.org', '/3/movie/popular', {
      'api_key': TMDB_API_KEY,
      'language': 'en-US',
      'page': '$page',
    });

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to load movies: ${res.statusCode}');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    final results = (data['results'] as List<dynamic>);
    return results
        .map((e) => Movie.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Film Explorer'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: FutureBuilder<List<Movie>>(
        future: _moviesFuture,
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
          final movies = snapshot.data ?? [];
          if (movies.isEmpty) {
            return const Center(
              child: Text(
                'No movies found',
                style: TextStyle(color: Colors.white),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: movies.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.65,
            ),
            itemBuilder: (context, index) {
              final movie = movies[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    movie.posterUrl.isNotEmpty
                        ? Image.network(
                            movie.posterUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                            errorBuilder: (context, _, __) {
                              return Container(color: Colors.grey);
                            },
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
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
// ...existing code...