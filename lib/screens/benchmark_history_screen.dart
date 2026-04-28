import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../routing/benchmark_session.dart';
import '../routing/benchmark_session_store.dart';
import 'package:intl/intl.dart';

class BenchmarkHistoryScreen extends StatefulWidget {
  const BenchmarkHistoryScreen({super.key});

  @override
  State<BenchmarkHistoryScreen> createState() => _BenchmarkHistoryScreenState();
}

class _BenchmarkHistoryScreenState extends State<BenchmarkHistoryScreen> {
  List<BenchmarkSession>? _sessions;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await BenchmarkSessionStore.instance.getAllSessions();
    setState(() {
      _sessions = sessions;
    });
  }

  void _copyCsv(BenchmarkSession session) {
    Clipboard.setData(ClipboardData(text: session.csvContent)).then((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV for "${session.name}" copied to clipboard!'),
          backgroundColor: Colors.greenAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Benchmark History'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.pinkAccent),
            tooltip: 'Clear All',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1A1A1A),
                  title: const Text('Clear All Sessions?', style: TextStyle(color: Colors.white)),
                  content: const Text('This will permanently delete all stored benchmark data.', style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
                    TextButton(
                      onPressed: () async {
                        await BenchmarkSessionStore.instance.clearAll();
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        _loadSessions();
                      },
                      child: const Text('CLEAR ALL', style: TextStyle(color: Colors.pinkAccent)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _sessions == null
          ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
          : _sessions!.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _sessions!.length,
                  itemBuilder: (context, index) {
                    final session = _sessions![index];
                    return _buildSessionCard(session);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          const Text('No sessions recorded yet.', style: TextStyle(color: Colors.white38)),
          const SizedBox(height: 8),
          const Text('Run a benchmark to see history here.', style: TextStyle(color: Colors.white24, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSessionCard(BenchmarkSession session) {
    final dateStr = DateFormat('MMM dd, yyyy · HH:mm').format(session.timestamp);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getModeColor(session.mode).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_getModeIcon(session.mode), color: _getModeColor(session.mode), size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 20),
                    onPressed: () async {
                      await BenchmarkSessionStore.instance.deleteSession(session.id);
                      _loadSessions();
                    },
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white.withValues(alpha: 0.02),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniStat('${session.requestCount}', 'Requests'),
                  _buildMiniStat('${session.totalJoules.toStringAsFixed(2)} J', 'Energy'),
                  ElevatedButton.icon(
                    onPressed: () => _copyCsv(session),
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    label: const Text('CSV'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent.withValues(alpha: 0.1),
                      foregroundColor: Colors.greenAccent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: const TextStyle(color: Colors.white24, fontSize: 9, letterSpacing: 0.5)),
      ],
    );
  }

  Color _getModeColor(String mode) {
    if (mode.contains('Full')) return Colors.orangeAccent;
    if (mode.contains('AI')) return Colors.purpleAccent;
    if (mode.contains('REST')) return Colors.blueAccent;
    if (mode.contains('GraphQL')) return Colors.pinkAccent;
    return Colors.greenAccent;
  }

  IconData _getModeIcon(String mode) {
    if (mode.contains('Full')) return Icons.auto_mode_rounded;
    if (mode.contains('AI')) return Icons.auto_awesome;
    if (mode.contains('REST')) return Icons.lan_outlined;
    if (mode.contains('GraphQL')) return Icons.account_tree_outlined;
    return Icons.speed_rounded;
  }
}
