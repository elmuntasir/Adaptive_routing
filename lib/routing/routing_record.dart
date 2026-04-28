class RoutingRecord {
  final String requestType; // simple_list | detail_medium | nested_large
  final String apiUsed; // REST | GraphQL
  final double energyJoules; // estimated
  final int latencyMs; // actual response time
  final String deviceTier;
  final String networkType;
  final String activeMode;
  final DateTime timestamp;
  final String geminiReasoning; // the one-sentence explanation from Gemini
  final bool modeConflict; // was there a green vs performance disagreement?

  RoutingRecord({
    required this.requestType,
    required this.apiUsed,
    required this.energyJoules,
    required this.latencyMs,
    required this.deviceTier,
    required this.networkType,
    required this.activeMode,
    required this.timestamp,
    required this.geminiReasoning,
    required this.modeConflict,
  });

  Map<String, dynamic> toJson() => {
        'requestType': requestType,
        'apiUsed': apiUsed,
        'energyJoules': energyJoules,
        'latencyMs': latencyMs,
        'deviceTier': deviceTier,
        'networkType': networkType,
        'activeMode': activeMode,
        'timestamp': timestamp.toIso8601String(),
        'geminiReasoning': geminiReasoning,
        'modeConflict': modeConflict,
      };

  factory RoutingRecord.fromJson(Map<String, dynamic> json) => RoutingRecord(
        requestType: json['requestType'],
        apiUsed: json['apiUsed'],
        energyJoules: json['energyJoules'],
        latencyMs: json['latencyMs'],
        deviceTier: json['deviceTier'],
        networkType: json['networkType'],
        activeMode: json['activeMode'],
        timestamp: DateTime.parse(json['timestamp']),
        geminiReasoning: json['geminiReasoning'],
        modeConflict: json['modeConflict'],
      );
}
