import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';

class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> tasks = [
      {'title': 'Phase 1: REST/GraphQL Backend Setup', 'completed': true},
      {'title': 'Phase 2: Shared UI Framework & Models', 'completed': true},
      {'title': 'Phase 3: Python Benchmarking Script (1k Cycles)', 'completed': true},
      {'title': 'Phase 4: Adaptive API Gateway Prototype', 'completed': true},
      {'title': 'Phase 5: Energy Analysis Results Plotting', 'completed': true},
      {'title': 'Phase 6: Final Research Submission', 'completed': true},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Research Tasks')),
      drawer: const AppDrawer(),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return Card(
            child: ListTile(
              leading: Icon(
                task['completed'] ? Icons.check_circle : Icons.radio_button_unchecked,
                color: task['completed'] ? Colors.greenAccent : Colors.white24,
              ),
              title: Text(task['title']),
              subtitle: Text(task['completed'] ? 'Completed' : 'Pending', style: const TextStyle(fontSize: 12)),
            ),
          );
        },
      ),
    );
  }
}
