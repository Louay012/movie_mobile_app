import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/favorites_service.dart';
import '../services/movie_service.dart';
import 'home.dart';

class MovieDetailsPage extends StatefulWidget {
  final Movie movie;
  const MovieDetailsPage({super.key, required this.movie});

  @override
  State<MovieDetailsPage> createState() => _MovieDetailsPageState();
}

class _MovieDetailsPageState extends State<MovieDetailsPage> {
  late FavoritesService _favoritesService;
  late MovieService _movieService;
  bool _isFavorite = false;
  bool _isLoading = false;
  bool _isLoadingDetails = true;
  bool _isLoadingTrailer = false;
  Map<String, dynamic>? _movieDetails;

  @override
  void initState() {
    super.initState();
    _favoritesService = FavoritesService();
    _movieService = MovieService();
    _checkIfFavorite();
    _loadMovieDetails();
  }

  Future<void> _loadMovieDetails() async {
    if (widget.movie.isCustom) {
      setState(() {
        _isLoadingDetails = false;
      });
      return;
    }

    try {
      final movieId = widget.movie.id is int
          ? widget.movie.id
          : int.tryParse(widget.movie.id.toString());

      if (movieId == null) {
        setState(() => _isLoadingDetails = false);
        return;
      }

      final details = await _movieService.getMovieDetails(movieId);
      if (mounted) {
        setState(() {
          _movieDetails = details;
          _isLoadingDetails = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
        });
      }
    }
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
        await _favoritesService.addToFavorites(_convertMovieToMovieModel());
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

  Future<void> _watchTrailer() async {
    // For custom movies, use the trailerUrl directly
    if (widget.movie.isCustom) {
      final trailerUrl = widget.movie.trailerUrl;
      if (trailerUrl != null && trailerUrl.isNotEmpty) {
        final uri = Uri.tryParse(trailerUrl);
        if (uri != null) {
          try {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return;
          } catch (e) {
            try {
              await launchUrl(uri, mode: LaunchMode.platformDefault);
              return;
            } catch (_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open trailer')),
                );
              }
              return;
            }
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No trailer available')));
      }
      return;
    }

    // For TMDB movies, fetch trailer from API
    setState(() {
      _isLoadingTrailer = true;
    });

    try {
      final movieId = widget.movie.id is int
          ? widget.movie.id
          : int.tryParse(widget.movie.id.toString());

      if (movieId == null) {
        throw Exception('Invalid movie ID');
      }

      final trailerKey = await _movieService.getMovieTrailer(movieId);

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

  String _formatRuntime(int? minutes) {
    if (minutes == null) return '';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  String _formatBudget(int? budget) {
    if (budget == null || budget == 0) return 'N/A';
    if (budget >= 1000000000) {
      return '\$${(budget / 1000000000).toStringAsFixed(1)}B';
    }
    if (budget >= 1000000) {
      return '\$${(budget / 1000000).toStringAsFixed(1)}M';
    }
    return '\$${budget.toString()}';
  }

  String? _getYear() {
    final releaseDate = widget.movie.releaseDate;
    if (releaseDate.isNotEmpty && releaseDate.length >= 4) {
      return releaseDate.substring(0, 4);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isCustomMovie = widget.movie.isCustom;

    final rating = isCustomMovie
        ? widget.movie.rating
        : (_movieDetails?['vote_average'] ?? widget.movie.rating);
    final voteCount = isCustomMovie ? null : _movieDetails?['vote_count'];
    final runtime = isCustomMovie
        ? widget.movie.runtime
        : _movieDetails?['runtime'];
    final budget = isCustomMovie
        ? widget.movie.budget
        : _movieDetails?['budget'];
    final revenue = isCustomMovie
        ? widget.movie.revenue
        : _movieDetails?['revenue'];
    final tagline = isCustomMovie
        ? widget.movie.tagline
        : _movieDetails?['tagline'];
    final status = isCustomMovie ? 'Released' : _movieDetails?['status'];
    final originalLanguage = _movieDetails?['original_language']
        ?.toString()
        .toUpperCase();

    final year = _getYear();

    List<Map<String, dynamic>>? productionCompanies;
    if (isCustomMovie && widget.movie.productions != null) {
      productionCompanies = widget.movie.productions!
          .map((p) => <String, dynamic>{'name': p})
          .toList();
    } else if (_movieDetails?['production_companies'] != null) {
      final rawList = _movieDetails!['production_companies'] as List;
      productionCompanies = rawList
          .map((p) => Map<String, dynamic>.from(p as Map))
          .toList();
    }

    List<Map<String, dynamic>>? genres;
    if (_movieDetails?['genres'] != null) {
      final rawList = _movieDetails!['genres'] as List;
      genres = rawList.map((g) => Map<String, dynamic>.from(g as Map)).toList();
    } else if (isCustomMovie && widget.movie.productions != null) {
      // For custom movies without genre data, we don't show genres section
      genres = null;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // App Bar with poster background
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            backgroundColor: Colors.black,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.movie.posterUrl.isNotEmpty)
                    Hero(
                      tag: 'poster-${widget.movie.id}',
                      child: Image.network(
                        widget.movie.posterUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, _, __) =>
                            Container(color: Colors.grey[900]),
                      ),
                    ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                          Colors.black,
                        ],
                        stops: const [0.3, 0.7, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _isLoading
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
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
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    widget.movie.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  // Tagline
                  if (tagline != null && tagline.toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '"$tagline"',
                      style: TextStyle(
                        color: Colors.deepPurpleAccent,
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Rating, Year, Runtime row
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Rating
                      if (rating != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getRatingColor((rating as num).toDouble()),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${(rating as num).toStringAsFixed(1)}${voteCount != null ? " ($voteCount)" : ""}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (year != null)
                        _buildInfoChip(Icons.calendar_today, year),

                      // Runtime
                      if (runtime != null && runtime is int && runtime > 0)
                        _buildInfoChip(
                          Icons.access_time,
                          _formatRuntime(runtime),
                        ),

                      // Status
                      if (status != null)
                        _buildInfoChip(Icons.info_outline, status.toString()),

                      // Language
                      if (!isCustomMovie && originalLanguage != null)
                        _buildInfoChip(Icons.language, originalLanguage),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Watch Trailer Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoadingTrailer ? null : _watchTrailer,
                      icon: _isLoadingTrailer
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.play_circle_filled, size: 24),
                      label: Text(
                        _isLoadingTrailer
                            ? 'Loading Trailer...'
                            : 'Watch Trailer',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurpleAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Genres
                  if (genres != null && genres.isNotEmpty) ...[
                    const Text(
                      'Genres',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: genres
                          .map<Widget>(
                            (g) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.deepPurpleAccent,
                                    Colors.purple.shade700,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                g['name']?.toString() ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Overview/Description
                  const Text(
                    'Overview',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    (_movieDetails?['overview']?.toString()) ??
                        (widget.movie.overview.isNotEmpty
                            ? widget.movie.overview
                            : 'No description available.'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),

                  // Budget & Revenue
                  if ((budget != null && budget is int && budget > 0) ||
                      (revenue != null && revenue is int && revenue > 0)) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Box Office',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (budget != null && budget is int && budget > 0)
                          Expanded(
                            child: _buildStatCard(
                              'Budget',
                              _formatBudget(budget),
                              Icons.account_balance_wallet,
                            ),
                          ),
                        if (budget != null &&
                            budget is int &&
                            budget > 0 &&
                            revenue != null &&
                            revenue is int &&
                            revenue > 0)
                          const SizedBox(width: 12),
                        if (revenue != null && revenue is int && revenue > 0)
                          Expanded(
                            child: _buildStatCard(
                              'Revenue',
                              _formatBudget(revenue),
                              Icons.trending_up,
                            ),
                          ),
                      ],
                    ),
                  ],

                  // Production Companies
                  if (productionCompanies != null &&
                      productionCompanies.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Production',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: productionCompanies
                          .map<Widget>(
                            (p) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                p['name']?.toString() ?? '',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 7.0) return Colors.green.shade700;
    if (rating >= 5.0) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.deepPurpleAccent,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _convertMovieToMovieModel() {
    return {
      'id': widget.movie.id,
      'title': widget.movie.title,
      'posterUrl': widget.movie.posterUrl,
      'overview': widget.movie.overview,
      'releaseDate': widget.movie.releaseDate,
      'rating': widget.movie.rating,
      'isCustom': widget.movie.isCustom,
      'trailerUrl': widget.movie.trailerUrl,
      'runtime': widget.movie.runtime,
      'budget': widget.movie.budget,
      'revenue': widget.movie.revenue,
      'tagline': widget.movie.tagline,
      'productions': widget.movie.productions,
    };
  }
}
