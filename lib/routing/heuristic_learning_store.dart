import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase-1 baseline samples for heuristic routing (REST-only, first N per payload type).
class HeuristicLearningStore {
  static final HeuristicLearningStore instance = HeuristicLearningStore._internal();
  HeuristicLearningStore._internal();

  static const _key = 'heuristic_baseline_v1';
  static const int baselineTarget = 10;

  final Map<String, List<int>> _restLatenciesMs = {};

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _restLatenciesMs.clear();
    map.forEach((k, v) {
      _restLatenciesMs[k] = (v as List).map((e) => (e as num).toInt()).toList();
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_restLatenciesMs));
  }

  int baselineCount(String payloadType) => _restLatenciesMs[payloadType]?.length ?? 0;

  bool isLearningPhase(String payloadType) => baselineCount(payloadType) < baselineTarget;

  Future<void> recordRestSample(String payloadType, int latencyMs) async {
    _restLatenciesMs.putIfAbsent(payloadType, () => []);
    if (_restLatenciesMs[payloadType]!.length >= baselineTarget) return;
    _restLatenciesMs[payloadType]!.add(latencyMs);
    await _save();
  }

  double? averageRestMs(String payloadType) {
    final list = _restLatenciesMs[payloadType];
    if (list == null || list.isEmpty) return null;
    return list.reduce((a, b) => a + b) / list.length;
  }

  Future<void> clear() async {
    _restLatenciesMs.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
