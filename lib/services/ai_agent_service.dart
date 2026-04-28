import 'package:google_generative_ai/google_generative_ai.dart';
import '../app_config.dart';
import '../routing/device_profiler.dart';

class AiAgentService {
  static final AiAgentService instance = AiAgentService._internal();
  AiAgentService._internal();

  late GenerativeModel _model;
  
  // The Strategy State
  String currentStrategy = 'Balanced Heuristic';
  String reasoningLog = 'Agent standby. Awaiting system scan...';
  Map<String, String> policyMap = {
    'Small': 'REST',
    'Medium': 'REST', 
    'Large': 'GraphQL'
  };

  bool isInitialized = false;

  Future<void> initializeAgent() async {
    if (isInitialized) return;
    
    _model = GenerativeModel(model: AppConfig.geminiModel, apiKey: AppConfig.geminiApiKey);
    
    await _performSystemScanAndPolicyGeneration();
    isInitialized = true;
  }

  Future<void> reInitialize() async {
    _model = GenerativeModel(model: AppConfig.geminiModel, apiKey: AppConfig.geminiApiKey);
    await _performSystemScanAndPolicyGeneration();
  }

  Future<void> _performSystemScanAndPolicyGeneration() async {
    reasoningLog = 'Scanning Hardware Architecture...';
    
    final deviceProfile = await DeviceProfiler.instance.getDeviceSignature();
    final tier = await DeviceProfiler.instance.getDeviceTier();

    reasoningLog = 'Generating Strategy for: $deviceProfile';

    final prompt = '''
    You are an AI Energy Optimization Agent for a Mobile App.
    Context: The app chooses between REST and GraphQL APIs to save battery.
    Device Profile: $deviceProfile
    Assessed Tier: ${tier.name}
    
    Energy Rules:
    - REST: Low CPU (less parsing), High Network (Over-fetching).
    - GraphQL: High CPU (JSON parsing complexity), Low Network (Exact fields).
    
    Task Types:
    - Small: Movie List (2KB)
    - Medium: Movie Detail (15KB)
    - Large: Full Cast & Reviews (150KB)
    
    Output exactly 3 lines in this format:
    Small: [REST or GraphQL]
    Medium: [REST or GraphQL]
    Large: [REST or GraphQL]
    Reasoning: [One sentence explaining why based on the device specs]
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final text = response.text;

      if (text != null) {
        _parseResponse(text);
        reasoningLog = 'AI Strategy optimized for detected Hardware Profile.';
      }
    } catch (e) {
      final err = e.toString();
      if (err.contains('API key not valid')) {
        reasoningLog = 'AI Strategy Error: Your API key was rejected by Google. Please check for trailing spaces or billing issues.';
      } else {
        reasoningLog = 'AI Strategy Error: $err. Falling back to default heuristic.';
      }
    }
  }

  void _parseResponse(String text) {
    try {
      List<String> lines = text.split('\n');
      for (var line in lines) {
        if (line.contains('Small:')) policyMap['Small'] = line.split(':')[1].trim().toUpperCase();
        if (line.contains('Medium:')) policyMap['Medium'] = line.split(':')[1].trim().toUpperCase();
        if (line.contains('Large:')) policyMap['Large'] = line.split(':')[1].trim().toUpperCase();
        if (line.contains('Reasoning:')) reasoningLog = line.split(':')[1].trim();
      }
      currentStrategy = 'AI Optimized (Gemini)';
    } catch (e) {
      reasoningLog = 'Parsing Error. Strategy partially applied.';
    }
  }

  String getProtocolForTask(String taskType) {
    return policyMap[taskType] ?? 'REST';
  }
}
