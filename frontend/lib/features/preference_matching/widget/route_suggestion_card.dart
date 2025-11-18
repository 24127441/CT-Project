// File: lib/features/preference_matching/widgets/route_suggestion_card.dart

import 'package:flutter/material.dart';
import '../models/route_model.dart';

class RouteSuggestionCard extends StatelessWidget {
  final RouteModel route;
  final VoidCallback onTap;

  const RouteSuggestionCard({
    super.key,
    required this.route,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 5,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.bottomLeft,
          children: [
            // Background Image
            Ink.image(
              image: NetworkImage(route.imageUrl),
              height: 200,
              fit: BoxFit.cover,
            ),
            // Gradient Overlay
            Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  stops: const [0.0, 0.5],
                ),
              ),
            ),
            // Text Content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${route.name} - ${route.location}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    route.description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}