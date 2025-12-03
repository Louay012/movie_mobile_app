import 'package:flutter/material.dart';

class MovieFlixLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool animated;

  const MovieFlixLogo({
    super.key,
    this.size = 80,
    this.showText = true,
    this.animated = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo Icon
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.25),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.deepPurpleAccent,
                Colors.purple.shade700,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurpleAccent.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Film reel background effect
              Positioned(
                top: size * 0.1,
                left: size * 0.1,
                child: Icon(
                  Icons.circle_outlined,
                  size: size * 0.25,
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
              Positioned(
                bottom: size * 0.1,
                right: size * 0.1,
                child: Icon(
                  Icons.circle_outlined,
                  size: size * 0.25,
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
              // Main icon - stylized "M" with play button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'M',
                    style: TextStyle(
                      fontSize: size * 0.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -2,
                      height: 1,
                    ),
                  ),
                  Icon(
                    Icons.play_arrow_rounded,
                    size: size * 0.35,
                    color: Colors.white,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showText) ...[
          SizedBox(height: size * 0.25),
          // App Name with gradient effect
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                Colors.deepPurpleAccent,
                Colors.purpleAccent.shade100,
              ],
            ).createShader(bounds),
            child: Text(
              'MovieFlix',
              style: TextStyle(
                fontSize: size * 0.45,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// Animated version of the logo for splash screens
class AnimatedMovieFlixLogo extends StatefulWidget {
  final double size;
  final bool showText;
  final VoidCallback? onAnimationComplete;

  const AnimatedMovieFlixLogo({
    super.key,
    this.size = 80,
    this.showText = true,
    this.onAnimationComplete,
  });

  @override
  State<AnimatedMovieFlixLogo> createState() => _AnimatedMovieFlixLogoState();
}

class _AnimatedMovieFlixLogoState extends State<AnimatedMovieFlixLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _controller.forward().then((_) {
      widget.onAnimationComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: MovieFlixLogo(
              size: widget.size,
              showText: widget.showText,
            ),
          ),
        );
      },
    );
  }
}
