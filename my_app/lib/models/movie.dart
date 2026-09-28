class Movie {
  final String title;
  final String posterPath;
  final List<String> cast;
  final String synopsis;
  bool isWatchlisted; // grad feature

  Movie({
    required this.title,
    required this.posterPath,
    required this.cast,
    required this.synopsis,
    this.isWatchlisted = false,
  });
}
