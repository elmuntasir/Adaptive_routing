import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/movie.dart';
import 'api_call_context.dart';
import 'api_history_provider.dart';
import 'api_service.dart';
import 'energy_estimator.dart';
import 'network_context.dart';
import '../routing/device_profiler.dart';

class RestApiService implements ApiService {
  final String baseUrl;

  RestApiService({this.baseUrl = 'http://127.0.0.1:5005'});

  /// Canonical task labels for research exports (never Short/Medium/Large).
  static const String kSimpleList = 'simple_list';
  static const String kDetailMedium = 'detail_medium';
  static const String kNestedLarge = 'nested_large';
  static const String kUltraAll = 'ultra_all';

  Future<http.Response> _logRequest(
    String type,
    Future<http.Response> Function() fetch, {
    int overhead = 0,
  }) async {
    final start = DateTime.now();
    final res = await fetch();
    final durationMs = DateTime.now().difference(start).inMilliseconds;
    final sizeKb = res.bodyBytes.length / 1024.0;
    final joules = await EnergyEstimator.instance.estimateJoules(durationMs);
    final tier = (await DeviceProfiler.instance.getDeviceTier()).name;
    final network = await networkTypeForResearch();

    ApiHistoryProvider.instance.addLog(
      'REST',
      type,
      durationMs,
      sizeKb,
      overheadMs: overhead,
      optMode: ApiCallContext.operatingModeLabel,
      strategy: ApiCallContext.routingStrategyLabel,
      deviceTier: tier,
      networkType: network,
      aiDecisionSource: ApiCallContext.aiDecisionSource,
      aiReasoning: ApiCallContext.aiReasoning,
      joulesEstimated: joules,
      modeConflict: ApiCallContext.routingModeConflict,
    );
    return res;
  }

  @override
  Future<List<MovieListItem>> getMovies({
    String? taskLabel,
    String? optMode,
    String? strategy,
    int overheadMs = 0,
  }) async {
    final label = taskLabel ?? kSimpleList;
    final res = await _logRequest(
      label,
      () => http.get(Uri.parse('$baseUrl/api/movies')),
      overhead: overheadMs,
    );
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data
          .map(
            (m) => MovieListItem(
              id: m['id'].toString(),
              title: m['title'],
              releaseYear: m['release_year'],
              rating: m['rating'].toDouble(),
              imageUrl: m['image_url'],
            ),
          )
          .toList();
    }
    return [];
  }

  @override
  Future<MovieDetailItem?> getMovieDetail(
    String id, {
    String? taskLabel,
    String? optMode,
    String? strategy,
    int overheadMs = 0,
  }) async {
    final label = taskLabel ?? kDetailMedium;
    final res = await _logRequest(
      label,
      () => http.get(Uri.parse('$baseUrl/api/movies/$id')),
      overhead: overheadMs,
    );
    if (res.statusCode == 200) {
      final m = jsonDecode(res.body);
      return MovieDetailItem(
        id: m['id'].toString(),
        title: m['title'],
        releaseYear: m['release_year'],
        rating: m['rating'].toDouble(),
        director: m['director'],
        description: m['description'],
        genres: List<String>.from(m['genres']),
        imageUrl: m['image_url'],
      );
    }
    return null;
  }

  @override
  Future<MovieFullItem?> getMovieFull(
    String id, {
    String? taskLabel,
    String? optMode,
    String? strategy,
    int overheadMs = 0,
  }) async {
    final label = taskLabel ?? kNestedLarge;
    final res = await _logRequest(
      label,
      () => http.get(Uri.parse('$baseUrl/api/movies/$id/full')),
      overhead: overheadMs,
    );
    if (res.statusCode == 200) {
      final m = jsonDecode(res.body);
      return MovieFullItem(
        id: m['id'].toString(),
        title: m['title'],
        releaseYear: m['release_year'],
        rating: m['rating'].toDouble(),
        director: m['director'],
        description: m['description'],
        genres: List<String>.from(m['genres']),
        imageUrl: m['image_url'],
        cast: (m['cast'] as List)
            .map(
              (a) => Actor(
                id: a['id'].toString(),
                name: a['name'],
                bio: a['bio'],
              ),
            )
            .toList(),
        reviews: (m['reviews'] as List)
            .map(
              (r) => Review(
                id: r['id'].toString(),
                author: r['author'],
                content: r['content'],
                score: r['score'],
              ),
            )
            .toList(),
      );
    }
    return null;
  }

  @override
  Future<List<MovieFullItem>> getMoviesFullAll({
    String? taskLabel,
    String? optMode,
    String? strategy,
    int overheadMs = 0,
  }) async {
    final label = taskLabel ?? kUltraAll;
    final res = await _logRequest(
      label,
      () => http.get(Uri.parse('$baseUrl/api/movies/all/full')),
      overhead: overheadMs,
    );
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data
          .map(
            (m) => MovieFullItem(
              id: m['id'].toString(),
              title: m['title'],
              releaseYear: m['release_year'],
              rating: m['rating'].toDouble(),
              director: m['director'],
              description: m['description'],
              genres: List<String>.from(m['genres']),
              imageUrl: m['image_url'],
              cast: (m['cast'] as List)
                  .map(
                    (a) => Actor(
                      id: a['id'].toString(),
                      name: a['name'],
                      bio: a['bio'],
                    ),
                  )
                  .toList(),
              reviews: (m['reviews'] as List)
                  .map(
                    (r) => Review(
                      id: r['id'].toString(),
                      author: r['author'],
                      content: r['content'],
                      score: r['score'],
                    ),
                  )
                  .toList(),
            ),
          )
          .toList();
    }
    return [];
  }
}
