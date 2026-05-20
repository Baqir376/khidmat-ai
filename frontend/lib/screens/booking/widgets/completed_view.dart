import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class CompletedView extends StatelessWidget {
  final Map<String, dynamic> booking;
  final String providerName;
  final num finalPrice;
  final bool reviewSubmitted;
  final VoidCallback onShowReviewDialog;
  final VoidCallback onGoHome;

  const CompletedView({
    super.key,
    required this.booking,
    required this.providerName,
    required this.finalPrice,
    required this.reviewSubmitted,
    required this.onShowReviewDialog,
    required this.onGoHome,
  });

  @override
  Widget build(BuildContext context) {
    final hasReviewed = booking['review_submitted'] == true || booking['rating'] != null || reviewSubmitted;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stars, color: AppTheme.primaryGreen, size: 80),
                const SizedBox(height: 24),
                const Text(
                  "Job Completed Successfully! 🎉",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "Your service with $providerName is complete. Payment of PKR $finalPrice has been released from escrow safely.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, color: AppTheme.primaryGreen, size: 16),
                      SizedBox(width: 8),
                      Text("Escrow Released Successfully", style: TextStyle(color: AppTheme.secondaryGreen, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (hasReviewed)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 20),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            "Your rating and review for $providerName have been submitted successfully. Thank you!",
                            style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.rate_review, color: Colors.amber.shade800, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Please take a moment to rate and review the services of $providerName.",
                            style: TextStyle(color: Colors.amber.shade900, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: onShowReviewDialog,
                    icon: const Icon(Icons.star_rounded, color: Colors.white, size: 20),
                    label: const Text("RATE & REVIEW PROFESSIONAL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: onGoHome,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Go Back to Home", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
