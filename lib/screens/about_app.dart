import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About & Methodology')),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Icon(Icons.menu_book_rounded, size: 64, color: Colors.greenAccent),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Energy Optimization Research',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'What is this app measuring?',
              'This application is a live testbed designed to compare the energy efficiency of REST and GraphQL APIs. It tracks every network request made while you browse movies, measures its properties, and logs its efficiency to determine which protocol performs best under certain conditions.',
              Icons.analytics_outlined,
              Colors.blueAccent,
            ),
            _buildSection(
              'Energy Proxy Model (Methodology)',
              'True hardware battery drain cannot be perfectly isolated without a physical hardware monitor. This app utilizes an Energy Proxy Model—a standard academic approach—to calculate system-wide efficiency.\n\n'
              'Crucially, our model now separates Routing Overhead (the energy cost of the AI/Heuristic decision logic) from API Execution Energy (the cost of the network request itself). This allows us to measure at what exact scale the "Saving" of a protocol switch outweighs the "Cost" of the reasoning agent.',
              Icons.bolt,
              Colors.amberAccent,
            ),
            
            _buildEquationSection(),

            _buildSection(
              'Automated Benchmark Suite',
              'The app includes a "Full Automated Workflow" that stress-tests REST, GraphQL, Heuristic, and AI-Informed modes (Balanced, Green, Performance) sequentially. This methodology ensures a controlled environment where task loads (Small/Medium/Large) are identical across all strategies for an intellectually honest comparison.',
              Icons.auto_fix_high_rounded,
              Colors.pinkAccent,
            ),

            _buildSection(
              'Why does GraphQL beat REST for "Small" tasks?',
              'When fetching a list of movies (a "Small" task), REST suffers from "over-fetching". The server blindly returns large chunks of data (heavy descriptions, cast members) even if the UI only needs the title and poster. \n\nGraphQL allows the app to request strictly what it needs { title, poster_path }. This trims the payload size drastically, resulting in a much cheaper mathematical Joule cost compared to rigid REST endpoints.',
              Icons.hub_outlined,
              Colors.purpleAccent,
            ),
             _buildSection(
              'Dynamic Adaptive Mode (AI-Powered Conscious Routing)',
              'This research project implements a "Conscious Routing Agent Layer"—an intelligent decision engine that replaces static protocol selection.\n\n'
              '1. Telemetry Capture: Before every request, the app captures a multi-dimensional context: device tier, network quality, battery level, and server load.\n\n'
              '2. LLM Reasoning: This context is sent to a Gemini 2.0 Flash-Lite agent. The agent reasons about technical trade-offs to select the most efficient protocol.\n\n'
              '3. Isolated Measurement: We strictly measure Routing Overhead separately from execution. In your papers, you can see how routing energy amortizes to near-zero as decisions are cached.\n\n'
              '4. Optimal Routing: The router instantaneously selects REST or GraphQL, prioritizing Green 🌱 (Energy) or Performance ⚡ (Latency) based on the user-selected policy.',
              Icons.auto_awesome,
              Colors.greenAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquationSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Energy Formulas', style: TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildFormula('Client (Mobile)', 'Joules = (t_exec * 0.5) + (s * 0.02)', 't = execution latency (s), s = payload size (KB)'),
          const Divider(height: 32, color: Colors.white10),
          _buildFormula('Routing Overhead', 'Joules = (t_route * 0.5)', 't = reasoning/decision time (s)'),
          const Divider(height: 32, color: Colors.white10),
          _buildFormula('Server (Cloud)', 'Joules = (CPU * 1.5) + 0.001', 'CPU = process CPU time (s)'),
          const Divider(height: 32, color: Colors.white10),
          _buildFormula('System Total', 'Joules = Client + Overhead + Server', 'The complete lifecycle cost of a conscious request'),
        ],
      ),
    );
  }

  Widget _buildFormula(String type, String formula, String key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(type, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 8),
        Text(formula, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
        const SizedBox(height: 4),
        Text(key, style: const TextStyle(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic)),
      ],
    );
  }

  Widget _buildSection(String title, String content, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 12),
          Text(content, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}
