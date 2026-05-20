import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/date_formatter.dart';

class ActiveBookingView extends StatelessWidget {
  final Map<String, dynamic> booking;
  final String providerName;
  final num finalPrice;
  final String status;
  final VoidCallback onMessage;
  final VoidCallback onCall;
  final VoidCallback onCancel;

  const ActiveBookingView({
    super.key,
    required this.booking,
    required this.providerName,
    required this.finalPrice,
    required this.status,
    required this.onMessage,
    required this.onCall,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Active Booking'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Map Placeholder (Like Uber/Foodpanda)
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                image: const DecorationImage(
                  image: NetworkImage("https://static.wixstatic.com/media/7b1fc6_54dcd0d9111c4b18bac412ebaf60359f~mv2.jpg"), // Simple map placeholder
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text("Tracking Live Location...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            
            // 2. Status Timeline
            Container(
              transform: Matrix4.translationValues(0.0, -20.0, 0.0),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5)),
                ],
              ),
              child: Column(
                children: [
                  Text(status == 'pending' ? "Waiting for Provider" : "Estimated Arrival", style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(status == 'pending' ? "Contacting..." : "15 - 20 mins", style: TextStyle(color: status == 'pending' ? Colors.orange : AppTheme.primaryGreen, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  // Progress Steps
                  Row(
                    children: [
                      _buildStep(Icons.access_time, "Pending", true),
                      _buildLine(status != 'pending'),
                      _buildStep(Icons.check_circle, "Confirmed", status != 'pending'),
                      _buildLine(false),
                      _buildStep(Icons.moped, "On the way", false),
                    ],
                  ),
                ],
              ),
            ),
            
            // 2b. Scheduled Date & Time Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: AppTheme.primaryGreen, size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Scheduled For", style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            DateFormatter.formatScheduledDateTime(booking['scheduled_date'], booking['scheduled_time']),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Provider Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person, color: AppTheme.primaryGreen, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(providerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.orange, size: 16),
                                Expanded(
                                  child: Text(
                                    " ${booking['provider_rating'] ?? 4.8} (${booking['provider_jobs_count'] ?? 2} jobs completed)",
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("Total", style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          Text("PKR $finalPrice", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryGreen)),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 4. Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onMessage,
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text("Message"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: AppTheme.primaryGreen),
                        foregroundColor: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onCall,
                      icon: const Icon(Icons.call),
                      label: const Text("Call"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  label: const Text("Cancel Booking Request", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.red)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
            
            // 5. Security & Blockchain
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Security & Blockchain", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.success.withValues(alpha: 0.3))),
                    child: const Row(
                      children: [
                        Icon(Icons.shield, color: AppTheme.success, size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text("TEE Verified • Blockchain Immutable Record • Smart Escrow Secured", style: TextStyle(color: AppTheme.secondaryGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: SelectableText(
                      "TxHash: ${booking['blockchain_tx_hash'] ?? 'Pending...'}", 
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(IconData icon, String label, bool isActive) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive ? AppTheme.primaryGreen : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isActive ? Colors.white : Colors.grey.shade400, size: 20),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? Colors.black87 : Colors.grey), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildLine(bool isActive) {
    return Expanded(
      child: Container(
        height: 3,
        color: isActive ? AppTheme.primaryGreen : Colors.grey.shade200,
        margin: const EdgeInsets.only(bottom: 24),
      ),
    );
  }
}
