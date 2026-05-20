import 'package:flutter/material.dart';
import 'job_card.dart';

class JobListView extends StatelessWidget {
  final List<dynamic> jobs;
  final String providerId;
  final bool isPending;
  final bool isCompleted;
  final Function(String) onAccept;
  final Function(String) onDecline;
  final Function(String) onComplete;
  final Function(Map<String, dynamic>) onChat;

  const JobListView({
    super.key,
    required this.jobs,
    required this.providerId,
    required this.isPending,
    required this.isCompleted,
    required this.onAccept,
    required this.onDecline,
    required this.onComplete,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending 
                ? Icons.search_off 
                : (isCompleted ? Icons.history : Icons.task_alt), 
              size: 64, 
              color: Colors.grey.shade300
            ),
            const SizedBox(height: 16),
            Text(
              isPending 
                ? 'No incoming requests right now.' 
                : (isCompleted ? 'You have no completed jobs yet.' : 'You have no active confirmed jobs.'),
              style: const TextStyle(color: Colors.grey, fontSize: 16)
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        return JobCard(
          job: job,
          providerId: providerId,
          isPending: isPending,
          isCompleted: isCompleted,
          onAccept: onAccept,
          onDecline: onDecline,
          onComplete: onComplete,
          onChat: () => onChat(job),
        );
      },
    );
  }
}
