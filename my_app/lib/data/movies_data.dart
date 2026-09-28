import '../models/movie.dart';

final List<Movie> sampleMovies = [
  Movie(
    title: 'Inception',
    posterPath: 'assets/images/inception.jpg',
    cast: ['Leonardo DiCaprio', 'Joseph Gordon-Levitt', 'Elliot Page'],
    synopsis:
        'A thief who steals corporate secrets through dream-sharing technology is given the inverse task of planting an idea into the mind of a CEO.',
  ),
  Movie(
    title: 'Interstellar',
    posterPath: 'assets/images/interstellar.jpg',
    cast: ['Matthew McConaughey', 'Anne Hathaway', 'Jessica Chastain'],
    synopsis:
        'A team of explorers travel through a wormhole in space in an attempt to ensure humanity\'s survival.',
  ),
  Movie(
    title: 'The Dark Knight',
    posterPath: 'assets/images/dark_knight.jpg',
    cast: ['Christian Bale', 'Heath Ledger', 'Aaron Eckhart'],
    synopsis:
        'When the menace known as the Joker wreaks havoc on Gotham, Batman must accept one of the greatest psychological tests of his ability to fight injustice.',
  ),
];
