import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/app_drawer.dart';
import '../services/api_history_provider.dart';
import '../services/service_locator.dart';
import '../routing/device_profiler.dart';
import '../app_config.dart';
import '../routing/heuristic_learning_store.dart';
import '../routing/benchmark_session.dart';
import '../routing/benchmark_session_store.dart';
import 'benchmark_history_screen.dart';

class BenchmarkResult {
  final double clientJoules;
  final double serverJoules;
  final double routingOverheadJoules; // New field
  final Map<String, double> clientJoulesByTask;
  final Map<String, double> serverJoulesByTask;
  final Map<String, Map<String, int>> selectionsByTask;

  BenchmarkResult({
    required this.clientJoules,
    required this.serverJoules,
    this.routingOverheadJoules = 0.0,
    required this.clientJoulesByTask,
    required this.serverJoulesByTask,
    required this.selectionsByTask,
  });
}

class EnergyComparisonScreen extends StatefulWidget {
  const EnergyComparisonScreen({super.key});

  @override
  State<EnergyComparisonScreen> createState() => _EnergyComparisonScreenState();
}

class _EnergyComparisonScreenState extends State<EnergyComparisonScreen> {
  bool _isRunningTest = false;
  String _currentTestMode = '';
  double _progress = 0.0;
  final List<double> _pulseData = List.filled(25, 2.0, growable: true);
  String _lastLog = 'Ready to Benchmark...';
  String _workflowDetail = '';

  final TextEditingController _cyclesPerComboController = TextEditingController(
    text: '30',
  );

  final TextEditingController _smallController = TextEditingController(
    text: '40',
  );
  final TextEditingController _mediumController = TextEditingController(
    text: '30',
  );
  final TextEditingController _largeController = TextEditingController(
    text: '30',
  );

  final FocusNode _smallFocus = FocusNode();
  final FocusNode _mediumFocus = FocusNode();
  final FocusNode _largeFocus = FocusNode();

  BenchmarkResult? _restResult;
  BenchmarkResult? _gqlResult;
  BenchmarkResult? _heuristicResult;
  BenchmarkResult? _aiInformedResult;
  BenchmarkResult? _balancedResult;
  BenchmarkResult? _greenResult;
  BenchmarkResult? _performanceResult;

  String _benchOperatingMode = 'balanced';
  String _benchStrategy = 'rest';

  @override
  void initState() {
    super.initState();
    _benchOperatingMode = currentOperatingMode;
    _benchStrategy = currentRoutingStrategy;
  }

  @override
  void dispose() {
    _cyclesPerComboController.dispose();
    _smallController.dispose();
    _mediumController.dispose();
    _largeController.dispose();
    _smallFocus.dispose();
    _mediumFocus.dispose();
    _largeFocus.dispose();
    super.dispose();
  }

