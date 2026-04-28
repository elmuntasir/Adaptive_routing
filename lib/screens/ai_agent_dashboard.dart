import 'package:flutter/material.dart';
import '../app_config.dart';
import '../routing/device_profiler.dart';
import '../services/ai_agent_service.dart';
import '../widgets/app_drawer.dart';
import '../routing/ai_policy_store.dart';
import 'dart:async';

class AiAgentDashboard extends StatefulWidget {
  const AiAgentDashboard({super.key});

  @override
  State<AiAgentDashboard> createState() => _AiAgentDashboardState();
}

class _AiAgentDashboardState extends State<AiAgentDashboard> {
  final List<String> _thoughtLogs = [];
  Timer? _timer;
  String? _lastLog;

  @override
  void initState() {
    super.initState();
    _thoughtLogs.add('Initializing Gemini Agent Core...');
    _thoughtLogs.add('Current Strategy: ${AiAgentService.instance.currentStrategy}');
    _startAutonomousCycle();
  }

  void _addThought(String thought) {
    if (!mounted || thought == _lastLog) return;
    _lastLog = thought;
    setState(() {
      _thoughtLogs.insert(0, '[${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}] $thought');
      if (_thoughtLogs.length > 50) _thoughtLogs.removeLast();
    });
  }

  void _startAutonomousCycle() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      _addThought(AiAgentService.instance.reasoningLog);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Autonomous AI Agent'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // Agent Status Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.greenAccent.withValues(alpha: 0.1), Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    const SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: 0.8,
                        color: Colors.greenAccent,
                        strokeWidth: 2,
                      ),
                    ),
                    const Icon(Icons.psychology, size: 40, color: Colors.greenAccent),
                  ],
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AGENT CORE STATUS', style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 2)),
                      const SizedBox(height: 4),
                      Text(AiAgentService.instance.currentStrategy.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Policy: ${AiAgentService.instance.policyMap.values.toSet().join("/")}', style: const TextStyle(color: Colors.greenAccent, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Environment Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                FutureBuilder<String>(
                  future: DeviceProfiler.instance.getDeviceSignature(),
                  builder: (context, snapshot) {
                    return _buildStat('Target Device', snapshot.data?.split('(').first.trim() ?? 'Detecting...', Icons.smartphone_rounded, Colors.green);
                  }
                ),
                const SizedBox(width: 12),
                _buildStat('Intelligence', AppConfig.geminiModel.split('-').skip(1).take(2).join(' ').toUpperCase(), Icons.auto_awesome, Colors.purple),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      _addThought('Manual re-scan triggered...');
                      await AiAgentService.instance.reInitialize();
                    },
                    icon: const Icon(Icons.refresh_rounded, color: Colors.blueAccent),
                    label: const Text('Re-Scan & Optimize', style: TextStyle(color: Colors.blueAccent)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await AiPolicyStore.instance.clear();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('AI policy cache cleared.'),
                          backgroundColor: Colors.greenAccent,
                        ),
                      );
                    },
                    icon: const Icon(Icons.delete_sweep_rounded, color: Colors.pinkAccent),
                    label: const Text('Reset Cache', style: TextStyle(color: Colors.pinkAccent)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Thought Log
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.terminal, size: 16, color: Colors.greenAccent),
                      SizedBox(width: 8),
                      Text('AGENT REASONING LOG', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _thoughtLogs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _thoughtLogs[index],
                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
