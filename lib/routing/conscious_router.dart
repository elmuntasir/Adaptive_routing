// Conscious routing for CSE451 — see mode philosophy in route() and _applyBalancedMode.
//
// Methodology note for the paper: a flagship device in Green Mode can show lower Joules
// than a budget device on the same API because hardware efficiency differs. The system
// therefore records Device_Tier on every row so the paper can state this paradox honestly
// (green tooling often helps least those who need it most unless routing compensates).

import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'ai_policy_store.dart';
import 'routing_history_store.dart';
import 'routing_record.dart';
import 'device_profiler.dart';
import '../services/api_history_provider.dart';
import '../services/server_load_service.dart';
import '../services/energy_estimator.dart';
import '../app_config.dart';
import '../app_state.dart';

enum ApiDecision { rest, graphql }

class ConsciousRouter {
  static final ConsciousRouter instance = ConsciousRouter._internal();
  ConsciousRouter._internal();

  late GenerativeModel _model;
  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();
  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized && AppConfig.geminiApiKey.isNotEmpty) return;
    
    if (AppConfig.geminiApiKey.isEmpty) {
      _isInitialized = false;
      return;
    }

    _model = GenerativeModel(
      model: AppConfig.geminiModel,
      apiKey: AppConfig.geminiApiKey,
    );
    _isInitialized = true;
  }

  void reInitialize() {
    print('Syncing Gemini Model with key: ${AppConfig.geminiApiKey.length > 8 ? "${AppConfig.geminiApiKey.substring(0, 4)}...${AppConfig.geminiApiKey.substring(AppConfig.geminiApiKey.length - 4)}" : "too short"}');
    
    if (AppConfig.geminiApiKey.isEmpty) {
      _isInitialized = false;
      return;
    }

    _model = GenerativeModel(
      model: AppConfig.geminiModel,
      apiKey: AppConfig.geminiApiKey,
    );
    _isInitialized = true;
  }

  Future<String?> testConnection() async {
    try {
      reInitialize();
      // Use a very basic ping
      final response = await _model.generateContent([Content.text('ping')]);
      if (response.text != null) return null; // Success
      return 'No response from Gemini';
    } catch (e) {
      final err = e.toString();
      print('Gemini Connection Test Failed: $err');
      if (err.contains('API key not valid')) return 'API Key rejected by Google';
      if (err.contains('location')) return 'Gemini is not available in your region';
      if (err.contains('model')) return 'Model not found (check model ID)';
      return err.split('\n').first;
    }
  }

  /// Routes according to [currentOperatingMode]: Green (min energy), Performance (min
  /// latency), or Balanced (Gemini trade-off). [modeConflict] is true when Green and
  /// Performance philosophies would choose different wire APIs for this context.
  Future<RoutingDecision> route(String requestType) async {
    initialize();

    if (!_isInitialized) {
      final greenPick = _pickGreenPhilosophy(requestType, await DeviceProfiler.instance.getDeviceTier(), await _getNetworkType());
      return RoutingDecision(
        api: greenPick,
        confidence: 0.5,
        reasoning: 'AI model not ready (No API Key). Using Green fallback.',
        modeConflict: false,
        isCacheHit: false,
        aiDecisionSource: 'rules_engine',
      );
    }

    final deviceTier = await DeviceProfiler.instance.getDeviceTier();
    final networkType = await _getNetworkType();
    final serverLoad = await ServerLoadService.instance.getServerLoad();

    final greenPick = _pickGreenPhilosophy(requestType, deviceTier, networkType);
    final perfPick = _pickPerformancePhilosophy(
      requestType,
      networkType,
      serverLoad,
    );
    final modeConflict = greenPick != perfPick;

    switch (currentOperatingMode) {
      case 'green':
        return _applyGreenMode(
          requestType,
          deviceTier,
          networkType,
          greenPick,
          modeConflict,
        );
      case 'performance':
        return _applyPerformanceMode(
          requestType,
          deviceTier,
          networkType,
          perfPick,
          modeConflict,
        );
      case 'balanced':
      default:
        return _applyBalancedMode(
          requestType,
          deviceTier,
          networkType,
          await _battery.batteryLevel,
          serverLoad,
          greenPick,
          perfPick,
          modeConflict,
        );
    }
  }

  // --- Green Mode: minimum Joules; budget favors REST on small payloads; flagship GQL on M/L ---

  ApiDecision _pickGreenPhilosophy(
    String requestType,
    DeviceTier tier,
    String networkType,
  ) {
    final hist = ApiHistoryProvider.instance;
    final jRest = hist.averageJoulesEstimated(requestType, 'REST');
    final jGql = hist.averageJoulesEstimated(requestType, 'GRAPHQL');

    if (jRest != null && jGql != null) {
      if (jRest < jGql) return ApiDecision.rest;
      if (jGql < jRest) return ApiDecision.graphql;
    } else if (jRest != null && jGql == null) {
      return ApiDecision.rest;
    } else if (jGql != null && jRest == null) {
      return ApiDecision.graphql;
    }

    return _greenTierFallback(requestType, tier);
  }

  ApiDecision _greenTierFallback(String requestType, DeviceTier tier) {
    switch (requestType) {
      case 'simple_list':
        return ApiDecision.rest;
      case 'detail_medium':
        return tier == DeviceTier.flagship ? ApiDecision.graphql : ApiDecision.rest;
      case 'nested_large':
      case 'ultra_all':
        return tier == DeviceTier.flagship ? ApiDecision.graphql : ApiDecision.rest;
      default:
        return ApiDecision.rest;
    }
  }

  Future<RoutingDecision> _applyGreenMode(
    String requestType,
    DeviceTier deviceTier,
    String networkType,
    ApiDecision greenPick,
    bool modeConflict,
  ) async {
    final cacheKey = AiPolicyStore.computeKey(
      payloadType: requestType,
      mode: 'green',
      deviceTier: deviceTier.name,
      networkType: networkType,
    );

    final cached = await AiPolicyStore.instance.get(cacheKey);
    if (cached != null) {
      return RoutingDecision(
        api: _apiFromRouteString(cached.route),
        confidence: 1.0,
        reasoning: cached.reasoning,
        modeConflict: modeConflict,
        isCacheHit: true,
        aiDecisionSource: 'cached',
      );
    }

    final reasoning =
        'Green Mode: minimize Joules on this device; chosen ${_label(greenPick)} for $requestType '
        '(history + tier fallback where needed).';
    await AiPolicyStore.instance.put(
      cacheKey: cacheKey,
      route: _routeString(greenPick),
      reasoning: reasoning,
    );

    return RoutingDecision(
      api: greenPick,
      confidence: 0.95,
      reasoning: reasoning,
      modeConflict: modeConflict,
      isCacheHit: false,
      aiDecisionSource: 'rules_engine',
    );
  }

  // --- Performance Mode: minimum latency; network/server heuristics ---

  ApiDecision _pickPerformancePhilosophy(
    String requestType,
    String networkType,
    String serverLoad,
  ) {
    final hist = ApiHistoryProvider.instance;

    if (serverLoad == 'high' && requestType == 'simple_list') {
      return ApiDecision.rest;
    }

    final poorNetwork = !_isWifi(networkType);
    if (poorNetwork &&
        (requestType == 'simple_list' || requestType == 'detail_medium')) {
      return ApiDecision.rest;
    }

    if (_isWifi(networkType) &&
        (requestType == 'nested_large' || requestType == 'ultra_all')) {
      return ApiDecision.graphql;
    }

    final msRest = hist.averageLatencyMs(requestType, 'REST');
    final msGql = hist.averageLatencyMs(requestType, 'GRAPHQL');

    if (msRest != null && msGql != null) {
      return msRest <= msGql ? ApiDecision.rest : ApiDecision.graphql;
    }
    if (msRest != null) return ApiDecision.rest;
    if (msGql != null) return ApiDecision.graphql;

    return ApiDecision.rest;
  }

  bool _isWifi(String networkType) => networkType == 'wifi';

  Future<RoutingDecision> _applyPerformanceMode(
    String requestType,
    DeviceTier deviceTier,
    String networkType,
    ApiDecision perfPick,
    bool modeConflict,
  ) async {
    final cacheKey = AiPolicyStore.computeKey(
      payloadType: requestType,
      mode: 'performance',
      deviceTier: deviceTier.name,
      networkType: networkType,
    );

    final cached = await AiPolicyStore.instance.get(cacheKey);
    if (cached != null) {
      return RoutingDecision(
        api: _apiFromRouteString(cached.route),
        confidence: 1.0,
        reasoning: cached.reasoning,
        modeConflict: modeConflict,
        isCacheHit: true,
        aiDecisionSource: 'cached',
      );
    }

    final reasoning =
        'Performance Mode: minimize Duration_ms; chosen ${_label(perfPick)} for $requestType '
        '(latency history + network/load heuristics).';
    await AiPolicyStore.instance.put(
      cacheKey: cacheKey,
      route: _routeString(perfPick),
      reasoning: reasoning,
    );

    return RoutingDecision(
      api: perfPick,
      confidence: 0.95,
      reasoning: reasoning,
      modeConflict: modeConflict,
      isCacheHit: false,
      aiDecisionSource: 'rules_engine',
    );
  }

  // --- Balanced Mode: Gemini resolves energy vs latency; bias to green when trade-off < 10% ---

  Future<RoutingDecision> _applyBalancedMode(
    String requestType,
    DeviceTier deviceTier,
    String networkType,
    int batteryLevel,
    String serverLoad,
    ApiDecision greenPick,
    ApiDecision perfPick,
    bool modeConflict,
  ) async {
    final cacheKey = AiPolicyStore.computeKey(
      payloadType: requestType,
      mode: 'balanced',
      deviceTier: deviceTier.name,
      networkType: networkType,
    );

    final cached = await AiPolicyStore.instance.get(cacheKey);
    if (cached != null) {
      return RoutingDecision(
        api: _apiFromRouteString(cached.route),
        confidence: 1.0,
        reasoning: cached.reasoning,
        modeConflict: modeConflict,
        isCacheHit: true,
        aiDecisionSource: 'cached',
      );
    }

    final hist = ApiHistoryProvider.instance;
    final jRest = hist.averageJoulesEstimated(requestType, 'REST');
    final jGql = hist.averageJoulesEstimated(requestType, 'GRAPHQL');
    final msRest = hist.averageLatencyMs(requestType, 'REST');
    final msGql = hist.averageLatencyMs(requestType, 'GRAPHQL');

    final lastHistory = RoutingHistoryStore.instance.getLastRecords(requestType, 8);
    final historyJson = lastHistory
        .map(
          (h) => {
            'api': h.apiUsed,
            'joules': h.energyJoules.toStringAsFixed(4),
            'latency': h.latencyMs,
          },
        )
        .toList();

    final greenHint = _routeString(greenPick);
    final perfHint = _routeString(perfPick);
    final conflictHint =
        modeConflict ? 'CONFLICT (research-relevant disagreement)' : 'agree';

    final balancedPhilosophy = '''
BALANCED MODE — Conscious compromise (not pure Green nor pure Performance).
- You receive both energy history (Joules_estimated) and latency history (Duration_ms).
- Resolve the trade-off: if energy and latency disagree, prefer the greener option when the
  relative gap in BOTH dimensions is under 10% (small trade-off → default to environmental benefit).
- When one option is clearly better on one dimension and much worse on the other, weigh
  device_tier, battery_level, network quality, and server_load.
- Green-only routing would pick: $greenHint ; Performance-only would pick: $perfHint ;
  they $conflictHint.
''';

    final context = {
      'payload_type': requestType,
      'device_tier': deviceTier.name,
      'network_type': networkType,
      'battery_level': batteryLevel,
      'server_load': serverLoad,
      'avg_joules_rest': jRest,
      'avg_joules_graphql': jGql,
      'avg_latency_ms_rest': msRest,
      'avg_latency_ms_graphql': msGql,
      'green_philosophy_pick': greenHint,
      'performance_philosophy_pick': perfHint,
      'philosophies_conflict': modeConflict,
      'recent_samples': historyJson,
    };

    final prompt =
        '$balancedPhilosophy\n\nContext: ${jsonEncode(context)}\n\n'
        'Respond ONLY with valid JSON, no markdown:\n'
        '{"route":"REST" or "GraphQL","confidence":0.0 to 1.0,"reasoning":"one sentence max"}';

    // Rate-limiting retry logic for research stability
    int retries = 0;
    while (retries < 2) {
      try {
        final response = await _model.generateContent([Content.text(prompt)]);
        final text = response.text;
        if (text != null) {
          var jsonStr = text.trim();
          if (jsonStr.contains('```json')) {
            jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
          } else if (jsonStr.contains('```')) {
            jsonStr = jsonStr.split('```')[1].trim();
          }

          final Map<String, dynamic> data = jsonDecode(jsonStr);
          final routeStr = data['route']?.toString().toUpperCase() ?? 'REST';
          final decision = RoutingDecision(
            api: routeStr == 'GRAPHQL' ? ApiDecision.graphql : ApiDecision.rest,
            confidence: (data['confidence'] is num)
                ? (data['confidence'] as num).toDouble()
                : 0.85,
            reasoning: data['reasoning']?.toString() ?? '',
            modeConflict: modeConflict,
            isCacheHit: false,
            aiDecisionSource: 'gemini_live',
          );

          await AiPolicyStore.instance.put(
            cacheKey: cacheKey,
            route: routeStr == 'GRAPHQL' ? 'GraphQL' : 'REST',
            reasoning: decision.reasoning,
          );

          return decision;
        }
        break; // Success
      } catch (e) {
        final errStr = e.toString();
        if (errStr.contains('429') || errStr.contains('quota')) {
          retries++;
          print('Gemini Rate Limit hit (attempt $retries). Waiting 2s...');
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        
        print('Gemini Balanced Routing Error: $e');
        final fallback = greenPick;
        return RoutingDecision(
          api: fallback,
          confidence: 0.5,
          reasoning: 'Gemini error (${errStr.split('\n').first}); Green-philosophy fallback.',
          modeConflict: modeConflict,
          isCacheHit: false,
          aiDecisionSource: 'rules_engine',
        );
      }
    }

    final fallback = greenPick;
    return RoutingDecision(
      api: fallback,
      confidence: 0.5,
      reasoning: 'Balanced fallback: no Gemini response; using Green-philosophy pick.',
      modeConflict: modeConflict,
      isCacheHit: false,
      aiDecisionSource: 'rules_engine',
    );
  }

  ApiDecision _apiFromRouteString(String r) =>
      r.toUpperCase() == 'GRAPHQL' ? ApiDecision.graphql : ApiDecision.rest;

  String _routeString(ApiDecision a) =>
      a == ApiDecision.graphql ? 'GraphQL' : 'REST';

  String _label(ApiDecision a) => _routeString(a);

  Future<String> _getNetworkType() async {
    final result = await _connectivity.checkConnectivity();
    if (result.contains(ConnectivityResult.wifi)) return 'wifi';
    if (result.contains(ConnectivityResult.mobile)) return '4g';
    if (result.contains(ConnectivityResult.none)) return 'none';
    return 'unknown';
  }

  Future<void> logFinalOutcome(
    String requestType,
    RoutingDecision decision,
    int durationMs,
  ) async {
    final deviceTier = await DeviceProfiler.instance.getDeviceTier();
    final networkType = await _getNetworkType();
    final energy = await EnergyEstimator.instance.estimateJoules(durationMs);

    final record = RoutingRecord(
      requestType: requestType,
      apiUsed: decision.api == ApiDecision.graphql ? 'GraphQL' : 'REST',
      energyJoules: energy,
      latencyMs: durationMs,
      deviceTier: deviceTier.name,
      networkType: networkType,
      activeMode: currentOperatingMode,
      timestamp: DateTime.now(),
      geminiReasoning: decision.reasoning,
      modeConflict: decision.modeConflict,
    );

    await RoutingHistoryStore.instance.addRecord(record);
  }
}

class RoutingDecision {
  final ApiDecision api;
  final double confidence;
  final String reasoning;
  final bool modeConflict;
  final bool isCacheHit;

  /// gemini_live | cached | rules_engine (CSV / research provenance).
  final String aiDecisionSource;

  RoutingDecision({
    required this.api,
    required this.confidence,
    required this.reasoning,
    required this.modeConflict,
    required this.isCacheHit,
    required this.aiDecisionSource,
  });
}
