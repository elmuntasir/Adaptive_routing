import 'package:flutter/material.dart';
import '../app_config.dart';
import '../services/api_history_provider.dart';
import '../services/service_locator.dart';
import '../widgets/app_drawer.dart';

class ApiModeScreen extends StatefulWidget {
  const ApiModeScreen({super.key});

  @override
  State<ApiModeScreen> createState() => _ApiModeScreenState();
}

class _ApiModeScreenState extends State<ApiModeScreen> {
  String _currentMode = 'default'; // 'rest', 'graphql', 'dynamic', 'default'
  String? _dynamicRecommendation;
  late final TextEditingController _urlController;
  late final TextEditingController _apiKeyController;
  late String _selectedModel;

  static const _knownModels = {
    'gemini-3.1-flash-lite-001',
    'gemini-3.1-flash-001',
    'gemini-2.5-flash-preview-04-17',
    'gemini-2.5-flash-lite-preview-06-17',
    'gemini-2.0-flash',
    'gemini-2.0-flash-lite',
    'gemini-1.5-flash',
  };

  @override
  void initState() {
    super.initState();
    _currentMode = currentApiMode;
    _urlController = TextEditingController(text: AppConfig.backendUrl);
    _apiKeyController = TextEditingController(text: AppConfig.geminiApiKey);
    // Guard: ensure value is always in the dropdown list
    _selectedModel = _knownModels.contains(AppConfig.geminiModel)
        ? AppConfig.geminiModel
        : 'gemini-3.1-flash-lite-001';
    _computeRecommendation();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _computeRecommendation() {
    final history = ApiHistoryProvider.instance;
    if (history.logs.length < 4) {
      _dynamicRecommendation = null;
      return;
    }

    // Task-Type balanced comparison
    Map<String, List<double>> restTasks = {
      'simple_list': [],
      'detail_medium': [],
      'nested_large': [],
    };
    Map<String, List<double>> gqlTasks = {
      'simple_list': [],
      'detail_medium': [],
      'nested_large': [],
    };

    for (var log in history.logs) {
      if (log.isSessionMarker) continue;
      double joules = log.joulesEstimated;
      if (log.apiType.toUpperCase() == 'REST') {
        restTasks.putIfAbsent(log.payloadType, () => []);
        restTasks[log.payloadType]!.add(joules);
      } else {
        gqlTasks.putIfAbsent(log.payloadType, () => []);
        gqlTasks[log.payloadType]!.add(joules);
      }
    }

    double totalRestAvg = 0;
    double totalGqlAvg = 0;
    int comparableTasks = 0;

    for (String type in ['simple_list', 'detail_medium', 'nested_large']) {
      if (restTasks[type]!.isNotEmpty && gqlTasks[type]!.isNotEmpty) {
        totalRestAvg +=
            restTasks[type]!.reduce((a, b) => a + b) / restTasks[type]!.length;
        totalGqlAvg +=
            gqlTasks[type]!.reduce((a, b) => a + b) / gqlTasks[type]!.length;
        comparableTasks++;
      }
    }

    if (comparableTasks == 0) {
      _dynamicRecommendation = null;
      return;
    }

    // Final normalized averages
    double finalRest = totalRestAvg / comparableTasks;
    double finalGql = totalGqlAvg / comparableTasks;

    if (finalRest < finalGql) {
      _dynamicRecommendation =
          'REST (normalized ${((1 - finalRest / finalGql) * 100).toStringAsFixed(1)}% more efficient)';
    } else {
      _dynamicRecommendation =
          'GraphQL (normalized ${((1 - finalGql / finalRest) * 100).toStringAsFixed(1)}% more efficient)';
    }
  }

  void _selectMode(String mode) {
    setState(() {
      _currentMode = mode;
      switch (mode) {
        case 'rest':
          currentRoutingStrategy = 'rest';
          break;
        case 'graphql':
          currentRoutingStrategy = 'graphql';
          break;
        case 'default':
          currentRoutingStrategy = 'default';
          break;
        case 'balanced':
          currentRoutingStrategy = 'ai_power';
          currentOperatingMode = 'balanced';
          break;
        case 'green':
          currentRoutingStrategy = 'ai_power';
          currentOperatingMode = 'green';
          break;
        case 'performance':
          currentRoutingStrategy = 'ai_power';
          currentOperatingMode = 'performance';
          break;
        default:
          switchApiMode(mode);
      }
      syncLegacyCurrentApiMode();
    });

    // Log the session switch
    ApiHistoryProvider.instance.addSessionMarker(mode);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switched to ${mode.toUpperCase()} mode'),
        backgroundColor: _getColor(mode),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _getColor(String mode) {
    switch (mode) {
      case 'rest':
        return Colors.blueAccent;
      case 'graphql':
        return Colors.purpleAccent;
      case 'dynamic':
        return Colors.greenAccent.shade700;
      case 'default':
        return Colors.amberAccent;
      case 'green':
        return Colors.greenAccent;
      case 'performance':
        return Colors.blueAccent;
      case 'balanced':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getIcon(String mode) {
    switch (mode) {
      case 'rest':
        return Icons.api;
      case 'graphql':
        return Icons.hub;
      case 'dynamic':
        return Icons.auto_awesome;
      case 'default':
        return Icons.compare_arrows;
      case 'green':
        return Icons.eco;
      case 'performance':
        return Icons.bolt;
      case 'balanced':
        return Icons.scale;
      default:
        return Icons.settings;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'API Switching Mode',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Server Configuration
            const Text(
              'Server Configuration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Configure the backend IP address for physical devices.',
              style: TextStyle(fontSize: 13, color: Colors.white54),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: 'Backend URL',
                      labelStyle: const TextStyle(color: Colors.greenAccent),
                      hintText: 'e.g., http://192.168.1.5:5005',
                      prefixIcon: const Icon(
                        Icons.dns,
                        color: Colors.greenAccent,
                      ),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.greenAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      updateBackendUrl(_urlController.text);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Server URL Updated!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent.withValues(
                        alpha: 0.2,
                      ),
                      foregroundColor: Colors.greenAccent,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(
                        color: Colors.greenAccent,
                        width: 0.5,
                      ),
                    ),
                    child: const Text(
                      'Update Server & Reconnect',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Gemini API Key',
                      labelStyle: const TextStyle(color: Colors.blueAccent),
                      hintText: 'Enter your AIza... key',
                      prefixIcon: const Icon(
                        Icons.vpn_key,
                        color: Colors.blueAccent,
                      ),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.blueAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      updateGeminiApiKey(_apiKeyController.text);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Gemini API Key Updated!'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                      foregroundColor: Colors.blueAccent,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(
                        color: Colors.blueAccent,
                        width: 0.5,
                      ),
                    ),
                    child: const Text(
                      'Update Gemini Key',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedModel,
                    dropdownColor: Colors.black87,
                    decoration: InputDecoration(
                      labelText: 'AI Routing Model',
                      labelStyle: const TextStyle(color: Colors.purpleAccent),
                      prefixIcon: const Icon(
                        Icons.memory,
                        color: Colors.purpleAccent,
                      ),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.purpleAccent,
                        ),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'gemini-3.1-flash-lite-001',
                        child: Text(
                          'Gemini 3.1 Flash-Lite (Optimized)',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'gemini-3.1-flash-001',
                        child: Text(
                          'Gemini 3.1 Flash (High Capacity)',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'gemini-2.5-flash-preview-04-17',
                        child: Text(
                          'Gemini 2.5 Flash',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'gemini-2.0-flash',
                        child: Text(
                          'Gemini 2.0 Flash (deprecated)',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'gemini-1.5-flash',
                        child: Text(
                          'Gemini 1.5 Flash',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedModel = val);
                        updateGeminiModel(val);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('AI Model set to $val'),
                            backgroundColor: Colors.purple,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Current Mode Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getColor(_currentMode).withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _getColor(_currentMode).withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _getIcon(_currentMode),
                    size: 48,
                    color: _getColor(_currentMode),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Active Mode',
                    style: TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentMode.toUpperCase(),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _getColor(_currentMode),
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Mode Selection
            const Text(
              'Select API Mode',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Each mode creates a new session in API History for comparison.',
              style: TextStyle(fontSize: 13, color: Colors.white54),
            ),
            const SizedBox(height: 16),

            _buildModeCard(
              'rest',
              'REST API',
              'All requests use traditional REST endpoints. Best for comparing baseline performance.',
              Icons.api,
              Colors.blueAccent,
            ),
            const SizedBox(height: 12),
            _buildModeCard(
              'graphql',
              'GraphQL',
              'All requests use GraphQL queries. Fetches only the exact fields needed.',
              Icons.hub,
              Colors.purpleAccent,
            ),
            const SizedBox(height: 12),
            _buildModeCard(
              'default',
              'Default (Benchmark Builder)',
              'Executes both APIs for every request to record and build the energy comparison history.',
              Icons.compare_arrows,
              Colors.amberAccent,
            ),
            const SizedBox(height: 12),
            _buildModeCard(
              'balanced',
              'Balanced Strategy ⚖️',
              'Gemini weighs both latency and energy, favoring green when the trade-off is small.',
              Icons.scale,
              Colors.grey,
            ),
            const SizedBox(height: 12),
            _buildModeCard(
              'green',
              'Green Optimization 🌱',
              'Conscious Routing prioritized for absolute minimum battery consumption.',
              Icons.eco,
              Colors.greenAccent,
            ),
            const SizedBox(height: 12),
            _buildModeCard(
              'performance',
              'High Performance ⚡',
              'Conscious Routing prioritized for lowest latency and speed.',
              Icons.bolt,
              Colors.blueAccent,
            ),

            const SizedBox(height: 28),

            // Dynamic Recommendation
            if (_dynamicRecommendation != null) ...[
              const Text(
                'Adaptive Recommendation',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.insights,
                      color: Colors.greenAccent,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Based on your session data:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _dynamicRecommendation!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.greenAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orangeAccent,
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Switch between REST and GraphQL modes and browse movies to generate comparison data for the adaptive recommendation.',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),

            // Task Types Table
            const Text(
              'Task Type Energy Matrix',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Energy cost per task type across API protocols.',
              style: TextStyle(fontSize: 13, color: Colors.white54),
            ),
            const SizedBox(height: 12),
            _buildTaskTypeTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard(
    String mode,
    String title,
    String desc,
    IconData icon,
    Color color,
  ) {
    bool isSelected = _currentMode == mode;
    return InkWell(
      onTap: () => _selectMode(mode),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey[800]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? color : Colors.white,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.check_circle, color: color, size: 18),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskTypeTable() {
    final history = ApiHistoryProvider.instance;
    Map<String, Map<String, List<double>>> taskEnergy = {};

    for (var log in history.logs) {
      if (log.isSessionMarker) continue;
      double joules = log.joulesEstimated;
      String apiType = log.apiType.toUpperCase() == 'GRAPHQL'
          ? 'GraphQL'
          : 'REST';

      taskEnergy.putIfAbsent(
        log.requestType,
        () => {'REST': [], 'GraphQL': []},
      );
      taskEnergy[log.requestType]![apiType]?.add(joules);
    }

    if (taskEnergy.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'No data yet. Browse movies in different modes to populate.',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Task',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Text(
                    'REST (J)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.blueAccent,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'GQL (J)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.purpleAccent,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Winner',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.greenAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...taskEnergy.entries.map((entry) {
            double restAvg = entry.value['REST']!.isEmpty
                ? -1
                : entry.value['REST']!.reduce((a, b) => a + b) /
                      entry.value['REST']!.length;
            double gqlAvg = entry.value['GraphQL']!.isEmpty
                ? -1
                : entry.value['GraphQL']!.reduce((a, b) => a + b) /
                      entry.value['GraphQL']!.length;

            String winner = '-';
            Color winnerColor = Colors.white54;
            if (restAvg >= 0 && gqlAvg >= 0) {
              winner = restAvg < gqlAvg ? 'REST' : 'GraphQL';
              winnerColor = restAvg < gqlAvg
                  ? Colors.blueAccent
                  : Colors.purpleAccent;
            } else if (restAvg >= 0) {
              winner = 'REST';
              winnerColor = Colors.blueAccent;
            } else if (gqlAvg >= 0) {
              winner = 'GraphQL';
              winnerColor = Colors.purpleAccent;
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[800]!, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      restAvg >= 0 ? restAvg.toStringAsFixed(4) : '-',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      gqlAvg >= 0 ? gqlAvg.toStringAsFixed(4) : '-',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      winner,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: winnerColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
