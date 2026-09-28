import 'package:flutter/material.dart';

import '../data/movies_data.dart';
import 'details_screen.dart';
import 'watchlist_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Movies'),
        actions: [
          IconButton(
            tooltip: 'View Watchlist',
            icon: const Icon(Icons.bookmarks),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WatchlistScreen()),
              );
              setState(() {}); // refresh icons after returning
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: sampleMovies.length,
        itemBuilder: (context, index) {
          final movie = sampleMovies[index];
          return Card(
            child: ListTile(
              leading: Image.asset(
                movie.posterPath,
                width: 56,
                fit: BoxFit.cover,
              ),
              title: Text(movie.title),
              trailing: movie.isWatchlisted
                  ? const Icon(Icons.bookmark, color: Colors.amber)
                  : const Icon(Icons.chevron_right),
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
