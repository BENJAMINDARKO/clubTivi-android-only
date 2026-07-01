import 'dart:ui';
import 'package:flutter/material.dart';

class BackdropLayer extends StatelessWidget {
  final String? imageUrl;
  final bool animate;

  const BackdropLayer({
    super.key,
    required this.imageUrl,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      image = Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.topCenter,
        errorBuilder: (_, __, ___) => const SizedBox.expand(),
      );
    } else {
      image = const SizedBox.expand();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (animate)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: KeyedSubtree(
              key: ValueKey(imageUrl),
              child: image,
            ),
          )
        else
          image,
        
        // Left-to-right gradient: very dark on left for text, transparent on right for artwork
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                const Color(0xFF0D0D14),
                const Color(0xFF0D0D14).withOpacity(0.95),
                Colors.black.withOpacity(0.5),
                Colors.transparent,
              ],
              stops: const [0.0, 0.3, 0.55, 0.85],
            ),
          ),
        ),
        // Top gradient: fade to dark at the top for the nav bar
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.transparent,
                Colors.transparent,
                Colors.black.withOpacity(0.4),
                const Color(0xFF0D0D14).withOpacity(0.8),
              ],
              stops: const [0.0, 0.7, 0.9, 1.0],
            ),
          ),
        ),
        // Bottom gradient: fade to dark at the bottom for posters
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.transparent,
                Colors.black.withOpacity(0.6),
                const Color(0xFF0D0D14),
              ],
              stops: const [0.0, 0.5, 0.75, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
