import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../theme/app_theme.dart';
import '../../../services/api_service.dart';

class ReviewDialog extends StatefulWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onReviewSubmitted;

  const ReviewDialog({
    super.key,
    required this.booking,
    required this.onReviewSubmitted,
  });

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  double selectedRating = 5.0;
  final commentController = TextEditingController();
  bool isSubmitting = false;

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              "How was your experience with ${widget.booking['provider_name'] ?? 'the professional'}?",
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
                          setState(() {
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
          onPressed: isSubmitting ? null : () => Navigator.pop(context),
          child: Text("CANCEL", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          onPressed: isSubmitting ? null : _submitReview,
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
  }

  Future<void> _submitReview() async {
    if (commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a review comment.')),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/reviews'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          "provider_id": widget.booking['provider_id'] ?? '',
          "booking_id": widget.booking['id'] ?? '',
          "rating": selectedRating,
          "review_text": commentController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context);
          widget.onReviewSubmitted();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thank you! Your review has been submitted successfully.'),
              backgroundColor: AppTheme.primaryGreen,
            ),
          );
        }
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
      if (mounted) {
        setState(() => isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
