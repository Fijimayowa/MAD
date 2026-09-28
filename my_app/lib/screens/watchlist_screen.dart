import 'package:flutter/material.dart';

import '../data/movies_data.dart';
import 'details_screen.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  @override
  Widget build(BuildContext context) {
    final watchlisted = sampleMovies.where((m) => m.isWatchlisted).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('My Watchlist')),
      body: watchlisted.isEmpty
          ? const Center(child: Text('No movies in your watchlist yet.'))
          : ListView.builder(
              itemCount: watchlisted.length,
              itemBuilder: (context, index) {
                final movie = watchlisted[index];
                return Card(
                  child: ListTile(
                    leading: Image.asset(
                      movie.posterPath,
                      width: 56,
                      fit: BoxFit.cover,
                    ),
                    title: Text(movie.title),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailsScreen(movie: movie),
                        ),
                      );
                      setState(() {});
                    },
                  ),
                );
              },
            ),
    );
  }
}
