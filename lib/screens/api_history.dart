import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import '../services/api_history_provider.dart';

class ApiHistoryScreen extends StatefulWidget {
  const ApiHistoryScreen({super.key});

  @override
  State<ApiHistoryScreen> createState() => _ApiHistoryScreenState();
}

class SessionGroup {
  final ApiRequestLog marker;
  List<ApiRequestLog> items;
  SessionGroup(this.marker, this.items);
}

class _ApiHistoryScreenState extends State<ApiHistoryScreen> {
  final ApiHistoryProvider history = ApiHistoryProvider.instance;

  List<SessionGroup> _groupLogs(List<ApiRequestLog> logs) {
    List<SessionGroup> sessions = [];
    SessionGroup? currentSession;

    for (var log in logs.reversed) {
      if (log.isSessionMarker) {
        if (currentSession != null) sessions.add(currentSession);
        currentSession = SessionGroup(log, []);
      } else {
        currentSession ??= SessionGroup(
          ApiRequestLog(
            apiType: 'INITIAL',
            payloadType: 'SESSION_START',
            timestamp: log.timestamp,
            durationMs: 0,
            sizeKb: 0,
          ),
          [],
        );
        currentSession.items.insert(0, log);
      }
    }
    if (currentSession != null) sessions.add(currentSession);

    return sessions.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API Benchmark Logs')),
      drawer: const AppDrawer(),
      body: ListenableBuilder(
        listenable: history,
        builder: (context, _) {
          final logs = history.logs;
          if (logs.isEmpty) {
            return const Center(
              child: Text(
                'No requests logged yet.',
                style: TextStyle(color: Colors.white24),
              ),
            );
          }
          final sessions = _groupLogs(logs);

          return ListView.builder(
            itemCount: sessions.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final session = sessions[index];
              return Card(
                color: Colors.white.withValues(alpha: 0.05),
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white10),
                ),
                child: ExpansionTile(
                  collapsedIconColor: Colors.white54,
                  iconColor: Colors.greenAccent,
                  initiallyExpanded: index == 0,
                  title: Text(
                    '${session.marker.apiType} Mode Execution',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.greenAccent,
                    ),
                  ),
                  subtitle: Text(
                    '${session.items.length} API Calls • ${session.marker.timestamp.toString().substring(0, 19)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  children: session.items.map((log) {
                    final isGql = log.apiType == 'GRAPHQL';
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: isGql
                            ? Colors.purpleAccent.withValues(alpha: 0.2)
                            : Colors.blueAccent.withValues(alpha: 0.2),
                        child: Icon(
                          isGql ? Icons.hub : Icons.api,
                          size: 16,
                          color: isGql
                              ? Colors.purpleAccent
                              : Colors.blueAccent,
                        ),
                      ),
                      title: Text(
                        log.payloadType,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        '${log.apiType} • ${log.timestamp.toString().substring(11, 19)}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${log.durationMs} ms',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${((log.durationMs / 1000) * 0.5 + log.sizeKb * 0.02).toStringAsFixed(4)}J',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.greenAccent,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
