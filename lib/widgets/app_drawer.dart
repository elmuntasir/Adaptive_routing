import 'package:flutter/material.dart';
import '../screens/movie_list.dart';
import '../screens/ai_agent_dashboard.dart';
import '../screens/protocol_selection_screen.dart';
import '../screens/energy_comparison.dart';
import '../screens/api_history.dart';
import '../screens/about_app.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget destination,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.greenAccent, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
      ),
      trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.white30),
      onTap: () {
        Navigator.pop(context); // Close drawer
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => destination,
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 60, bottom: 20, left: 20, right: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.greenAccent.withValues(alpha: 0.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.greenAccent.withValues(alpha: 0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.bolt, color: Colors.greenAccent, size: 40),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Green API Tracker',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Research Framework',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildDrawerItem(
                  context,
                  icon: Icons.movie_outlined,
                  title: 'Movie Browser',
                  destination: const MovieListScreen(),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.psychology_outlined,
                  title: 'Autonomous AI Agent',
                  destination: const AiAgentDashboard(),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.bolt_outlined,
                  title: 'Benchmark Suite',
                  destination: const EnergyComparisonScreen(),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.settings_input_component_outlined,
                  title: 'Protocol Selection',
                  destination: const ProtocolSelectionScreen(),
                ),
                const Divider(color: Colors.white10, height: 16, indent: 16, endIndent: 16),
                _buildDrawerItem(
                  context,
                  icon: Icons.history_outlined,
                  title: 'API History',
                  destination: const ApiHistoryScreen(),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.info_outline,
                  title: 'About & Methodology',
                  destination: const AboutAppScreen(),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.science, size: 14, color: Colors.white30),
                const SizedBox(width: 8),
                Text('v1.0.0 • Dynamic Protocol', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
