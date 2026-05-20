import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class CancelledView extends StatelessWidget {
  final VoidCallback onGoHome;

  const CancelledView({
    super.key,
    required this.onGoHome,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cancel_outlined, color: Colors.red, size: 80),
              const SizedBox(height: 24),
              const Text(
                "Booking Cancelled",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                "This booking has been cancelled. If you want a new service, you can request another professional.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: onGoHome,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Go Back to Home"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
