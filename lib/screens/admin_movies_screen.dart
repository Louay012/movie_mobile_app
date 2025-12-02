import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/admin_service.dart';

class AdminMoviesScreen extends StatefulWidget {
  const AdminMoviesScreen({super.key});

  @override
  State<AdminMoviesScreen> createState() => _AdminMoviesScreenState();
}

class _AdminMoviesScreenState extends State<AdminMoviesScreen> {
  final AdminService _adminService = AdminService();

  void _showAddMovieDialog() {
    showDialog(context: context, builder: (context) => const _AddMovieDialog());
  }

  void _showEditMovieDialog(Map<String, dynamic> movie) {
    showDialog(
      context: context,
      builder: (context) => _AddMovieDialog(movie: movie),
    );
  }

  void _showMovieDetailsDialog(Map<String, dynamic> movie) {
    showDialog(
      context: context,
      builder: (context) => _MovieDetailsDialog(movie: movie),
    );
  }

  Future<void> _deleteMovie(String movieId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Movie',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "$title"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _adminService.deleteMovie(movieId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Movie deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Manage Movies'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Manage Users',
            onPressed: () => Navigator.pushNamed(context, '/admin/users'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMovieDialog,
        backgroundColor: Colors.deepPurpleAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Movie',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _adminService.getCustomMoviesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading movies',
                    style: TextStyle(color: Colors.grey[400], fontSize: 18),
                  ),
                ],
              ),
            );
          }

          final movies = snapshot.data ?? [];

          if (movies.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.movie_creation_outlined,
                    size: 80,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No custom movies yet',
                    style: TextStyle(color: Colors.grey[400], fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the + button to add a movie',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];
              final genres = (movie['genres'] as List?)?.join(', ') ?? '';

              return GestureDetector(
                onTap: () => _showMovieDetailsDialog(movie),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E1E1E), Color(0xFF252525)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Movie Poster
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                        child:
                            movie['poster'] != null &&
                                movie['poster'].isNotEmpty
                            ? Image.network(
                                movie['poster'],
                                width: 100,
                                height: 150,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 100,
                                  height: 150,
                                  color: Colors.grey[800],
                                  child: const Icon(
                                    Icons.movie,
                                    color: Colors.grey,
                                    size: 40,
                                  ),
                                ),
                              )
                            : Container(
                                width: 100,
                                height: 150,
                                color: Colors.grey[800],
                                child: const Icon(
                                  Icons.movie,
                                  color: Colors.grey,
                                  size: 40,
                                ),
                              ),
                      ),
                      // Movie Details
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                movie['title'] ?? 'Untitled',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.deepPurpleAccent,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${(movie['voteAverage'] ?? 0.0).toStringAsFixed(1)}',
                                    style: const TextStyle(
                                      color: Colors.deepPurpleAccent,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if (movie['releaseDate'] != null)
                                    Text(
                                      movie['releaseDate'],
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (genres.isNotEmpty)
                                Text(
                                  genres,
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    onPressed: () =>
                                        _showEditMovieDialog(movie),
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                    tooltip: 'Edit',
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () => _deleteMovie(
                                      movie['id'],
                                      movie['title'] ?? '',
                                    ),
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    tooltip: 'Delete',
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ],
                              ),
                            ],
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
    );
  }
}

