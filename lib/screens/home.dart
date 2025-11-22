import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _auth = AuthService();

  final List<Map<String, String>> _movies = [
    {
      'title': 'Inception',
      'poster':
          'https://image.tmdb.org/t/p/w500/9gk7adHYeDMPS6QyJQsQJ0O5w9K.jpg',
    },
    {
      'title': 'The Dark Knight',
      'poster':
          'https://image.tmdb.org/t/p/w500/qJ2tW6WMUDux911r6m7haI0xvwi.jpg',
    },
    {
      'title': 'Interstellar',
      'poster':
          'https://image.tmdb.org/t/p/w500/gEU2QniE6E77NI6lCu244mCjIqT.jpg',
    },
    {
      'title': 'The Matrix',
      'poster':
          'https://image.tmdb.org/t/p/w500/viq2RY2YyEL9zIccEr9W23i2Rio.jpg',
    },
    {
      'title': 'Pulp Fiction',
      'poster':
          'https://image.tmdb.org/t/p/w500/dM2w06cJ0h361synchronized.jpg',
    },
    {
      'title': 'Forrest Gump',
      'poster':
          'https://image.tmdb.org/t/p/w500/clnyhPqj1SNgpAdeSS6margin.jpg',
    },
    {
      'title': 'Fight Club',
      'poster':
          'https://image.tmdb.org/t/p/w500/pB8BM7pdSp6B6Eg7SZlJ01IIl51.jpg',
    },
    {
      'title': 'Goodfellas',
      'poster':
          'https://image.tmdb.org/t/p/w500/sd62HjCoAQMB870eI8kxyD54idW.jpg',
    },
  ];

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _auth.signOut().then((_) {
                Navigator.pushReplacementNamed(context, '/login');
              });
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MovieFlix'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.7,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _movies.length,
          itemBuilder: (context, index) {
            final movie = _movies[index];
            return MovieCard(
              title: movie['title']!,
              posterUrl: movie['poster']!,
            );
          },
        ),
      ),
    );
  }
}

class MovieCard extends StatelessWidget {
  final String title;
  final String posterUrl;

  const MovieCard({
    required this.title,
    required this.posterUrl,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tapped: $title')),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Image.network(
                posterUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade800,
                    child: const Icon(Icons.movie_creation_outlined),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
