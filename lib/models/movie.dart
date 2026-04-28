class Actor {
  final String id;
  final String name;
  final String bio;

  Actor({required this.id, required this.name, required this.bio});
}

class Review {
  final String id;
  final String author;
  final String content;
  final int score;

  Review({required this.id, required this.author, required this.content, required this.score});
}

class MovieListItem {
  final String id;
  final String title;
  final int releaseYear;
  final double rating;
  final String? imageUrl;

  MovieListItem({
    required this.id,
    required this.title,
    required this.releaseYear,
    required this.rating,
    this.imageUrl,
  });
}

class MovieDetailItem extends MovieListItem {
  final String director;
  final String description;
  final List<String> genres;

  MovieDetailItem({
    required super.id,
    required super.title,
    required super.releaseYear,
    required super.rating,
    super.imageUrl,
    required this.director,
    required this.description,
    required this.genres,
  });
}

class MovieFullItem extends MovieDetailItem {
  final List<Actor> cast;
  final List<Review> reviews;

  MovieFullItem({
    required super.id,
    required super.title,
    required super.releaseYear,
    required super.rating,
    super.imageUrl,
    required super.director,
    required super.description,
    required super.genres,
    required this.cast,
    required this.reviews,
  });
}