class _MovieDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> movie;

  const _MovieDetailsDialog({required this.movie});

  String _formatNumber(dynamic number) {
    if (number == null) return 'N/A';
    final num = number is int ? number : int.tryParse(number.toString()) ?? 0;
    if (num >= 1000000000) {
      return '${(num / 1000000000).toStringAsFixed(1)}B';
    }
    if (num >= 1000000) {
      return '${(num / 1000000).toStringAsFixed(1)}M';
    }
    return num.toString();
  }

  @override
  Widget build(BuildContext context) {
    final genres = (movie['genres'] as List?)?.join(', ') ?? 'N/A';
    final productions = (movie['productions'] as List?)?.join(', ') ?? '';

    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with poster
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: movie['poster'] != null && movie['poster'].isNotEmpty
                      ? Image.network(
                          movie['poster'],
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: double.infinity,
                            height: 200,
                            color: Colors.grey[800],
                            child: const Icon(
                              Icons.movie,
                              color: Colors.grey,
                              size: 80,
                            ),
                          ),
                        )
                      : Container(
                          width: double.infinity,
                          height: 200,
                          color: Colors.grey[800],
                          child: const Icon(
                            Icons.movie,
                            color: Colors.grey,
                            size: 80,
                          ),
                        ),
                ),
                // Gradient overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, const Color(0xFF1E1E1E)],
                      ),
                    ),
                  ),
                ),
                // Close button
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                // Title
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Text(
                    movie['title'] ?? 'Untitled',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rating and Release Date
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurpleAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.deepPurpleAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${(movie['voteAverage'] ?? 0.0).toStringAsFixed(1)}',
                                style: const TextStyle(
                                  color: Colors.deepPurpleAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (movie['releaseDate'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  color: Colors.grey,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  movie['releaseDate'],
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (movie['runtime'] != null && movie['runtime'] > 0)
                      _buildInfoSection(
                        'Runtime',
                        '${movie['runtime']} minutes',
                      ),

                    // Tagline
                    if (movie['tagline'] != null &&
                        movie['tagline'].isNotEmpty) ...[
                      Text(
                        '"${movie['tagline']}"',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Genres
                    _buildInfoSection('Genres', genres),

                    // Overview
                    if (movie['overview'] != null &&
                        movie['overview'].isNotEmpty) ...[
                      const Text(
                        'Overview',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        movie['overview'],
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Budget & Revenue
                    if (movie['budget'] != null && movie['budget'] > 0)
                      _buildInfoSection(
                        'Budget',
                        '\$${_formatNumber(movie['budget'])}',
                      ),
                    if (movie['revenue'] != null && movie['revenue'] > 0)
                      _buildInfoSection(
                        'Revenue',
                        '\$${_formatNumber(movie['revenue'])}',
                      ),

                    if (productions.isNotEmpty)
                      _buildInfoSection('Production', productions),

                    // Trailer link
                    if (movie['trailerUrl'] != null &&
                        movie['trailerUrl'].isNotEmpty)
                      _buildInfoSection('Trailer', movie['trailerUrl']),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddMovieDialog extends StatefulWidget {
  final Map<String, dynamic>? movie;

  const _AddMovieDialog({this.movie});

  @override
  State<_AddMovieDialog> createState() => _AddMovieDialogState();
}

class _AddMovieDialogState extends State<_AddMovieDialog> {
  final _formKey = GlobalKey<FormState>();
  final AdminService _adminService = AdminService();

  late TextEditingController _titleController;
  late TextEditingController _overviewController;
  late TextEditingController _posterController;
  late TextEditingController _trailerController;
  late TextEditingController _ratingController;
  late TextEditingController _genresController;
  late TextEditingController _runtimeController;
  late TextEditingController _budgetController;
  late TextEditingController _revenueController;
  late TextEditingController _taglineController;
  late TextEditingController _productionsController;

  DateTime? _selectedReleaseDate;

  bool _isLoading = false;
  bool get _isEditing => widget.movie != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.movie?['title'] ?? '',
    );
    _overviewController = TextEditingController(
      text: widget.movie?['overview'] ?? '',
    );
    _posterController = TextEditingController(
      text: widget.movie?['poster'] ?? '',
    );
    _trailerController = TextEditingController(
      text: widget.movie?['trailerUrl'] ?? '',
    );
    _ratingController = TextEditingController(
      text: widget.movie?['voteAverage']?.toString() ?? '',
    );
    _genresController = TextEditingController(
      text: (widget.movie?['genres'] as List?)?.join(', ') ?? '',
    );
    _runtimeController = TextEditingController(
      text: widget.movie?['runtime']?.toString() ?? '',
    );
    _budgetController = TextEditingController(
      text: widget.movie?['budget']?.toString() ?? '',
    );
    _revenueController = TextEditingController(
      text: widget.movie?['revenue']?.toString() ?? '',
    );
    _taglineController = TextEditingController(
      text: widget.movie?['tagline'] ?? '',
    );
    _productionsController = TextEditingController(
      text: (widget.movie?['productions'] as List?)?.join(', ') ?? '',
    );

    if (widget.movie?['releaseDate'] != null) {
      try {
        _selectedReleaseDate = DateTime.parse(widget.movie!['releaseDate']);
      } catch (e) {
        // Try parsing different format
        final parts = widget.movie!['releaseDate'].toString().split('-');
        if (parts.length == 3) {
          _selectedReleaseDate = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _overviewController.dispose();
    _posterController.dispose();
    _trailerController.dispose();
    _ratingController.dispose();
    _genresController.dispose();
    _runtimeController.dispose();
    _budgetController.dispose();
    _revenueController.dispose();
    _taglineController.dispose();
    _productionsController.dispose();
    super.dispose();
  }

  Future<void> _selectReleaseDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedReleaseDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.deepPurpleAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1E1E1E),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedReleaseDate) {
      setState(() {
        _selectedReleaseDate = picked;
      });
    }
  }

  Future<void> _saveMovie() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedReleaseDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a release date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final genres = _genresController.text
          .split(',')
          .map((g) => g.trim())
          .where((g) => g.isNotEmpty)
          .toList();

      final productions = _productionsController.text
          .split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();

      final releaseDate =
          '${_selectedReleaseDate!.year}-${_selectedReleaseDate!.month.toString().padLeft(2, '0')}-${_selectedReleaseDate!.day.toString().padLeft(2, '0')}';

      if (_isEditing) {
        await _adminService.updateMovie(widget.movie!['id'], {
          'title': _titleController.text.trim(),
          'overview': _overviewController.text.trim(),
          'poster': _posterController.text.trim(),
          'posterPath': _posterController.text.trim(),
          'trailerUrl': _trailerController.text.trim(),
          'voteAverage': double.tryParse(_ratingController.text) ?? 0.0,
          'releaseDate': releaseDate,
          'genres': genres,
          'productions': productions,
          'runtime': int.tryParse(_runtimeController.text),
          'budget': int.tryParse(_budgetController.text),
          'revenue': int.tryParse(_revenueController.text),
          'tagline': _taglineController.text.trim(),
        });
      } else {
        await _adminService.addMovie(
          title: _titleController.text.trim(),
          overview: _overviewController.text.trim(),
          posterUrl: _posterController.text.trim(),
          trailerUrl: _trailerController.text.trim(),
          rating: double.tryParse(_ratingController.text) ?? 0.0,
          releaseDate: releaseDate,
          genres: genres,
          productions: productions,
          runtime: int.tryParse(_runtimeController.text),
          budget: int.tryParse(_budgetController.text),
          revenue: int.tryParse(_revenueController.text),
          tagline: _taglineController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Movie updated successfully'
                  : 'Movie added successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  Icon(
                    _isEditing ? Icons.edit : Icons.movie_creation,
                    color: Colors.deepPurpleAccent,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isEditing ? 'Edit Movie' : 'Add New Movie',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        controller: _titleController,
                        label: 'Title *',
                        hint: 'Enter movie title',
                        validator: (v) =>
                            v?.isEmpty ?? true ? 'Title is required' : null,
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _overviewController,
                        label: 'Overview *',
                        hint: 'Enter movie description',
                        maxLines: 3,
                        validator: (v) =>
                            v?.isEmpty ?? true ? 'Overview is required' : null,
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _posterController,
                        label: 'Poster URL *',
                        hint: 'https://example.com/poster.jpg',
                        validator: (v) => v?.isEmpty ?? true
                            ? 'Poster URL is required'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _trailerController,
                        label: 'Trailer URL',
                        hint: 'https://youtube.com/watch?v=...',
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _ratingController,
                              label: 'Rating (0-10) *',
                              hint: '8.5',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*'),
                                ),
                              ],
                              validator: (v) {
                                if (v?.isEmpty ?? true)
                                  return 'Rating is required';
                                final rating = double.tryParse(v!);
                                if (rating == null) return 'Invalid number';
                                if (rating < 0 || rating > 10)
                                  return 'Must be 0-10';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Release Date *',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: _selectReleaseDate,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _selectedReleaseDate != null
                                                ? '${_selectedReleaseDate!.year}-${_selectedReleaseDate!.month.toString().padLeft(2, '0')}-${_selectedReleaseDate!.day.toString().padLeft(2, '0')}'
                                                : 'Select date',
                                            style: TextStyle(
                                              color:
                                                  _selectedReleaseDate != null
                                                  ? Colors.white
                                                  : Colors.grey,
                                            ),
                                          ),
                                        ),
                                        const Icon(
                                          Icons.calendar_today,
                                          color: Colors.deepPurpleAccent,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _genresController,
                        label: 'Genres (comma separated)',
                        hint: 'Action, Drama, Sci-Fi',
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _productionsController,
                        label: 'Production Companies (comma separated)',
                        hint: 'Warner Bros, Paramount, Universal',
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _taglineController,
                        label: 'Tagline',
                        hint: 'Enter movie tagline',
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _runtimeController,
                              label: 'Runtime (minutes)',
                              hint: '120',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _budgetController,
                              label: 'Budget (\$)',
                              hint: '150000000',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        controller: _revenueController,
                        label: 'Revenue (\$)',
                        hint: '500000000',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveMovie,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isEditing ? 'Update' : 'Add Movie'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.deepPurpleAccent),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }
}
