import 'package:flutter/material.dart';

class ApiRequestLog {
  /// Wire protocol used for this row (REST or GRAPHQL).
  final String apiType;
  final String payloadType;
  final DateTime timestamp;
  final int durationMs;
  final int routingOverheadMs;
  final double sizeKb;

  final String optimizationMode;
  final String routingStrategy;

  final String deviceTier;
  final String networkType;
  final String aiDecisionSource;
  final String aiReasoning;
  final double joulesEstimated;

  /// True when Green philosophy and Performance philosophy would pick different wire APIs (research signal).
  final bool modeConflict;

  ApiRequestLog({
    required this.apiType,
    required this.payloadType,
    required this.timestamp,
    required this.durationMs,
    this.routingOverheadMs = 0,
    required this.sizeKb,
    this.optimizationMode = 'N/A',
    this.routingStrategy = 'N/A',
    this.deviceTier = 'unknown',
    this.networkType = 'unknown',
    this.aiDecisionSource = 'not_applicable',
    this.aiReasoning = '',
    this.joulesEstimated = 0.0,
    this.modeConflict = false,
  });

  String get requestType => payloadType;
  bool get isSessionMarker => sizeKb == 0 && durationMs == 0;
}

class ApiHistoryProvider extends ChangeNotifier {
  static final ApiHistoryProvider _instance = ApiHistoryProvider._internal();
  factory ApiHistoryProvider() => _instance;
  ApiHistoryProvider._internal();

  final List<ApiRequestLog> _logs = [];
  List<ApiRequestLog> get logs => List.unmodifiable(_logs);

  static ApiHistoryProvider get instance => _instance;

  void addLog(
    String apiType,
    String payloadType,
    int durationMs,
    double sizeKb, {
    int overheadMs = 0,
    String optMode = 'N/A',
    String strategy = 'N/A',
    String deviceTier = 'unknown',
    String networkType = 'unknown',
    String aiDecisionSource = 'not_applicable',
    String aiReasoning = '',
    double joulesEstimated = 0.0,
    bool modeConflict = false,
  }) {
    _logs.insert(
      0,
      ApiRequestLog(
        apiType: apiType,
        payloadType: payloadType,
        timestamp: DateTime.now(),
        durationMs: durationMs,
        routingOverheadMs: overheadMs,
        sizeKb: sizeKb,
        optimizationMode: optMode,
        routingStrategy: strategy,
        deviceTier: deviceTier,
        networkType: networkType,
        aiDecisionSource: aiDecisionSource,
        aiReasoning: aiReasoning,
        joulesEstimated: joulesEstimated,
        modeConflict: modeConflict,
      ),
    );
    notifyListeners();
  }

  void addSessionMarker(String mode) {
    _logs.insert(
      0,
      ApiRequestLog(
        apiType: mode.toUpperCase(),
        payloadType: 'SESSION_START',
        timestamp: DateTime.now(),
        durationMs: 0,
        sizeKb: 0,
      ),
    );
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  /// Average latency (ms) for completed requests of [payloadType] and wire [apiType] (REST / GRAPHQL).
  double? averageLatencyMs(String payloadType, String apiType) {
    final upper = apiType.toUpperCase();
    final samples = _logs
        .where(
          (l) =>
              !l.isSessionMarker &&
              l.payloadType == payloadType &&
              l.apiType.toUpperCase() == upper,
        )
        .map((l) => l.durationMs)
        .toList();
    if (samples.isEmpty) return null;
    return samples.reduce((a, b) => a + b) / samples.length;
  }

  /// Average [joulesEstimated] for completed requests of [payloadType] and wire [apiType] (REST / GRAPHQL).
  double? averageJoulesEstimated(String payloadType, String apiType) {
    final upper = apiType.toUpperCase();
    final samples = _logs
        .where(
          (l) =>
              !l.isSessionMarker &&
              l.payloadType == payloadType &&
              l.apiType.toUpperCase() == upper,
        )
        .map((l) => l.joulesEstimated)
        .toList();
    if (samples.isEmpty) return null;
    return samples.reduce((a, b) => a + b) / samples.length;
  }
}
