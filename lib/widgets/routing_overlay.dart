import 'package:flutter/material.dart';
import '../routing/conscious_router.dart';

class RoutingOverlay {
  static void show(OverlayState overlay, RoutingDecision decision) {
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () => entry.remove(),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: decision.api == ApiDecision.graphql
                      ? Colors.purpleAccent.withValues(alpha: 0.5)
                      : Colors.blueAccent.withValues(alpha: 0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            decision.api == ApiDecision.graphql ? Icons.hub : Icons.api,
                            color: decision.api == ApiDecision.graphql
                                ? Colors.purpleAccent
                                : Colors.blueAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Routed to: ${decision.api == ApiDecision.graphql ? "GraphQL" : "REST"}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: decision.isCacheHit ? Colors.green : Colors.grey[800],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          decision.isCacheHit ? 'CACHE HIT' : 'GEMINI LIVE',
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Confidence: ${(decision.confidence * 100).toInt()}%',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reason: ${decision.reasoning}',
                    style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                  if (decision.modeConflict) ...[
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Note: Mode Conflict Detected',
                          style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }
}
