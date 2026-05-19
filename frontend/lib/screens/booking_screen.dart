import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

import 'dart:async';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  Timer? _timer;
  bool _showAllProviders = true; // Show all providers by default — not hidden behind a toggle
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
    double selectedRating = 5.0;
    final commentController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogStateCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.rate_review, color: AppTheme.primaryGreen),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Review Professional",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "How was your experience with ${booking['provider_name'] ?? 'the professional'}?",
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              final starValue = index + 1.0;
                              return GestureDetector(
                                onTap: isSubmitting ? null : () {
                                  setDialogState(() {
                                    selectedRating = starValue;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(
                                    selectedRating >= starValue 
                                        ? Icons.star_rounded 
                                        : Icons.star_border_rounded,
                                    size: 36,
                                    color: Colors.amber,
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedRating == 5.0 
                                ? "Excellent! ⭐⭐⭐⭐⭐" 
                                : (selectedRating == 4.0 
                                    ? "Good ⭐⭐⭐⭐" 
                                    : (selectedRating == 3.0 
                                        ? "Average ⭐⭐⭐" 
                                        : (selectedRating == 2.0 
                                            ? "Poor ⭐⭐" 
                                            : "Very Bad ⭐"))),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Write your comments:",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      enabled: !isSubmitting,
                      decoration: InputDecoration(
                        hintText: "E.g., Bohot acha kaam kiya, timing perfect thi, highly recommended!",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: Text("CANCEL", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : () async {
                    if (commentController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(dialogStateCtx).showSnackBar(
                        const SnackBar(content: Text('Please write a review comment.')),
                      );
                      return;
                    }
                    
                    setDialogState(() => isSubmitting = true);
                    
                    try {
                      final response = await http.post(
                        Uri.parse('${ApiService.baseUrl}/reviews'),
                        headers: {
                          'Content-Type': 'application/json',
                          'ngrok-skip-browser-warning': 'true',
                        },
                        body: jsonEncode({
                          "provider_id": booking['provider_id'] ?? '',
                          "booking_id": booking['id'] ?? '',
                          "rating": selectedRating,
                          "review_text": commentController.text.trim(),
                        }),
                      );
                      
                      if (response.statusCode == 200) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (!mounted) return;
                        setState(() {
                          _reviewSubmitted = true;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Thank you! Your review has been submitted successfully.'),
                            backgroundColor: AppTheme.primaryGreen,
                          ),
                        );
                      } else {
                        String msg = 'Failed to submit review';
                        try {
                          final errData = jsonDecode(response.body);
                          if (errData != null && errData['detail'] != null) {
                            msg = errData['detail'].toString();
                          }
                        } catch (_) {}
                        throw Exception(msg);
                      }
                    } catch (e) {
                      if (!dialogStateCtx.mounted) return;
                      setDialogState(() => isSubmitting = false);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isSubmitting 
                      ? const SizedBox(
                          width: 20, 
                          height: 20, 
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        ) 
                      : const Text("SUBMIT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
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
      
      if (providers.isEmpty) {
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(title: const Text('AI Booking Selection')),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                "Service unavailable. We are sorry but no provider is giving service in this area",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          ),
        );
      }

      final bestMatch = providers[0];
      final runnerUps = providers.skip(1).toList();

      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('AI Smart Match Recommendation', style: TextStyle(fontWeight: FontWeight.bold)),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textPrimary,
          centerTitle: true,
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // AI Greeting / Robot Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: AppTheme.primaryGreen,
                              radius: 18,
                              child: Icon(Icons.psychology, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "AI-Optimized Best Value Choice",
                                    style: TextStyle(
                                      color: AppTheme.primaryGreen,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "AI has evaluated price, rating, and distance to match you with the absolute best choice.",
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),

                      // Giant glowing premium Best Match Card
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.5),
                            width: 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                              blurRadius: 24,
                              spreadRadius: 4,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header badge
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppTheme.primaryGreen, AppTheme.secondaryGreen],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            "RECOMMENDED BEST MATCH",
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      "${bestMatch['match_score']?.toStringAsFixed(1) ?? '98.5'}% Match",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Profile / Info Row (Clickable to view details & reviews)
                                  GestureDetector(
                                    onTap: () => _showProviderProfileSheet(context, bestMatch),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      color: Colors.transparent, // increases touch target
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 30,
                                            backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                                            child: Text(
                                              (bestMatch['name'] != null && bestMatch['name'].toString().isNotEmpty)
                                                  ? bestMatch['name'].toString().substring(0, 1).toUpperCase()
                                                  : 'P',
                                              style: const TextStyle(
                                                color: AppTheme.primaryGreen,
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        bestMatch['name'] ?? 'Professional',
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 18,
                                                          color: AppTheme.textPrimary,
                                                          decoration: TextDecoration.underline,
                                                        ),
                                                      ),
                                                    ),
                                                    const Icon(Icons.chevron_right, size: 18, color: AppTheme.primaryGreen),
                                                    const SizedBox(width: 4),
                                                    if (bestMatch['trust_badge'] != null && bestMatch['trust_badge'].toString().isNotEmpty)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: Colors.blue.shade50,
                                                          borderRadius: BorderRadius.circular(6),
                                                          border: Border.all(color: Colors.blue.shade200),
                                                        ),
                                                        child: Text(
                                                          bestMatch['trust_badge'],
                                                          style: TextStyle(
                                                            color: Colors.blue.shade800,
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Wrap(
                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                  spacing: 12,
                                                  runSpacing: 4,
                                                  children: [
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.star, color: Colors.orange, size: 16),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          "${bestMatch['rating'] ?? 5.0} Rating (View Reviews)",
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 12,
                                                            color: AppTheme.primaryGreen,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.location_on, color: Colors.grey.shade400, size: 16),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          "${bestMatch['distance_km'] ?? 1.5} km away",
                                                          style: const TextStyle(
                                                            color: AppTheme.textSecondary,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 20),
                                  const Divider(height: 1),
                                  const SizedBox(height: 20),

                                  // Core specs: Price & ETA
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "ESTIMATED RATE",
                                              style: TextStyle(
                                                color: AppTheme.textSecondary,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatRate(bestMatch),
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primaryGreen,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        width: 1,
                                        height: 35,
                                        color: Colors.grey.shade300,
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "ESTIMATED ARRIVAL (ETA)",
                                              style: TextStyle(
                                                color: AppTheme.textSecondary,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "${bestMatch['eta_minutes'] ?? 15} minutes",
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  if (counterfactual.isNotEmpty) ...[
                                    const SizedBox(height: 20),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade50.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.amber.shade100),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.info_outline, color: Colors.amber.shade800, size: 14),
                                              const SizedBox(width: 6),
                                              Text(
                                                "Why this match is the best value:",
                                                style: TextStyle(
                                                  color: Colors.amber.shade900,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            counterfactual,
                                            style: TextStyle(
                                              color: Colors.grey.shade800,
                                              fontSize: 11,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 24),

                                  // Pulsing Confirm Booking Button
                                  ElevatedButton(
                                    onPressed: () => context.read<AppProvider>().confirmBooking(bestMatch['id']),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryGreen,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size.fromHeight(56),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 4,
                                      shadowColor: AppTheme.primaryGreen.withValues(alpha: 0.4),
                                    ),
                                    child: const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.check_circle_outline, color: Colors.white),
                                          SizedBox(width: 10),
                                          Text(
                                            "Confirm Recommended Booking",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Sub-list section with toggle for other options
                      if (runnerUps.isNotEmpty) ...[
                        const Divider(),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showAllProviders = !_showAllProviders;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.people_outline, color: Colors.grey.shade600),
                                    const SizedBox(width: 10),
                                    Text(
                                      "Show other available specialists (${runnerUps.length})",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(
                                  _showAllProviders ? Icons.expand_less : Icons.expand_more,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        if (_showAllProviders) ...[
                          const SizedBox(height: 12),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: runnerUps.length,
                            itemBuilder: (context, index) {
                              final p = runnerUps[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 0.5,
                                color: Colors.white,
                                child: ListTile(
                                  onTap: () => _showProviderProfileSheet(context, p),
                                  contentPadding: const EdgeInsets.all(12),
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                                    child: Text(
                                      (p['name'] != null && p['name'].toString().isNotEmpty)
                                          ? p['name'].toString().substring(0, 1).toUpperCase()
                                          : 'P',
                                      style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          p['name'] ?? 'Unknown', 
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold, 
                                            fontSize: 14,
                                            decoration: TextDecoration.underline,
                                          )
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right, size: 16, color: AppTheme.primaryGreen),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 2),
                                      Text("⭐ ${p['rating']} (View Reviews) • ${p['distance_km']}km away"),
                                      Text("${_formatRate(p)} • ETA: ${p['eta_minutes']}m"),
                                    ],
                                  ),
                                  trailing: ElevatedButton(
                                    onPressed: () => context.read<AppProvider>().confirmBooking(p['id']),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade100,
                                      foregroundColor: AppTheme.primaryGreen,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text("Book", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
      );
    }

    // Complete phase
    final booking = response['booking'] ?? {};
    
    // In completed phase, the assigned provider is passed back
    final providerName = response['booking']?['provider_name'] ?? 'Professional';
    final finalPrice = response['final_price'] ?? response['booking']?['final_price'] ?? 1000;
    final status = response['booking']?['status'] ?? 'pending';
    
    if (status == 'cancelled') {
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
                  onPressed: () {
                    context.read<AppProvider>().currentBookingResponse = null;
                    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
                  },
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

    if (status == 'completed') {
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
                  Builder(
                    builder: (context) {
                      final hasReviewed = booking['review_submitted'] == true || booking['rating'] != null || _reviewSubmitted;
                      if (hasReviewed) {
                        return Container(
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
                        );
                      } else {
                        return Column(
                          children: [
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
                              onPressed: () => _showReviewDialog(booking),
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
                        );
                      }
                    }
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      context.read<AppProvider>().currentBookingResponse = null;
                      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
                    },
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
    
    // We can simulate an active tracking screen
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
                            formatScheduledDateTime(booking['scheduled_date'], booking['scheduled_time']),
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
                      onPressed: _showChat,
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
                      onPressed: () {},
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
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Cancel Booking"),
                        content: const Text("Are you sure you want to cancel this booking request?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("NO"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text("YES, CANCEL"),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      if (!context.mounted) return;
                      try {
                        await context.read<AppProvider>().cancelActiveBooking(booking['id']);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Booking cancelled successfully"),
                            backgroundColor: Colors.red,
                          )
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Error: $e"),
                            backgroundColor: Colors.red,
                          )
                        );
                      }
                    }
                  },
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

  String _formatRate(Map<String, dynamic> p) {
    final pricingType = (p['pricing_type'] as String?)?.trim() ?? 'hourly';

    // Safely extracts the first positive int from the given keys.
    // Handles both int and double JSON values safely.
    int getValidRate(List<String> keys) {
      for (final key in keys) {
        final val = p[key];
        if (val == null) continue;
        final num? n = val is num ? val : num.tryParse(val.toString());
        if (n != null && n > 0) return n.toInt();
      }
      return 0;
    }

    if (pricingType == 'fixed') {
      final rate = getValidRate(['fixed_rate', 'rate', 'per_job_rate', 'hourly_rate']);
      return rate > 0 ? "PKR $rate (Fixed)" : "PKR 1500 (Fixed)";
    } else if (pricingType == 'per_job') {
      final rate = getValidRate(['per_job_rate', 'rate', 'fixed_rate', 'hourly_rate']);
      return rate > 0 ? "PKR $rate/job" : "PKR 1500/job";
    } else {
      final rate = getValidRate(['hourly_rate', 'rate', 'per_job_rate', 'fixed_rate']);
      return rate > 0 ? "PKR $rate/hr" : "PKR 1500/hr";
    }
  }

  String formatScheduledDateTime(dynamic dateVal, dynamic timeVal) {
    if (dateVal == null) return 'ASAP';
    
    String dateStr = dateVal.toString();
    if (dateStr.isEmpty || dateStr.toLowerCase() == 'asap') {
      return 'ASAP';
    }
    
    String formattedDate = dateStr;
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        final dateTime = DateTime(year, month, day);
        final weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
        final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
        formattedDate = "${weekdays[dateTime.weekday % 7]}, ${months[dateTime.month - 1]} $day, $year";
      }
    } catch (_) {}
    
    if (timeVal == null) return formattedDate;
    
    String timeStr = timeVal.toString().trim();
    if (timeStr.toLowerCase() == 'asap' || timeStr.isEmpty) {
      return "$formattedDate at ASAP";
    }
    
    String formattedTime = timeStr;
    try {
      final cleanTime = timeStr.toLowerCase();
      if (cleanTime.contains('am') || cleanTime.contains('pm')) {
        final isPm = cleanTime.contains('pm');
        final digits = cleanTime.replaceAll(RegExp(r'[^0-9:]'), '');
        final parts = digits.split(':');
        if (parts.isNotEmpty) {
          int hour = int.parse(parts[0]);
          int minute = parts.length > 1 ? int.parse(parts[1]) : 0;
          if (hour == 0) hour = 12;
          if (hour > 12) hour = hour % 12;
          formattedTime = "$hour:${minute.toString().padLeft(2, '0')} ${isPm ? 'PM' : 'AM'}";
        }
      } else {
        final timeParts = timeStr.split(':');
        if (timeParts.isNotEmpty) {
          int hour = int.parse(timeParts[0]);
          int minute = timeParts.length > 1 ? int.parse(timeParts[1].replaceAll(RegExp(r'[^0-9]'), '')) : 0;
          final ampm = hour >= 12 ? 'PM' : 'AM';
          final hour12 = hour % 12 == 0 ? 12 : hour % 12;
          formattedTime = "$hour12:${minute.toString().padLeft(2, '0')} $ampm";
        }
      }
    } catch (_) {}
    
    return "$formattedDate at $formattedTime";
  }

  void _showProviderProfileSheet(BuildContext context, Map<String, dynamic> pData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        List<dynamic> reviews = [];
        bool isLoadingReviews = true;
        String errorMessage = '';

        return StatefulBuilder(
          builder: (context, setSheetState) {
            // Fetch reviews if loading
            if (isLoadingReviews) {
              final providerId = pData['id'] ?? pData['provider_id'];
              if (providerId != null) {
                http.get(
                  Uri.parse('${ApiService.baseUrl}/providers/$providerId/reviews'),
                  headers: {'ngrok-skip-browser-warning': 'true'},
                ).then((res) {
                  if (res.statusCode == 200) {
                    final data = jsonDecode(res.body);
                    if (context.mounted) {
                      setSheetState(() {
                        reviews = data['reviews'] ?? [];
                        isLoadingReviews = false;
                      });
                    }
                  } else {
                    if (context.mounted) {
                      setSheetState(() {
                        errorMessage = 'Failed to load reviews';
                        isLoadingReviews = false;
                      });
                    }
                  }
                }).catchError((err) {
                  if (context.mounted) {
                    setSheetState(() {
                      errorMessage = err.toString();
                      isLoadingReviews = false;
                    });
                  }
                });
              } else {
                isLoadingReviews = false;
                errorMessage = 'Invalid provider ID';
              }
            }

            final double avgRating = pData['rating'] is num 
                ? (pData['rating'] as num).toDouble() 
                : double.tryParse((pData['rating'] ?? '5.0').toString()) ?? 5.0;

            final String trustBadge = pData['trust_badge']?.toString() ?? 'Bronze';
            final double trustScore = pData['trust_score'] is num 
                ? (pData['trust_score'] as num).toDouble() 
                : double.tryParse((pData['trust_score'] ?? '75.0').toString()) ?? 75.0;

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle/Indicator bar
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Header with profile photo & stats
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                          child: Text(
                            (pData['name'] != null && pData['name'].toString().isNotEmpty)
                                ? pData['name'].toString().substring(0, 1).toUpperCase()
                                : 'P',
                            style: const TextStyle(
                              color: AppTheme.primaryGreen,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pData['name'] ?? 'Professional',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  // Trust badge representation
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getBadgeBgColor(trustBadge),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.verified_user, 
                                          size: 12, 
                                          color: _getBadgeTextColor(trustBadge)
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "$trustBadge Level",
                                          style: TextStyle(
                                            color: _getBadgeTextColor(trustBadge),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Trust score badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      "Trust Score: ${trustScore.toStringAsFixed(0)}",
                                      style: TextStyle(
                                        color: Colors.teal.shade800,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                                  const SizedBox(width: 4),
                                  Text(
                                    avgRating.toStringAsFixed(1),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "(${reviews.length} reviews)",
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(height: 1),

                  // Tabs header
                  Container(
                    color: Colors.grey.shade50,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Text(
                      "CUSTOMER REVIEWS & FEEDBACK",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),

                  // Reviews listing
                  Expanded(
                    child: isLoadingReviews
                        ? const Center(
                            child: CircularProgressIndicator(color: AppTheme.primaryGreen),
                          )
                        : errorMessage.isNotEmpty
                            ? Center(
                                child: Text(
                                  "Error loading reviews: $errorMessage",
                                  style: const TextStyle(color: Colors.red),
                                ),
                              )
                            : reviews.isEmpty
                                ? const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.rate_review_outlined, size: 48, color: Colors.grey),
                                        SizedBox(height: 12),
                                        Text(
                                          "No reviews yet.",
                                          style: TextStyle(color: Colors.grey, fontSize: 15),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.all(16),
                                    itemCount: reviews.length,
                                    itemBuilder: (context, rIdx) {
                                      final rev = reviews[rIdx];
                                      final rRating = rev['rating'] is num 
                                          ? (rev['rating'] as num).toDouble() 
                                          : double.tryParse((rev['rating'] ?? '5.0').toString()) ?? 5.0;
                                      
                                      final sentiment = (rev['sentiment'] ?? rev['sentiment_label'])?.toString().replaceAll('_', ' ').toUpperCase() ?? 'POSITIVE';
                                      
                                      return Card(
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          side: BorderSide(color: Colors.grey.shade200),
                                        ),
                                        margin: const EdgeInsets.only(bottom: 12),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Row(
                                                    children: List.generate(5, (starIdx) {
                                                      return Icon(
                                                        starIdx < rRating 
                                                            ? Icons.star_rounded 
                                                            : Icons.star_border_rounded,
                                                        size: 16,
                                                        color: Colors.amber,
                                                      );
                                                    }),
                                                  ),
                                                  if (sentiment.isNotEmpty)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: _getSentimentBgColor(sentiment),
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Text(
                                                        sentiment,
                                                        style: TextStyle(
                                                          color: _getSentimentTextColor(sentiment),
                                                          fontSize: 8,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                rev['review_text'] ?? '',
                                                style: const TextStyle(
                                                  color: Colors.black87,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    "Job Done",
                                                    style: TextStyle(
                                                      color: Colors.grey.shade500,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  Text(
                                                    _formatReviewDate(rev['created_at']),
                                                    style: TextStyle(
                                                      color: Colors.grey.shade400,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getBadgeBgColor(String level) {
    switch (level.toLowerCase()) {
      case 'elite':
        return Colors.purple.shade50;
      case 'gold':
        return Colors.amber.shade50;
      case 'silver':
        return Colors.blueGrey.shade50;
      default:
        return Colors.orange.shade50;
    }
  }

  Color _getBadgeTextColor(String level) {
    switch (level.toLowerCase()) {
      case 'elite':
        return Colors.purple.shade800;
      case 'gold':
        return Colors.amber.shade800;
      case 'silver':
        return Colors.blueGrey.shade800;
      default:
        return Colors.orange.shade800;
    }
  }

  Color _getSentimentBgColor(String sentiment) {
    if (sentiment.contains('VERY POSITIVE')) return Colors.green.shade100;
    if (sentiment.contains('POSITIVE')) return Colors.green.shade50;
    if (sentiment.contains('NEUTRAL')) return Colors.grey.shade100;
    return Colors.red.shade50;
  }

  Color _getSentimentTextColor(String sentiment) {
    if (sentiment.contains('VERY POSITIVE')) return Colors.green.shade900;
    if (sentiment.contains('POSITIVE')) return Colors.green.shade800;
    if (sentiment.contains('NEUTRAL')) return Colors.grey.shade800;
    return Colors.red.shade800;
  }

  String _formatReviewDate(dynamic dateStr) {
    if (dateStr == null) return "Recent";
    try {
      final parsed = DateTime.parse(dateStr.toString());
      return "${parsed.day}/${parsed.month}/${parsed.year}";
    } catch (_) {
      return dateStr.toString().split('T')[0];
    }
  }
}
