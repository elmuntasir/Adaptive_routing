import 'package:flutter/material.dart';
import '../app_config.dart';
import '../app_state.dart';
import 'api_service.dart';
import 'rest_api_service.dart';
import 'graphql_api_service.dart';
import 'api_history_provider.dart';
import 'ai_agent_service.dart';
import 'api_call_context.dart';
import '../models/movie.dart';
import '../routing/conscious_router.dart';
import '../widgets/routing_overlay.dart';
import '../routing/heuristic_learning_store.dart';

export '../app_state.dart';
export 'api_service.dart';

// Since navigatorKey is in main.dart, we'll need a way to access it without circularity.
// We can move it to a dedicated file.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void syncApiCallContext() {
  ApiCallContext.routingStrategyLabel = strategyColumnLabel();
  ApiCallContext.operatingModeLabel = modeColumnLabel();
  ApiCallContext.resetAiFields();
}

late RestApiService restApiService;
late GraphQlApiService graphqlApiService;

class ComparisonApiService implements ApiService {
  @override
  Future<List<MovieListItem>> getMovies({
    String? taskLabel,
    String? optMode,
    String? strategy,
    int overheadMs = 0,
  }) async {
    final label = taskLabel ?? RestApiService.kSimpleList;
    final results = await Future.wait([
      restApiService.getMovies(
        taskLabel: label,
        optMode: optMode,
        strategy: strategy,
        overheadMs: overheadMs,
      ),
      graphqlApiService
          .getMovies(
            taskLabel: label,
            optMode: optMode,
            strategy: strategy,
            overheadMs: overheadMs,
          )
          .catchError((e) => <MovieListItem>[]),
    ]);
    return results[0];
  }

  @override
  Future<MovieDetailItem?> getMovieDetail(
    String id, {
    String? taskLabel,
    String? optMode,
    String? strategy,
    int overheadMs = 0,
  }) async {
    final label = taskLabel ?? RestApiService.kDetailMedium;
    final results = await Future.wait([
      restApiService.getMovieDetail(
        id,
        taskLabel: label,
        optMode: optMode,
        strategy: strategy,
        overheadMs: overheadMs,
      ),
      graphqlApiService
          .getMovieDetail(
            id,
            taskLabel: label,
            optMode: optMode,
            strategy: strategy,
            overheadMs: overheadMs,
          )
          .catchError((e) => null),
    ]);
    return results[0];
  }

  @override
  Future<MovieFullItem?> getMovieFull(
    String id, {
    String? taskLabel,
    String? optMode,
    String? strategy,
    int overheadMs = 0,
  }) async {
    final label = taskLabel ?? RestApiService.kNestedLarge;
    final results = await Future.wait([
      restApiService.getMovieFull(
        id,
        taskLabel: label,
        optMode: optMode,
        strategy: strategy,
        overheadMs: overheadMs,
      ),
      graphqlApiService
          .getMovieFull(
            id,
            taskLabel: label,
            optMode: optMode,
            strategy: strategy,
            overheadMs: overheadMs,
          )
          .catchError((e) => null),
    ]);
    return results[0];
  }

  @override
  Future<List<MovieFullItem>> getMoviesFullAll({
    String? taskLabel,
    String? optMode,
    String? strategy,
    int overheadMs = 0,
  }) async {
    final label = taskLabel ?? RestApiService.kUltraAll;
    final results = await Future.wait([
      restApiService.getMoviesFullAll(
        taskLabel: label,
        optMode: optMode,
        strategy: strategy,
        overheadMs: overheadMs,
      ),
      graphqlApiService
          .getMoviesFullAll(
            taskLabel: label,
            optMode: optMode,
            strategy: strategy,
            overheadMs: overheadMs,
          )
          .catchError((e) => <MovieFullItem>[]),
    ]);
    return results[0];
  }
}

late final ComparisonApiService comparisonApiService;

class AdaptiveApiService implements ApiService {
  final ApiService restApiService;
  final ApiService graphqlApiService;
  final ApiService comparisonApiService;

  AdaptiveApiService({
    required this.restApiService,
    required this.graphqlApiService,
    required this.comparisonApiService,
  });

  @override
  Future<List<MovieListItem>> getMovies({
    String? taskLabel,
    String? optMode,
    String? strategy,
    int overheadMs = 0,
  }) {
    return _executeWithRouting(
      'simple_list',
      (s, overhead) => s.getMovies(
        taskLabel: taskLabel ?? 'simple_list',
        optMode: optMode ?? modeColumnLabel(),
        strategy: strategy ?? strategyColumnLabel(),
        overheadMs: overhead,
      ),
    );
  }

