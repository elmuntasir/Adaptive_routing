import '../models/movie.dart';

abstract class ApiService {
  Future<List<MovieListItem>> getMovies({
    String? taskLabel,
    String? optMode,
    String? strategy,
    int overheadMs = 0,
  });

  Future<MovieDetailItem?> getMovieDetail(
    String id, {
    String? taskLabel,
    String? optMode,
    String? strategy,
    int overheadMs = 0,
  });

  Future<MovieFullItem?> getMovieFull(
    String id, {
    String? taskLabel,
    String? optMode,
    String? strategy,
    int overheadMs = 0,
  });

  Future<List<MovieFullItem>> getMoviesFullAll({
    String? taskLabel,
    String? optMode,
    String? strategy,
    int overheadMs = 0,
  });
}
