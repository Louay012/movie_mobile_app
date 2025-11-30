// lib/screens/loading_screen.dart
import 'package:flutter/material.dart';
import 'signup.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    // Fade-in animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    // Navigate after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SignUpScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF141414), Color(0xFF000000)],
          ),
        ),
        child: FadeTransition(
          opacity: _fade,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Film Reel + Clapper Icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.4),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromARGB(
                          255,
                          190,
                          26,
                          235,
                        ).withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.movie_filter,
                    size: 80,
                    color: const Color.fromARGB(255, 210, 31, 233),
                  ),
                ),

                const SizedBox(height: 32),

                // App Name with Glow
                Text(
                  'MovieFlix',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        color: const Color.fromARGB(
                          255,
                          163,
                          24,
                          222,
                        ).withOpacity(0.6),
                        blurRadius: 15,
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Tagline
                Text(
                  'Your cinema, anywhere',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade400,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 50),

                // Smooth Progress Bar
                SizedBox(
                  width: 200,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 5,
                      backgroundColor: Colors.grey.shade800,
                      valueColor: AlwaysStoppedAnimation(Colors.amber.shade600),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Loading text
                Text(
                  'Loading...',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
