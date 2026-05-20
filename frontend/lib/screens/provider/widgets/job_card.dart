import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/date_formatter.dart';

class JobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final String providerId;
  final bool isPending;
  final bool isCompleted;
  final Function(String) onAccept;
  final Function(String) onDecline;
  final Function(String) onComplete;
  final VoidCallback onChat;

  const JobCard({
    super.key,
    required this.job,
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPending 
                        ? ((job['is_recommended'] == true || job['provider_id'] == providerId) 
                            ? Colors.amber.shade50 
                            : Colors.blue.shade50)
                        : (isCompleted ? Colors.green.shade50 : AppTheme.primaryGreen.withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(20),
                    border: isPending && (job['is_recommended'] == true || job['provider_id'] == providerId)
                        ? Border.all(color: Colors.amber.shade300, width: 1)
                        : isPending
                            ? Border.all(color: Colors.blue.shade200, width: 1)
                            : null,
                  ),
                  child: Text(
                    isPending 
                        ? ((job['is_recommended'] == true || job['provider_id'] == providerId) 
                            ? '⭐ RECOMMENDED MATCH' 
                            : '📍 NEARBY JOB (${job['distance_to_provider_km'] != null ? double.parse(job['distance_to_provider_km'].toString()).toStringAsFixed(1) : '15.0'} km)')
                        : (isCompleted ? 'COMPLETED' : 'CONFIRMED'),
                    style: TextStyle(
                      color: isPending 
                          ? ((job['is_recommended'] == true || job['provider_id'] == providerId) 
                              ? Colors.amber.shade800 
                              : Colors.blue.shade700)
                          : (isCompleted ? Colors.green.shade800 : AppTheme.primaryGreen),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                Text('PKR ${job['final_price'] ?? job['quoted_price'] ?? 0}', 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryGreen)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              (job['service_type_id'] ?? 'Task').toString().replaceAll('_', ' ').toUpperCase(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  job['user_name'] ?? 'Customer',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, size: 18, color: AppTheme.primaryGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job['service_address'] ?? job['service_area'] ?? 'Location not provided', 
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (job['service_lat'] != null && job['service_lng'] != null && double.tryParse(job['service_lat'].toString()) != 0.0) ...[
                            const SizedBox(height: 4),
                            Text(
                              "Coordinates: ${double.parse(job['service_lat'].toString()).toStringAsFixed(5)}, ${double.parse(job['service_lng'].toString()).toStringAsFixed(5)}",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (!isCompleted && job['service_lat'] != null && job['service_lng'] != null && double.tryParse(job['service_lat'].toString()) != 0.0) ...[
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () async {
                      final lat = job['service_lat'];
                      final lng = job['service_lng'];
                      final url = Uri.parse('https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=16/$lat/$lng');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not launch maps application.')),
                          );
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.navigation_outlined, size: 16, color: AppTheme.primaryGreen),
                          SizedBox(width: 6),
                          Text(
                            'Get Exact Navigation (OpenStreetMap)',
                            style: TextStyle(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isCompleted ? Colors.green.shade200 : Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    isCompleted ? Icons.check_circle : Icons.access_time, 
                    size: 20, 
                    color: isCompleted ? Colors.green : Colors.orange
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isPending 
                        ? 'Customer wants you to do the job on:\n${DateFormatter.formatScheduledDateTime(job['scheduled_date'], job['scheduled_time'])}\n\nConfirm according to your availability.'
                        : isCompleted 
                          ? 'Job completed successfully on:\n${DateFormatter.formatScheduledDateTime(job['completed_at'] ?? job['updated_at'] ?? job['scheduled_date'], job['scheduled_time'])}'
                          : 'Scheduled for:\n${DateFormatter.formatScheduledDateTime(job['scheduled_date'], job['scheduled_time'])}', 
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (isPending)
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: OutlinedButton.icon(
                      onPressed: () => onDecline(job['id']),
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      label: const Text('DECLINE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: ElevatedButton.icon(
                      onPressed: () => onAccept(job['id']),
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text('ACCEPT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              )
            else if (isCompleted)
              Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text('Payment Released successfully! 💸', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield, color: AppTheme.primaryGreen, size: 20),
                        SizedBox(width: 8),
                        Text('Escrow Funded - Proceed to Job', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onChat,
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text("Chat"),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: const BorderSide(color: AppTheme.primaryGreen),
                            foregroundColor: AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => onComplete(job['id']),
                          icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                          label: const Text("MARK DONE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
          ],
        ),
      ),
    );
  }
}
