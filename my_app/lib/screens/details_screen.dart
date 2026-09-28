import 'package:flutter/material.dart';

import '../models/movie.dart';

class DetailsScreen extends StatelessWidget {
  final Movie movie;
  const DetailsScreen({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(movie.title)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero poster
            Image.asset(
              movie.posterPath,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    movie.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  // Cast
                  Text(
                    'Cast: ${movie.cast.join(', ')}',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 16),
                  // Synopsis
                  Text(
                    movie.synopsis,
                    style: Theme.of(context).textTheme.bodyLarge,
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