  @override
  Future<MovieDetailItem?> getMovieDetail(
    String id, {
    String? taskLabel,
    String? optMode,
    String? strategy,
    int overheadMs = 0,
  }) {
    return _executeWithRouting(
      'detail_medium',
      (s, overhead) => s.getMovieDetail(
        id,
        taskLabel: taskLabel ?? 'detail_medium',
        optMode: optMode ?? modeColumnLabel(),
        strategy: strategy ?? strategyColumnLabel(),
        overheadMs: overhead,
      ),
    );
  }

  @override
  Future<MovieFullItem?> getMovieFull(
    String id, {
    String? taskLabel,
    String? optMode,
    String? strategy,
    int overheadMs = 0,
  }) {
    return _executeWithRouting(
      'nested_large',
      (s, overhead) => s.getMovieFull(
        id,
        taskLabel: taskLabel ?? 'nested_large',
        optMode: optMode ?? modeColumnLabel(),
        strategy: strategy ?? strategyColumnLabel(),
        overheadMs: overhead,
      ),
    );
  }

  @override
  Future<List<MovieFullItem>> getMoviesFullAll({
    String? taskLabel,
    String? optMode,
    String? strategy,
    int overheadMs = 0,
  }) {
    return _executeWithRouting(
      'ultra_all',
      (s, overhead) => s.getMoviesFullAll(
        taskLabel: taskLabel ?? 'ultra_all',
        optMode: optMode ?? modeColumnLabel(),
        strategy: strategy ?? strategyColumnLabel(),
        overheadMs: overhead,
      ),
    );
  }

  Future<T> _executeWithRouting<T>(
    String requestType,
    Future<T> Function(ApiService service, int overhead) action,
  ) async {
    syncApiCallContext();

    final strategy = currentRoutingStrategy;

    if (strategy == 'default') {
      return action(comparisonApiService, 0);
    }
    if (strategy == 'rest') {
      return action(restApiService, 0);
    }
    if (strategy == 'graphql') {
      return action(graphqlApiService, 0);
    }

    if (strategy == 'heuristic') {
      final store = HeuristicLearningStore.instance;
      if (store.isLearningPhase(requestType)) {
        final sw = Stopwatch()..start();
        final result = await action(restApiService, 0);
        sw.stop();
        await store.recordRestSample(requestType, sw.elapsedMilliseconds);
        return result;
      }
      final restAvg = store.averageRestMs(requestType) ?? 0.0;
      final gqlAvg =
          ApiHistoryProvider.instance.averageLatencyMs(
            requestType,
            'GRAPHQL',
          ) ??
          double.infinity;
      final useGql = gqlAvg < restAvg;
      final selected = useGql ? graphqlApiService : restApiService;
      return action(selected, 0);
    }

    if (strategy == 'ai_power') {
      final routingStart = DateTime.now();
      final decision = await ConsciousRouter.instance.route(requestType);
      final routingDuration =
          DateTime.now().difference(routingStart).inMilliseconds;

      ApiCallContext.setAiDecision(
        source: decision.aiDecisionSource,
        reasoning: decision.reasoning,
        modeConflict: decision.modeConflict,
      );

      final overlayState = navigatorKey.currentState?.overlay;
      if (overlayState != null) {
        RoutingOverlay.show(overlayState, decision);
      }

      final selectedService = decision.api == ApiDecision.graphql
          ? graphqlApiService
          : restApiService;

      final executionStart = DateTime.now();
      final result = await action(selectedService, routingDuration);
      final executionDuration =
          DateTime.now().difference(executionStart).inMilliseconds;

      await ConsciousRouter.instance.logFinalOutcome(
        requestType,
        decision,
        executionDuration,
      );
      return result;
    }

    return action(restApiService, 0);
  }
}

late final AdaptiveApiService apiService;

void updateBackendUrl(String newUrl) async {
  await AppConfig.setBackendUrl(newUrl);
  restApiService = RestApiService(baseUrl: AppConfig.backendUrl);
  graphqlApiService = GraphQlApiService(
    endpoint: '${AppConfig.backendUrl}/graphql',
  );
}

void updateGeminiApiKey(String newKey) async {
  final trimmedKey = newKey.trim();
  await AppConfig.setApiKey(trimmedKey);
  ConsciousRouter.instance.reInitialize();
  AiAgentService.instance.reInitialize();
}

void updateGeminiModel(String newModel) async {
  await AppConfig.setGeminiModel(newModel);
  ConsciousRouter.instance.reInitialize();
  AiAgentService.instance.reInitialize();
}
