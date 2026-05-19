import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AgentTraceBubble extends StatelessWidget {
  final Map<String, dynamic> trace;

  const AgentTraceBubble({super.key, required this.trace});

  @override
  Widget build(BuildContext context) {
    bool isSuccess = trace['status'] == 'success';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess ? AppTheme.primaryGreen : AppTheme.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                trace['agent_name'] ?? 'Agent',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                "${trace['duration_ms'] ?? 0}ms",
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            trace['reasoning_text'] ?? '',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
