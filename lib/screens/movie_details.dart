import 'package:flutter/material.dart';
import 'home.dart'; // for Movie model

class MovieDetailsPage extends StatelessWidget {
  final Movie movie;
  const MovieDetailsPage({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(movie.title),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (movie.posterUrl.isNotEmpty)
            Hero(
              tag: 'poster-${movie.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  movie.posterUrl,
                  height: 420,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, __) =>
                      Container(height: 420, color: Colors.grey),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            movie.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (movie.year != null)
                Text(
                  '${movie.year}',
                  style: const TextStyle(color: Colors.white70),
                ),
              if (movie.runningTime != null) ...[
                const SizedBox(width: 12),
                Text(
                  movie.runningTime!,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (movie.genre != null && movie.genre!.isNotEmpty)
            Wrap(
              spacing: 8,
              children: movie.genre!
                  .map(
                    (g) => Chip(
                      label: Text(g),
                      backgroundColor: Colors.white10,
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 12),
          if (movie.description != null)
            Text(
              movie.description!,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // example action: go back
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
          ),
        ],
      ),
    );
  }
}