  Future<void> _runBenchmark() async {
    if (_isRunningTest) return;

    final int smallCount = int.tryParse(_smallController.text) ?? 0;
    final int mediumCount = int.tryParse(_mediumController.text) ?? 0;
    final int largeCount = int.tryParse(_largeController.text) ?? 0;
    final int totalCount = smallCount + mediumCount + largeCount;

    if (totalCount == 0) return;

    setState(() {
      _isRunningTest = true;
      _currentTestMode = _benchStrategy;
      _progress = 0.0;
      _workflowDetail = '';
    });

    final prevStrategy = currentRoutingStrategy;
    final prevMode = currentOperatingMode;
    currentRoutingStrategy = _benchStrategy;
    currentOperatingMode = _benchOperatingMode;
    syncLegacyCurrentApiMode();

    int snapshotLengthBefore = ApiHistoryProvider.instance.logs.length;

    for (int i = 0; i < totalCount; i++) {
      if (i < smallCount) {
        await apiService.getMovies();
      } else if (i < smallCount + mediumCount) {
        await apiService.getMovieDetail('1');
      } else {
        await apiService.getMovieFull('1');
      }

      setState(() {
        _progress = (i + 1) / totalCount;
        final logs = ApiHistoryProvider.instance.logs;
        if (logs.isNotEmpty) {
          final lastEntry = logs.first;
          final j = lastEntry.joulesEstimated;

          _pulseData.removeAt(0);
          _pulseData.add((j * 150).clamp(2.0, 50.0));

          _lastLog =
              '[${lastEntry.apiType}] ${lastEntry.payloadType} - ${j.toStringAsFixed(4)}J';
        }
      });
      await Future.delayed(const Duration(milliseconds: 10));
    }

    final history = ApiHistoryProvider.instance;
    final int newLogsCount = history.logs.length - snapshotLengthBefore;
    final testLogs = history.logs.take(newLogsCount);

    double totalJoules = 0;
    double totalOverheadJoules = 0;
    Map<String, double> jByTask = {
      'simple_list': 0.0,
      'detail_medium': 0.0,
      'nested_large': 0.0,
    };
    Map<String, Map<String, int>> selByTask = {
      'simple_list': {'REST': 0, 'GRAPHQL': 0},
      'detail_medium': {'REST': 0, 'GRAPHQL': 0},
      'nested_large': {'REST': 0, 'GRAPHQL': 0},
    };

    final wattPrior = await _clientWattagePrior();
    for (var log in testLogs) {
      if (!log.isSessionMarker) {
        final j = log.joulesEstimated;
        totalJoules += j;

        final oj = (log.routingOverheadMs / 1000) * wattPrior;
        totalOverheadJoules += oj;

        String tType = log.payloadType;
        if (!jByTask.containsKey(tType)) tType = 'simple_list';

        jByTask[tType] = (jByTask[tType] ?? 0.0) + j;
        String api = log.apiType.toUpperCase();
        selByTask[tType]![api] = (selByTask[tType]![api] ?? 0) + 1;
      }
    }

    double totalServerJoules = 0;
    Map<String, double> sByTask = {
      'simple_list': 0.0,
      'detail_medium': 0.0,
      'nested_large': 0.0,
    };

    try {
      final configBase = AppConfig.backendUrl;
      final response = await http.get(
        Uri.parse('$configBase/api/server-metrics?count=$totalCount'),
      );

      if (response.statusCode == 200) {
        final List metrics = jsonDecode(response.body);
        for (var m in metrics) {
          double sj = m['joules'] ?? 0.0;
          totalServerJoules += sj;
          String tType = m['task_type'] as String;
          if (tType == 'Small') tType = 'simple_list';
          if (tType == 'Medium') tType = 'detail_medium';
          if (tType == 'Large') tType = 'nested_large';
          if (tType == 'Ultra') tType = 'ultra_all';
          sByTask[tType] = (sByTask[tType] ?? 0.0) + sj;
        }
      }
    } catch (e) {
      totalServerJoules = totalCount * 0.002;
    }

    final result = BenchmarkResult(
      clientJoules: totalJoules,
      serverJoules: totalServerJoules,
      routingOverheadJoules: totalOverheadJoules,
      clientJoulesByTask: jByTask,
      serverJoulesByTask: sByTask,
      selectionsByTask: selByTask,
    );

    setState(() {
      _isRunningTest = false;
      _currentTestMode = '';
      final mode = _benchStrategy;
      if (mode == 'rest') _restResult = result;
      if (mode == 'graphql') _gqlResult = result;
      if (mode == 'heuristic') _heuristicResult = result;
      if (mode == 'ai_power' && _benchOperatingMode == 'balanced') {
        _balancedResult = result;
        _aiInformedResult = result;
      }
      if (mode == 'ai_power' && _benchOperatingMode == 'green') {
        _greenResult = result;
        _aiInformedResult = result;
      }
      if (mode == 'ai_power' && _benchOperatingMode == 'performance') {
        _performanceResult = result;
        _aiInformedResult = result;
      }
    });

    currentRoutingStrategy = prevStrategy;
    currentOperatingMode = prevMode;
    syncLegacyCurrentApiMode();

    // AUTO-SAVE SESSION
    await _saveRunAsSession(
      logs: testLogs.toList(),
      strategy: _benchStrategy,
      mode: _benchOperatingMode,
      totalJoules: totalJoules,
      requestCount: totalCount,
    );
  }

