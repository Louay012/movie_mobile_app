import 'package:flutter/material.dart';
import '../services/favorites_service.dart';
import 'home.dart';

class MovieDetailsPage extends StatefulWidget {
  final Movie movie;
  const MovieDetailsPage({super.key, required this.movie});

  @override
  State<MovieDetailsPage> createState() => _MovieDetailsPageState();
}

class _MovieDetailsPageState extends State<MovieDetailsPage> {
  late FavoritesService _favoritesService;
  bool _isFavorite = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _favoritesService = FavoritesService();
    _checkIfFavorite();
  }

  Future<void> _checkIfFavorite() async {
    try {
      final isFav = await _favoritesService.isFavorite(widget.movie.id);
      if (mounted) {
        setState(() {
          _isFavorite = isFav;
        });
      }
    } catch (e) {
      debugPrint('Error checking favorite: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      if (_isFavorite) {
        await _favoritesService.removeFromFavorites(widget.movie.id);
      } else {
        await _favoritesService.addToFavorites(
          _convertMovieToMovieModel(),
        );
      }
      
      if (mounted) {
        setState(() {
          _isFavorite = !_isFavorite;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFavorite ? 'Added to favorites' : 'Removed from favorites',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.movie.title),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorite ? Colors.red : Colors.white,
                        size: 28,
                      ),
                      onPressed: _toggleFavorite,
                    ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.movie.posterUrl.isNotEmpty)
            Hero(
              tag: 'poster-${widget.movie.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  widget.movie.posterUrl,
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
            widget.movie.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (widget.movie.year != null)
                Text(
                  '${widget.movie.year}',
                  style: const TextStyle(color: Colors.white70),
                ),
              if (widget.movie.runningTime != null) ...[
                const SizedBox(width: 12),
                Text(
                  widget.movie.runningTime!,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (widget.movie.genre != null && widget.movie.genre!.isNotEmpty)
            Wrap(
              spacing: 8,
              children: widget.movie.genre!
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
          if (widget.movie.description != null)
            Text(
              widget.movie.description!,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
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

  dynamic _convertMovieToMovieModel() {
    return {
      'id': widget.movie.id,
      'title': widget.movie.title,
      'posterPath': widget.movie.posterPath,
      'overview': widget.movie.description,
      'releaseDate': widget.movie.year?.toString() ?? '',
      'voteAverage': 0.0,
    };
  }
}
