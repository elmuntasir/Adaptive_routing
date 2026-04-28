import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'routing_record.dart';

class RoutingHistoryStore {
  static final RoutingHistoryStore instance = RoutingHistoryStore._internal();
  RoutingHistoryStore._internal();

  static const String _storageKey = 'routing_history';
  List<RoutingRecord> _records = [];

  List<RoutingRecord> get records => _records;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr != null) {
      final List<dynamic> list = jsonDecode(jsonStr);
      _records = list.map((item) => RoutingRecord.fromJson(item)).toList();
    }
  }

  Future<void> addRecord(RoutingRecord record) async {
    _records.insert(0, record);
    if (_records.length > 100) {
      _records = _records.sublist(0, 100);
    }
    await _save();
  }

  List<RoutingRecord> getLastRecords(String requestType, int count) {
    return _records
        .where((r) => r.requestType == requestType)
        .take(count)
        .toList();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_records.map((r) => r.toJson()).toList());
    await prefs.setString(_storageKey, jsonStr);
  }
}
