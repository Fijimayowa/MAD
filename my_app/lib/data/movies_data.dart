import '../models/movie.dart';

final List<Movie> sampleMovies = [
  Movie(
    title: 'The Empire Strikes Back',
    posterPath: 'assets/images/empire_strikes_back.jpg',
    cast: ['Mark Hamill', 'Harrison Ford', 'Carrie Fisher'],
    synopsis: 'After the Rebels are driven from their hidden base, Luke Skywalker begins Jedi training while his friends are pursued across the galaxy by the Empire.',
  ),
  Movie(
    title: 'The Avengers',
    posterPath: 'assets/images/avengers.jpg',
    cast: ['Robert Downey Jr.', 'Chris Evans', 'Scarlett Johansson'],
    synopsis: 'Earth\'s mightiest heroes must learn to work together when Loki and an alien army threaten to take over the world.',
  ),
  Movie(
    title: 'Moonlight',
    posterPath: 'assets/images/moonlight.jpg',
    cast: ['Trevante Rhodes', 'André Holland', 'Janelle Monáe'],
    synopsis: 'A young man growing up in Miami is shown at three stages of his life as he searches for his identity and a place to belong.',
  ),
  Movie(
    title: 'Jaws',
    posterPath: 'assets/images/jaws.jpg',
    cast: ['Roy Scheider', 'Robert Shaw', 'Richard Dreyfuss'],
    synopsis: 'When a giant shark begins attacking swimmers at a beach town, the police chief, a marine scientist, and a grizzled fisherman set out to hunt it down.',
  ),
];
