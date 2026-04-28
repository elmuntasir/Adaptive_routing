import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import '../app_state.dart';
import '../routing/ai_policy_store.dart';

class ModeToggle extends StatefulWidget {
  const ModeToggle({super.key});

  @override
  State<ModeToggle> createState() => _ModeToggleState();
}

class _ModeToggleState extends State<ModeToggle> {
  final Battery _battery = Battery();
  
  @override
  void initState() {
    super.initState();
    _battery.onBatteryStateChanged.listen((BatteryState state) async {
       final level = await _battery.batteryLevel;
       if (level < 20 && currentOperatingMode != 'green') {
          _switchMode('green', auto: true);
       }
    });
  }

  void _switchMode(String mode, {bool auto = false}) {
    setState(() {
      switchApiMode(mode);
    });

    AiPolicyStore.instance.clear();

    if (auto && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Battery low — switched to Green Mode 🌱'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Color activeColor;
    IconData activeIcon;

    switch (currentOperatingMode) {
      case 'green':
        activeColor = Colors.greenAccent;
        activeIcon = Icons.eco;
        break;
      case 'performance':
        activeColor = Colors.blueAccent;
        activeIcon = Icons.bolt;
        break;
      case 'balanced':
        activeColor = Colors.grey;
        activeIcon = Icons.scale;
        break;
      default:
        activeColor = Colors.amberAccent;
        activeIcon = Icons.compare_arrows;
    }

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: PopupMenuButton<String>(
        onSelected: _switchMode,
        icon: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: activeColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: activeColor.withValues(alpha: 0.3)),
          ),
          child: Icon(activeIcon, color: activeColor, size: 20),
        ),
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value: 'green',
            child: Row(
              children: [
                const Icon(Icons.eco, color: Colors.greenAccent, size: 20),
                const SizedBox(width: 8),
                const Text('Green Mode 🌱'),
                if (currentOperatingMode == 'green') const Spacer(),
                if (currentOperatingMode == 'green') const Icon(Icons.check, size: 16),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'performance',
            child: Row(
              children: [
                const Icon(Icons.bolt, color: Colors.blueAccent, size: 20),
                const SizedBox(width: 8),
                const Text('Performance ⚡'),
                if (currentOperatingMode == 'performance') const Spacer(),
                if (currentOperatingMode == 'performance') const Icon(Icons.check, size: 16),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'balanced',
            child: Row(
              children: [
                const Icon(Icons.scale, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                const Text('Balanced ⚖️'),
                if (currentOperatingMode == 'balanced') const Spacer(),
                if (currentOperatingMode == 'balanced') const Icon(Icons.check, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