  Future<void> _saveRunAsSession({
    required List<dynamic> logs, // List<RoutingLog> from ApiHistoryProvider
    required String strategy,
    required String mode,
    required double totalJoules,
    required int requestCount,
  }) async {
    final csv = StringBuffer();
    csv.writeln(
      'Timestamp,Strategy,Mode,Task_Type,API_Type,Duration_ms,Overhead_ms,Size_kb,Joules_estimated,Device_Tier,Network_Type,Mode_Conflict,AI_Decision_Source,AI_Reasoning',
    );

    for (var log in logs.reversed) {
      if (log.isSessionMarker) continue;
      final esc = log.aiReasoning.replaceAll('"', '""');
      csv.writeln(
        '${log.timestamp.toIso8601String()},'
        '${log.routingStrategy},'
        '${log.optimizationMode},'
        '${log.payloadType},'
        '${log.apiType},'
        '${log.durationMs},'
        '${log.routingOverheadMs},'
        '${log.sizeKb.toStringAsFixed(4)},'
        '${log.joulesEstimated.toStringAsFixed(6)},'
        '${log.deviceTier},'
        '${log.networkType},'
        '${log.modeConflict},'
        '${log.aiDecisionSource},'
        '"$esc"',
      );
    }

    final session = BenchmarkSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '${_workflowStrategyLabel(strategy)} Run',
      timestamp: DateTime.now(),
      mode: _workflowModeLabel(mode),
      csvContent: csv.toString(),
      requestCount: requestCount,
      totalJoules: totalJoules,
    );

