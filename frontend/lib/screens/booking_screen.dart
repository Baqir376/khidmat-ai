import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart';
import 'dart:async';

import 'booking/widgets/awaiting_selection_view.dart';
import 'booking/widgets/active_booking_view.dart';
import 'booking/widgets/completed_view.dart';
import 'booking/widgets/cancelled_view.dart';
import 'booking/widgets/provider_profile_sheet.dart';
import 'booking/widgets/review_dialog.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  Timer? _timer;
  bool _showAllProviders = true;
  bool _reviewSubmitted = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      final provider = context.read<AppProvider>();
      final response = provider.currentBookingResponse;
      if (response != null && response['booking'] != null && response['booking']['id'] != null) {
        provider.refreshBooking(response['booking']['id']);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _showChat() {
    final response = context.read<AppProvider>().currentBookingResponse;
    if (response == null || response['booking'] == null) return;
    
    final booking = response['booking'];
    final bookingId = booking['id'];
    final providerName = booking['provider_name'] ?? 'Professional';
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? 'unknown';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChatScreen(
        bookingId: bookingId,
        otherPersonName: providerName,
        currentUserId: currentUserId,
      ),
    );
  }

  void _showReviewDialog(Map<String, dynamic> booking) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ReviewDialog(
        booking: booking,
        onReviewSubmitted: () {
          setState(() {
            _reviewSubmitted = true;
          });
        },
      ),
    );
  }

  void _showProviderProfileSheet(BuildContext context, Map<String, dynamic> pData) {
    ProviderProfileSheet.show(context, pData);
  }

  @override
  Widget build(BuildContext context) {
    final response = context.select<AppProvider, Map<String, dynamic>?>((p) => p.currentBookingResponse);
    final isLoading = context.select<AppProvider, bool>((p) => p.isLoading);

    if (response == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Results')),
        body: const Center(child: Text("No booking data found")),
      );
    }

    final pipelineStatus = response['pipeline_status'];

    if (pipelineStatus == "awaiting_user_selection") {
      final providers = response['top_providers'] as List<dynamic>? ?? [];
      final counterfactual = response['counterfactual'] as String? ?? '';

      return isLoading
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
            )
          : AwaitingSelectionView(
              providers: providers,
              counterfactual: counterfactual,
              showAllProviders: _showAllProviders,
              onToggleShowAllProviders: () {
                setState(() {
                  _showAllProviders = !_showAllProviders;
                });
              },
              onShowProviderProfileSheet: _showProviderProfileSheet,
              onConfirmBooking: (providerId) {
                context.read<AppProvider>().confirmBooking(providerId);
              },
            );
    }

    final booking = response['booking'] ?? {};
    final providerName = response['booking']?['provider_name'] ?? 'Professional';
    final finalPrice = response['final_price'] ?? response['booking']?['final_price'] ?? 1000;
    final status = response['booking']?['status'] ?? 'pending';

    if (status == 'cancelled') {
      return CancelledView(
        onGoHome: () {
          context.read<AppProvider>().currentBookingResponse = null;
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        },
      );
    }

    if (status == 'completed') {
      return CompletedView(
        booking: booking,
        providerName: providerName,
        finalPrice: finalPrice,
        reviewSubmitted: _reviewSubmitted,
        onShowReviewDialog: () => _showReviewDialog(booking),
        onGoHome: () {
          context.read<AppProvider>().currentBookingResponse = null;
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        },
      );
    }

    // Active tracking screen
    return ActiveBookingView(
      booking: booking,
      providerName: providerName,
      finalPrice: finalPrice,
      status: status,
      onMessage: _showChat,
      onCall: () {
        final phone = booking['provider_phone'] ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Simulating call to $providerName ($phone)')),
        );
      },
      onCancel: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Cancel Booking"),
            content: const Text("Are you sure you want to cancel this booking request?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("NO")),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("YES, CANCEL")),
            ],
          ),
        );
        if (!context.mounted) return;
        if (confirmed == true) {
          try {
            await context.read<AppProvider>().cancelActiveBooking(booking['id']);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Booking cancelled successfully"),
                backgroundColor: Colors.red,
              ),
            );
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
            );
          }
        }
      },
    );
  }
}
