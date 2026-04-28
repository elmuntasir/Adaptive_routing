
class BenchmarkSession {
  final String id;
  final String name;
  final DateTime timestamp;
  final String mode;
  final String csvContent;
  final int requestCount;
  final double totalJoules;

  BenchmarkSession({
    required this.id,
    required this.name,
    required this.timestamp,
    required this.mode,
    required this.csvContent,
    required this.requestCount,
    required this.totalJoules,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'timestamp': timestamp.toIso8601String(),
        'mode': mode,
        'csvContent': csvContent,
        'requestCount': requestCount,
        'totalJoules': totalJoules,
      };

  factory BenchmarkSession.fromJson(Map<String, dynamic> json) => BenchmarkSession(
        id: json['id'],
        name: json['name'],
        timestamp: DateTime.parse(json['timestamp']),
        mode: json['mode'],
        csvContent: json['csvContent'],
        requestCount: json['requestCount'] ?? 0,
        totalJoules: (json['totalJoules'] as num?)?.toDouble() ?? 0.0,
      );
}