    await BenchmarkSessionStore.instance.saveSession(session);
  }

  String _workflowStrategyLabel(String strategy) {
    switch (strategy) {
      case 'ai_power':
        return 'AI Power';
      case 'graphql':
        return 'GraphQL';
      case 'heuristic':
        return 'Heuristic';
      case 'autonomous':
        return 'Full Autonomous';
      default:
        return strategy.toUpperCase();
    }
  }

  String _workflowModeLabel(String mode) {
    switch (mode) {
      case 'green':
        return 'Green Mode';
      case 'performance':
        return 'Performance Mode';
      case 'balanced':
        return 'Balanced Mode';
      case 'multi':
        return 'Omni-Optimization';
      default:
        return mode;
    }
  }

  Future<double> _clientWattagePrior() async {
    final tier = await DeviceProfiler.instance.getDeviceTier();
    switch (tier) {
      case DeviceTier.budget:
        return 0.8;
      case DeviceTier.mid:
        return 0.6;
      case DeviceTier.flagship:
        return 0.45;
    }
  }

  Widget _buildTopButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildModeSelectButton(
                'BALANCED',
                'balanced',
                Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildModeSelectButton(
                'GREEN',
                'green',
                Colors.greenAccent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildModeSelectButton(
                'PERFORM',
                'performance',
                Colors.lightBlueAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStrategySelectButton(
                'REST',
                'rest',
                Colors.blueAccent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStrategySelectButton(
                'GQL',
                'graphql',
                Colors.purpleAccent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStrategySelectButton(
                'HEURISTIC',
                'heuristic',
                Colors.amberAccent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStrategySelectButton(
                'AI POWER',
                'ai_power',
                Colors.pinkAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _isRunningTest ? null : _runBenchmark,
          icon: const Icon(Icons.play_circle_fill_rounded),
          label: Text(
            'RUN BENCHMARK (${_workflowStrategyLabel(_benchStrategy)} / ${_workflowModeLabel(_benchOperatingMode)})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            backgroundColor: Colors.white12,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        // Automated Workflow Button
        ElevatedButton.icon(
          onPressed: _isRunningTest ? null : _runFullAutomatedWorkflow,
          icon: const Icon(Icons.auto_fix_high_rounded),
          label: const Text(
            'RUN FULL AUTOMATED WORKFLOW',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.greenAccent.withValues(alpha: 0.1),
            foregroundColor: Colors.greenAccent,
            side: const BorderSide(color: Colors.greenAccent, width: 2),
            minimumSize: const Size(double.infinity, 60),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _runFullAutomatedWorkflow() async {
    if (_isRunningTest) return;

    final cycles = int.tryParse(_cyclesPerComboController.text) ?? 30;
    final modes = ['balanced', 'green', 'performance'];
    final strategies = ['rest', 'graphql', 'heuristic', 'ai_power'];
    const payloads = ['simple_list', 'detail_medium', 'nested_large'];

    ApiHistoryProvider.instance.clearLogs();

    const totalCombos = 36;
    int comboIndex = 0;

    setState(() {
      _isRunningTest = true;
      _progress = 0;
      _workflowDetail = 'Starting…';
    });

    final prevStrategy = currentRoutingStrategy;
    final prevMode = currentOperatingMode;

    try {
      for (final mode in modes) {
        for (final strategy in strategies) {
          for (final payload in payloads) {
            comboIndex++;
            if (!mounted) return;

            setState(() {
              _workflowDetail =
                  'Testing: ${_workflowStrategyLabel(strategy)} / ${_workflowModeLabel(mode)} / $payload... ($comboIndex/$totalCombos combinations)';
            });

            currentOperatingMode = mode;
            currentRoutingStrategy = strategy;
            syncLegacyCurrentApiMode();

            for (int i = 0; i < cycles; i++) {
              switch (payload) {
                case 'simple_list':
                  await apiService.getMovies();
                  break;
                case 'detail_medium':
                  await apiService.getMovieDetail('1');
                  break;
                case 'nested_large':
                  await apiService.getMovieFull('1');
                  break;
              }
              setState(() {
                _progress =
                    ((comboIndex - 1) * cycles + i + 1) /
                    (totalCombos * cycles);
              });
            }

            await Future.delayed(const Duration(seconds: 2));
          }
        }
      }

      if (mounted) {
        // Calculate totals for the automated run
        double automatedTotalJoules = 0;
        final history = ApiHistoryProvider.instance;
        for (var log in history.logs) {
          if (!log.isSessionMarker) automatedTotalJoules += log.joulesEstimated;
        }

        await _saveRunAsSession(
          logs: history.logs.toList(),
          strategy: 'autonomous',
          mode: 'multi',
          totalJoules: automatedTotalJoules,
          requestCount: totalCombos * cycles,
        );

        _exportResultsToCSV();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Workflow complete. ${totalCombos * cycles} rows ready (exported to clipboard).',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      currentRoutingStrategy = prevStrategy;
      currentOperatingMode = prevMode;
      syncLegacyCurrentApiMode();
      if (mounted) {
        setState(() {
          _isRunningTest = false;
          _workflowDetail = '';
        });
      }
    }
  }

  Widget _buildModeSelectButton(String label, String mode, Color color) {
    final selected = _benchOperatingMode == mode;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: selected
            ? color.withValues(alpha: 0.35)
            : color.withValues(alpha: 0.2),
        foregroundColor: color,
        side: BorderSide(
          color: color.withValues(alpha: 0.5),
          width: selected ? 2 : 1,
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: _isRunningTest
          ? null
          : () => setState(() => _benchOperatingMode = mode),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStrategySelectButton(
    String label,
    String strategy,
    Color color,
  ) {
    final selected = _benchStrategy == strategy;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: selected
            ? color.withValues(alpha: 0.35)
            : color.withValues(alpha: 0.2),
        foregroundColor: color,
        side: BorderSide(
          color: color.withValues(alpha: 0.5),
          width: selected ? 2 : 1,
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: _isRunningTest
          ? null
          : () => setState(() => _benchStrategy = strategy),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildInputFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildCountField(
                'Small',
                _smallController,
                _smallFocus,
                Colors.blueAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCountField(
                'Medium',
                _mediumController,
                _mediumFocus,
                Colors.amberAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCountField(
                'Large',
                _largeController,
                _largeFocus,
                Colors.redAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPresetChip('LIGHT (30)', 10, 10, 10),
            const SizedBox(width: 8),
            _buildPresetChip('BALANCED (100)', 40, 30, 30),
            const SizedBox(width: 8),
            _buildPresetChip('HEAVY (300)', 100, 100, 100),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cyclesPerComboController,
          keyboardType: const TextInputType.numberWithOptions(
            signed: false,
            decimal: false,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          enabled: !_isRunningTest,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Cycles per combination (full automated workflow)',
            labelStyle: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 12,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip(String label, int s, int m, int l) {
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
      backgroundColor: Colors.white10,
      onPressed: _isRunningTest
          ? null
          : () {
              setState(() {
                _smallController.text = s.toString();
                _mediumController.text = m.toString();
                _largeController.text = l.toString();
              });
            },
    );
  }

  Widget _buildCountField(
    String label,
    TextEditingController controller,
    FocusNode node,
    Color color,
  ) {
    return Column(
      key: ValueKey('lbl_col_$label'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: ValueKey('txt_$label'),
          controller: controller,
          focusNode: node,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: false,
            signed: false,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          enabled: !_isRunningTest,
          style: TextStyle(
            fontSize: 14,
            color: _isRunningTest ? Colors.white24 : Colors.white,
          ),
          onEditingComplete: () => setState(() {}),
          onTapOutside: (_) {
            node.unfocus();
            setState(() {});
          },
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 12,
            ),
            suffixIcon: _isRunningTest
                ? null
                : IconButton(
                    icon: const Icon(
                      Icons.clear_rounded,
                      size: 14,
                      color: Colors.white24,
                    ),
                    onPressed: () {
                      controller.clear();
                      setState(() {});
                    },
                  ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: color),
              borderRadius: BorderRadius.circular(8),
            ),
            disabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.white10),
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: _isRunningTest
                ? Colors.white.withValues(alpha: 0.02)
                : color.withValues(alpha: 0.05),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsDashboard() {
    int s = int.tryParse(_smallController.text) ?? 0;
    int m = int.tryParse(_mediumController.text) ?? 0;
    int l = int.tryParse(_largeController.text) ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Metric (J)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'REST',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.blueAccent,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'GQL',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.purpleAccent,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'HEU',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.amberAccent,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'AI',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.pinkAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),

          _buildMetricMetricRow(
            'TOTAL API',
            _restResult,
            _gqlResult,
            _heuristicResult,
            _aiInformedResult,
          ),
          _buildMetricMetricRow(
            'OVERHEAD (J)',
            _restResult,
            _gqlResult,
            _heuristicResult,
            _aiInformedResult,
            showOverhead: true,
          ),
          _buildMetricMetricRow(
            'simple_list (x$s)',
            _restResult,
            _gqlResult,
            _heuristicResult,
            _aiInformedResult,
            task: 'simple_list',
          ),
          _buildMetricMetricRow(
            'detail_medium (x$m)',
            _restResult,
            _gqlResult,
            _heuristicResult,
            _aiInformedResult,
            task: 'detail_medium',
          ),
          _buildMetricMetricRow(
            'nested_large (x$l)',
            _restResult,
            _gqlResult,
            _heuristicResult,
            _aiInformedResult,
            task: 'nested_large',
          ),

          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.copy_all, size: 16),
                  label: const Text('Export Latest Logs (CSV)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white10,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 45),
                  ),
                  onPressed: _exportResultsToCSV,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _isRunningTest
                      ? null
                      : () async {
                          await HeuristicLearningStore.instance.clear();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Heuristic REST baseline history cleared.',
                              ),
                              backgroundColor: Colors.amberAccent,
                            ),
                          );
                        },
                  icon: const Icon(
                    Icons.restart_alt_rounded,
                    size: 18,
                    color: Colors.amberAccent,
                  ),
                  label: const Text(
                    'Reset Heuristic History',
                    style: TextStyle(color: Colors.amberAccent),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricMetricRow(
    String label,
    BenchmarkResult? r,
    BenchmarkResult? g,
    BenchmarkResult? h,
    BenchmarkResult? ai, {
    String? task,
    bool showOverhead = false,
  }) {
    double? getVal(BenchmarkResult? res) {
      if (res == null) return null;
      if (showOverhead) return res.routingOverheadJoules;
      if (task == null) return res.clientJoules + res.serverJoules;
      return (res.clientJoulesByTask[task] ?? 0) +
          (res.serverJoulesByTask[task] ?? 0);
    }

    final rv = getVal(r);
    final gv = getVal(g);
    final hv = getVal(h);
    final aiv = getVal(ai);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              rv?.toStringAsFixed(3) ?? '-',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.blueAccent, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              gv?.toStringAsFixed(3) ?? '-',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.purpleAccent, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              hv?.toStringAsFixed(3) ?? '-',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              aiv?.toStringAsFixed(3) ?? '-',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.pinkAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionPanel(int totalCalls) {
    if (_balancedResult == null ||
        _restResult == null ||
        _gqlResult == null ||
        totalCalls == 0) {
      return const SizedBox.shrink();
    }

    double aiTotal =
        _balancedResult!.clientJoules + _balancedResult!.serverJoules;
    double restTotal = _restResult!.clientJoules + _restResult!.serverJoules;
    double gqlTotal = _gqlResult!.clientJoules + _gqlResult!.serverJoules;

    double staticWinner = restTotal < gqlTotal ? restTotal : gqlTotal;
    double savedJoules = staticWinner - aiTotal;

    // Safety clamp in case of strategy variance
    if (savedJoules < 0) savedJoules = 0;

    double savedPerCall = savedJoules / totalCalls;
    double extrapolated1M = savedPerCall * 1000000;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Text(
            'At-Scale Server Extrapolation',
            style: TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  const Text(
                    'Saved locally:',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  Text(
                    '${savedJoules.toStringAsFixed(3)} J',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  const Text(
                    'Est. savings (1M req):',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  Text(
                    '${(extrapolated1M / 1000).toStringAsFixed(1)} kJ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.greenAccent,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _exportResultsToCSV() {
    final history = ApiHistoryProvider.instance;
    if (history.logs.isEmpty) return;

    final csv = StringBuffer();
    csv.writeln(
      'Timestamp,Strategy,Mode,Task_Type,API_Type,Duration_ms,Overhead_ms,Size_kb,Joules_estimated,Device_Tier,Network_Type,Mode_Conflict,AI_Decision_Source,AI_Reasoning',
    );

    final recentLogs = history.logs.reversed
        .take(5000)
        .toList()
        .reversed
        .where((l) => !l.isSessionMarker);

    for (final log in recentLogs) {
      final esc = log.aiReasoning.replaceAll('"', '""');
      csv.writeln(
        '${log.timestamp.toIso8601String()},'
        '${log.routingStrategy},'
        '${log.optimizationMode},'
        '${log.payloadType},'
        '${log.apiType},'
        '${log.durationMs},'
        '${log.routingOverheadMs},'
        '${log.sizeKb.toStringAsFixed(4)},'
        '${log.joulesEstimated.toStringAsFixed(6)},'
        '${log.deviceTier},'
        '${log.networkType},'
        '${log.modeConflict},'
        '${log.aiDecisionSource},'
        '"$esc"',
      );
    }

    Clipboard.setData(ClipboardData(text: csv.toString())).then((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Raw Benchmark Data copied to Clipboard (CSV)! Paste into Excel or Sheets.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    });
  }

  Widget _buildLiveMonitor() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LIVE PULSE',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              Text(
                _lastLog,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(_pulseData.length, (index) {
              final val = _pulseData[index];
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  height: val,
                  decoration: BoxDecoration(
                    color: index == _pulseData.length - 1
                        ? Colors.greenAccent
                        : Colors.greenAccent.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _clearResults() {
    setState(() {
      _restResult = null;
      _gqlResult = null;
      _heuristicResult = null;
      _balancedResult = null;
      _greenResult = null;
      _performanceResult = null;
      _pulseData.fillRange(0, _pulseData.length, 2.0);
      _lastLog = 'Dashboard Reset';
    });
  }

  void _showHistoryLogs() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'RAW REQUEST HISTORY',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: ApiHistoryProvider.instance.logs.length,
                itemBuilder: (context, idx) {
                  final log = ApiHistoryProvider.instance.logs[idx];
                  if (log.isSessionMarker) {
                    return const Divider(color: Colors.white10);
                  }
                  return ListTile(
                    dense: true,
                    leading: Text(
                      log.apiType,
                      style: TextStyle(
                        color: log.apiType == 'REST'
                            ? Colors.blueAccent
                            : Colors.purpleAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    title: Text(log.payloadType),
                    subtitle: Text(
                      '${log.durationMs}ms | ${log.sizeKb.toStringAsFixed(2)}KB',
                    ),
                    trailing: Text(
                      '${log.joulesEstimated.toStringAsFixed(4)}J',
                      style: const TextStyle(color: Colors.greenAccent),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int s = int.tryParse(_smallController.text) ?? 0;
    int m = int.tryParse(_mediumController.text) ?? 0;
    int l = int.tryParse(_largeController.text) ?? 0;
    int total = s + m + l;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Energy Benchmark Suite'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.greenAccent),
            tooltip: 'Benchmark History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (c) => const BenchmarkHistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
            tooltip: 'Clear Results',
            onPressed: _clearResults,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configure Benchmark',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Set the number of calls for each task type to simulate a real-world workload.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),

            _buildInputFields(),

            const SizedBox(height: 24),
            _buildLiveMonitor(),

            const SizedBox(height: 24),
            const Text(
              'Trigger Benchmark',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            _buildTopButtons(),

            const SizedBox(height: 20),
            if (_isRunningTest) ...[
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.white12,
                color: Colors.greenAccent,
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _workflowDetail.isNotEmpty
                      ? '$_workflowDetail  ${(_progress * 100).toInt()}%'
                      : 'Running $total calls... ${(_progress * 100).toInt()}%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ],

            const SizedBox(height: 24),
            const Text(
              'Results Dashboard',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            _buildResultsDashboard(),
            _buildPredictionPanel(total),

            const SizedBox(height: 20),
            const Text(
              '* Dynamic mode utilizes historical data to automatically route the request through the most efficient protocol for that specific task type.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
