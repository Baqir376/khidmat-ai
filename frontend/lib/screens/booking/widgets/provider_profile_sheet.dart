import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../theme/app_theme.dart';
import '../../../services/api_service.dart';

class ProviderProfileSheet {
  static void show(BuildContext context, Map<String, dynamic> pData) {
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

  static Color _getBadgeBgColor(String level) {
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

  static Color _getBadgeTextColor(String level) {
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

  static Color _getSentimentBgColor(String sentiment) {
    if (sentiment.contains('VERY POSITIVE')) return Colors.green.shade100;
    if (sentiment.contains('POSITIVE')) return Colors.green.shade50;
    if (sentiment.contains('NEUTRAL')) return Colors.grey.shade100;
    return Colors.red.shade50;
  }

  static Color _getSentimentTextColor(String sentiment) {
    if (sentiment.contains('VERY POSITIVE')) return Colors.green.shade900;
    if (sentiment.contains('POSITIVE')) return Colors.green.shade800;
    if (sentiment.contains('NEUTRAL')) return Colors.grey.shade800;
    return Colors.red.shade800;
  }

  static String _formatReviewDate(dynamic dateStr) {
    if (dateStr == null) return "Recent";
    try {
      final parsed = DateTime.parse(dateStr.toString());
      return "${parsed.day}/${parsed.month}/${parsed.year}";
    } catch (_) {
      return dateStr.toString().split('T')[0];
    }
  }
}
