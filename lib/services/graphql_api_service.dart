import 'dart:convert';
import 'package:graphql/client.dart';
import '../models/movie.dart';
import 'api_call_context.dart';
import 'api_history_provider.dart';
import 'api_service.dart';
import 'energy_estimator.dart';
import 'network_context.dart';
import '../routing/device_profiler.dart';

class GraphQlApiService implements ApiService {
  final GraphQLClient client;

  GraphQlApiService({required String endpoint})
    : client = GraphQLClient(
        link: HttpLink(endpoint),
        cache: GraphQLCache(),
      );

  static const String kSimpleList = 'simple_list';
  static const String kDetailMedium = 'detail_medium';
  static const String kNestedLarge = 'nested_large';
  static const String kUltraAll = 'ultra_all';

  Future<QueryResult> _logRequest(
    String type,
    String queryString,
    Future<QueryResult> Function() fetch, {
    int overheadMs = 0,
  }) async {
    final start = DateTime.now();
    final res = await fetch();
    final durationMs = DateTime.now().difference(start).inMilliseconds;
    final responseStr = jsonEncode(res.data ?? {});
    final totalSizeKb = (queryString.length + responseStr.length) / 1024.0;
    final joules = await EnergyEstimator.instance.estimateJoules(durationMs);
    final tier = (await DeviceProfiler.instance.getDeviceTier()).name;
    final network = await networkTypeForResearch();

    ApiHistoryProvider.instance.addLog(
      'GRAPHQL',
      type,
      durationMs,
      totalSizeKb,
      overheadMs: overheadMs,
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
    const query = r'''
      query {
        movies {
          id
          title
          releaseYear
          rating
          imageUrl
        }
      }
    ''';
    final result = await _logRequest(
      label,
      query,
      () => client.query(QueryOptions(document: gql(query))),
      overheadMs: overheadMs,
    );
    if (result.hasException) return [];

    final List data = result.data!['movies'];
    return data
        .map(
          (m) => MovieListItem(
            id: m['id'].toString(),
            title: m['title'],
            releaseYear: m['releaseYear'],
            rating: m['rating'].toDouble(),
            imageUrl: m['imageUrl'],
          ),
        )
        .toList();
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
    const query = r'''
      query GetMovieDetail($id: ID!) {
        movieDetail(id: $id) {
          id
          title
          releaseYear
          rating
          director
          description
          genres
          imageUrl
        }
      }
    ''';
    final result = await _logRequest(
      label,
      query,
      () => client.query(
        QueryOptions(
          document: gql(query),
          variables: {'id': id},
        ),
      ),
      overheadMs: overheadMs,
    );
    if (result.hasException || result.data!['movieDetail'] == null) return null;

    final m = result.data!['movieDetail'];
    return MovieDetailItem(
      id: m['id'].toString(),
      title: m['title'],
      releaseYear: m['releaseYear'],
      rating: m['rating'].toDouble(),
      director: m['director'],
      description: m['description'],
      genres: List<String>.from(m['genres']),
      imageUrl: m['imageUrl'],
    );
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
    const query = r'''
      query GetMovieFull($id: ID!) {
        movieFull(id: $id) {
          id
          title
          releaseYear
          rating
          director
          description
          genres
          imageUrl
          cast {
            id
            name
            bio
          }
          reviews {
            id
            author
            content
            score
          }
        }
      }
    ''';
    final result = await _logRequest(
      label,
      query,
      () => client.query(
        QueryOptions(
          document: gql(query),
          variables: {'id': id},
        ),
      ),
      overheadMs: overheadMs,
    );
    if (result.hasException || result.data!['movieFull'] == null) return null;

    final m = result.data!['movieFull'];
    return MovieFullItem(
      id: m['id'].toString(),
      title: m['title'],
      releaseYear: m['releaseYear'],
      rating: m['rating'].toDouble(),
      director: m['director'],
      description: m['description'],
      genres: List<String>.from(m['genres']),
      imageUrl: m['imageUrl'],
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

  @override
  Future<List<MovieFullItem>> getMoviesFullAll({
    String? taskLabel,
    String? optMode,
    String? strategy,
    int overheadMs = 0,
  }) async {
    final label = taskLabel ?? kUltraAll;
    const query = r'''
      query {
        moviesFullAll {
          id
          title
          releaseYear
          rating
          director
          description
          genres
          imageUrl
          cast {
            id
            name
            bio
          }
          reviews {
            id
            author
            content
            score
          }
        }
      }
    ''';
    final result = await _logRequest(
      label,
      query,
      () => client.query(QueryOptions(document: gql(query))),
      overheadMs: overheadMs,
    );
    if (result.hasException) return [];

    final List data = result.data!['moviesFullAll'];
    return data
        .map(
          (m) => MovieFullItem(
            id: m['id'].toString(),
            title: m['title'],
            releaseYear: m['releaseYear'],
            rating: m['rating'].toDouble(),
            director: m['director'],
            description: m['description'],
            genres: List<String>.from(m['genres']),
            imageUrl: m['imageUrl'],
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
}
