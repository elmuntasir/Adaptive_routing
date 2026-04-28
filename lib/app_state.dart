/// Shared routing state (no Flutter imports — safe for routing / Gemini layers).
library;

String currentRoutingStrategy = 'rest';
String currentOperatingMode = 'balanced';

/// Legacy single-field display for screens that still use one string.
String currentApiMode = 'rest';

void switchApiMode(String mode) {
  switch (mode) {
    case 'green':
    case 'performance':
    case 'balanced':
      currentOperatingMode = mode;
      break;
    case 'rest':
    case 'graphql':
    case 'default':
    case 'heuristic':
      currentRoutingStrategy = mode;
      break;
    case 'ai':
    case 'ai_power':
      currentRoutingStrategy = 'ai_power';
      break;
    default:
      currentRoutingStrategy = mode;
  }
  syncLegacyCurrentApiMode();
}

void syncLegacyCurrentApiMode() {
  if (currentRoutingStrategy == 'ai_power') {
    currentApiMode = currentOperatingMode;
  } else {
    currentApiMode = currentRoutingStrategy;
  }
}

String strategyColumnLabel() {
  switch (currentRoutingStrategy) {
    case 'rest':
      return 'REST';
    case 'graphql':
      return 'GQL';
    case 'heuristic':
      return 'Heuristic';
    case 'ai_power':
      return 'AI_Power';
    case 'default':
      return 'Default';
    default:
      return currentRoutingStrategy;
  }
}

String modeColumnLabel() {
  switch (currentOperatingMode) {
    case 'green':
      return 'Green';
    case 'performance':
      return 'Performance';
    case 'balanced':
      return 'Balanced';
    default:
      return currentOperatingMode;
  }
}
