/// Per-request metadata for CSV export (set by [AdaptiveApiService] before each call).
class ApiCallContext {
  static String routingStrategyLabel = 'REST';
  static String operatingModeLabel = 'Balanced';
  static String aiDecisionSource = 'not_applicable';
  static String aiReasoning = '';

  /// Set when routing strategies disagree on wire API (Green vs Performance philosophy).
  static bool routingModeConflict = false;

  static void resetAiFields() {
    aiDecisionSource = 'not_applicable';
    aiReasoning = '';
    routingModeConflict = false;
  }

  static void setAiDecision({
    required String source,
    required String reasoning,
    bool modeConflict = false,
  }) {
    aiDecisionSource = source;
    aiReasoning = reasoning;
    routingModeConflict = modeConflict;
  }
}
