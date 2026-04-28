import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/app_drawer.dart';
import '../services/api_history_provider.dart';

class EnergyMonitorScreen extends StatefulWidget {
  const EnergyMonitorScreen({super.key});

  @override
  State<EnergyMonitorScreen> createState() => _EnergyMonitorScreenState();
}

class _EnergyMonitorScreenState extends State<EnergyMonitorScreen> {
  final ApiHistoryProvider history = ApiHistoryProvider();

  @override
  Widget build(BuildContext context) {
    // Basic aggregation calculation for simulated energy (Joules)
    double totalJoules = 0;
    double restJoules = 0;
    double graphqlJoules = 0;

    for (var log in history.logs) {
      if (log.isSessionMarker) continue;
      double joules = log.joulesEstimated;
      totalJoules += joules;
      if (log.apiType == 'REST') {
        restJoules += joules;
      } else {
        graphqlJoules += joules;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Energy Consumption Monitor')),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildStatCard(
              'Total Simulated Carbon Footprint',
              '${totalJoules.toStringAsFixed(4)} Joules',
              Icons.energy_savings_leaf,
              Colors.greenAccent,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'REST API',
                    '${restJoules.toStringAsFixed(4)} J',
                    Icons.api,
                    Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildStatCard(
                    'GraphQL',
                    '${graphqlJoules.toStringAsFixed(4)} J',
                    Icons.hub,
                    Colors.purpleAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Text(
              'Real-time Correlation Chart (Simulated)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              height: 250,
              padding: const EdgeInsets.only(right: 20, left: 10, top: 20, bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _buildChart(),
            ),
            const SizedBox(height: 20),
            const Text(
              'Methodology: Joules_estimated = (Duration_ms / 1000) × device wattage prior by tier (not PowerAPI hardware).',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white24,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    final reversedLogs = history.logs.reversed.where((l) => !l.isSessionMarker).toList();
    if (reversedLogs.isEmpty) {
      return const Center(child: Text('No data recorded yet.', style: TextStyle(color: Colors.white54)));
    }

    final List<FlSpot> restSpots = [];
    final List<FlSpot> gqlSpots = [];
    
    double maxY = 0.0;
    int indexRest = 0;
    int indexGql = 0;

    for (var log in reversedLogs) {
      double joules = log.joulesEstimated;
      if (joules > maxY) maxY = joules;

      if (log.apiType.toUpperCase() == 'REST') {
        restSpots.add(FlSpot(indexRest.toDouble(), joules));
        indexRest++;
      } else if (log.apiType.toUpperCase() == 'GRAPHQL') {
        gqlSpots.add(FlSpot(indexGql.toDouble(), joules));
        indexGql++;
      }
    }

    if (restSpots.isEmpty && gqlSpots.isEmpty) {
      return const Center(child: Text('No dual-API data recorded yet.', style: TextStyle(color: Colors.white54)));
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.5,
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.white12, strokeWidth: 1),
          getDrawingVerticalLine: (value) => FlLine(color: Colors.white12, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(val.toStringAsFixed(3), style: const TextStyle(color: Colors.white54, fontSize: 10)),
              ),
              reservedSize: 40,
            ),
          ),
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.white12)),
        lineBarsData: [
          if (restSpots.isNotEmpty)
            LineChartBarData(
              spots: restSpots,
              isCurved: true,
              color: Colors.blueAccent,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Colors.blueAccent.withValues(alpha: 0.1)),
            ),
          if (gqlSpots.isNotEmpty)
            LineChartBarData(
              spots: gqlSpots,
              isCurved: true,
              color: Colors.purpleAccent,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Colors.purpleAccent.withValues(alpha: 0.1)),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(fontSize: 14, color: Colors.white60),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
