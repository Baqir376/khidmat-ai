import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import '../services/api_service.dart';


class MyBookingsScreen extends StatefulWidget {
  final String status;
  
  const MyBookingsScreen({super.key, required this.status});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  List<dynamic> myBookings = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMyBookings();
  }

  @override
  void didUpdateWidget(MyBookingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _fetchMyBookings();
    }
  }

  Future<void> _fetchMyBookings() async {
    setState(() => isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/bookings?citizen_id=${user.id}&status=${widget.status}'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          myBookings = data['bookings'] ?? [];
          // Sort by creation time descending if possible, or assume already sorted
        });
      }
    } catch (e) {
      debugPrint("Error fetching bookings: $e");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showReviewDialog(Map<String, dynamic> job) {
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
                      "How was your experience with ${job['provider_name'] ?? 'the professional'}?",
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
                          "provider_id": job['provider_id'],
                          "booking_id": job['id'],
                          "rating": selectedRating,
                          "review_text": commentController.text.trim(),
                        }),
                      );
                      
                      if (response.statusCode == 200) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Thank you! Your review has been submitted successfully.'),
                            backgroundColor: AppTheme.primaryGreen,
                          ),
                        );
                        _fetchMyBookings();
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
                      if (dialogStateCtx.mounted) {
                        setDialogState(() => isSubmitting = false);
                      }
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
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
    }

    if (myBookings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text("No bookings yet.", style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchMyBookings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: myBookings.length,
        itemBuilder: (context, index) {
          final job = myBookings[index];
          final isPending = job['status'] == 'pending';
          
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.only(bottom: 16),
            child: InkWell(
              onTap: () {
                context.read<AppProvider>().setActiveBooking(job);
                Navigator.pushNamed(context, '/booking');
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Builder(
                          builder: (context) {
                            final status = job['status'] ?? 'pending';
                            Color tagBg = Colors.orange.shade50;
                            Color tagText = Colors.orange;
                            String tagLabel = 'WAITING FOR PROVIDER';
                            
                            if (status == 'confirmed') {
                              tagBg = AppTheme.primaryGreen.withValues(alpha: 0.1);
                              tagText = AppTheme.primaryGreen;
                              tagLabel = 'CONFIRMED / ACTIVE';
                            } else if (status == 'completed') {
                              tagBg = Colors.blue.shade50;
                              tagText = Colors.blue.shade800;
                              tagLabel = 'COMPLETED 🎉';
                            } else if (status == 'cancelled') {
                              tagBg = Colors.red.shade50;
                              tagText = Colors.red.shade800;
                              tagLabel = 'CANCELLED';
                            }

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: tagBg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                tagLabel,
                                style: TextStyle(
                                  color: tagText,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }
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
                    if (job['provider_name'] != null) ...[
                      const SizedBox(height: 8),
                      Text('Professional: ${job['provider_name']}', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w500)),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(formatScheduledDateTime(job['scheduled_date'], job['scheduled_time']), 
                          style: const TextStyle(color: Colors.black87)),
                      ],
                    ),
                    if (!isPending && job['status'] != 'completed' && job['status'] != 'cancelled') ...[ 
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? 'unknown';
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => ChatScreen(
                                bookingId: job['id'],
                                otherPersonName: job['provider_name'] ?? 'Professional',
                                currentUserId: currentUserId,
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline, size: 16),
                          label: const Text("Message Professional"),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            side: const BorderSide(color: AppTheme.primaryGreen),
                            foregroundColor: AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                    if (job['status'] == 'completed') ...[
                      const SizedBox(height: 12),
                      if (job['review_submitted'] == true || job['rating'] != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.rate_review_outlined, size: 16, color: AppTheme.primaryGreen),
                                  const SizedBox(width: 6),
                                  const Expanded(
                                    child: Text(
                                      "Your Submitted Review:",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Row(
                                    children: List.generate(5, (starIdx) {
                                      final starRating = (job['rating'] ?? 5.0) is double ? (job['rating'] ?? 5.0) : double.parse((job['rating'] ?? 5.0).toString());
                                      return Icon(
                                        starIdx < starRating ? Icons.star_rounded : Icons.star_border_rounded,
                                        size: 16,
                                        color: Colors.amber,
                                      );
                                    }),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                job['review_text'] ?? 'No review text provided.',
                                style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.black87),
                              ),
                            ],
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showReviewDialog(job),
                            icon: const Icon(Icons.star_rounded, color: Colors.white, size: 18),
                            label: const Text("RATE & REVIEW PROFESSIONAL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String formatScheduledDateTime(dynamic dateVal, dynamic timeVal) {
    if (dateVal == null) return 'ASAP';
    
    String dateStr = '';
    if (dateVal is Map) {
      if (dateVal.containsKey('resolved_date')) {
        dateStr = dateVal['resolved_date']?.toString() ?? '';
      } else if (dateVal.containsKey('date')) {
        dateStr = dateVal['date']?.toString() ?? '';
      } else if (dateVal.containsKey('day') && dateVal.containsKey('month') && dateVal.containsKey('year')) {
        dateStr = "${dateVal['year']}-${dateVal['month'].toString().padLeft(2, '0')}-${dateVal['day'].toString().padLeft(2, '0')}";
      } else {
        dateStr = dateVal.toString();
      }
    } else {
      dateStr = dateVal.toString();
    }

    if (dateStr.isEmpty || dateStr.toLowerCase() == 'asap') {
      return 'ASAP';
    }
    
    // Parse JSON string if dateStr is a JSON string
    if (dateStr.startsWith('{')) {
      try {
        final parsed = jsonDecode(dateStr);
        if (parsed is Map) {
          if (parsed.containsKey('resolved_date')) {
            dateStr = parsed['resolved_date']?.toString() ?? '';
          } else if (parsed.containsKey('date')) {
            dateStr = parsed['date']?.toString() ?? '';
          } else if (parsed.containsKey('day') && parsed.containsKey('month') && parsed.containsKey('year')) {
            dateStr = "${parsed['year']}-${parsed['month'].toString().padLeft(2, '0')}-${parsed['day'].toString().padLeft(2, '0')}";
          }
        }
      } catch (_) {}
    }
    
    String formattedDate = dateStr;
    try {
      // Expected format: YYYY-MM-DD
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        
        final dateTime = DateTime(year, month, day);
        final weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
        final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
        
        final weekday = weekdays[dateTime.weekday % 7];
        final monthStr = months[dateTime.month - 1];
        
        formattedDate = "$weekday, $monthStr $day, $year";
      }
    } catch (e) {
      try {
        final partsSlash = dateStr.split('/');
        if (partsSlash.length == 3) {
          final day = int.parse(partsSlash[0]);
          final month = int.parse(partsSlash[1]);
          final year = int.parse(partsSlash[2]);
          final dateTime = DateTime(year, month, day);
          final weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
          final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
          final weekday = weekdays[dateTime.weekday % 7];
          final monthStr = months[dateTime.month - 1];
          formattedDate = "$weekday, $monthStr $day, $year";
        }
      } catch (_) {}
    }
    
    if (timeVal == null) {
      return formattedDate;
    }
    
    String timeStr = '';
    if (timeVal is Map) {
      if (timeVal.containsKey('resolved_time')) {
        timeStr = timeVal['resolved_time']?.toString() ?? '';
      } else if (timeVal.containsKey('time')) {
        timeStr = timeVal['time']?.toString() ?? '';
      } else if (timeVal.containsKey('hour')) {
        final hr = timeVal['hour'];
        final min = timeVal['minute'] ?? 0;
        final period = timeVal['period'] ?? '';
        timeStr = "$hr:${min.toString().padLeft(2, '0')} $period";
      } else {
        timeStr = timeVal.toString();
      }
    } else {
      timeStr = timeVal.toString();
    }

    // Parse JSON string if timeStr is a JSON string
    if (timeStr.startsWith('{')) {
      try {
        final parsed = jsonDecode(timeStr);
        if (parsed is Map) {
          if (parsed.containsKey('resolved_time')) {
            timeStr = parsed['resolved_time']?.toString() ?? '';
          } else if (parsed.containsKey('time')) {
            timeStr = parsed['time']?.toString() ?? '';
          } else if (parsed.containsKey('hour')) {
            final hr = parsed['hour'];
            final min = parsed['minute'] ?? 0;
            final period = parsed['period'] ?? '';
            timeStr = "$hr:${min.toString().padLeft(2, '0')} $period";
          }
        }
      } catch (_) {}
    }
    
    String formattedTime = timeStr.trim();
    if (formattedTime.toLowerCase() == 'asap') {
      return "$formattedDate at ASAP";
    }
    
    try {
      final cleanTime = formattedTime.toLowerCase();
      // If it already has AM or PM
      if (cleanTime.contains('am') || cleanTime.contains('pm')) {
        final isPm = cleanTime.contains('pm');
        // Extract numbers
        final digits = cleanTime.replaceAll(RegExp(r'[^0-9:]'), '');
        final parts = digits.split(':');
        if (parts.isNotEmpty) {
          int hour = int.parse(parts[0]);
          int minute = parts.length > 1 ? int.parse(parts[1]) : 0;
          // Standardize hour (12-hour format normalization)
          if (hour == 0) hour = 12;
          if (hour > 12) hour = hour % 12;
          final period = isPm ? 'PM' : 'AM';
          formattedTime = "$hour:${minute.toString().padLeft(2, '0')} $period";
        }
      } else {
        // Assuming 24-hour time or simple HH:MM
        final timeParts = formattedTime.split(':');
        if (timeParts.isNotEmpty) {
          int hour = int.parse(timeParts[0]);
          int minute = timeParts.length > 1 ? int.parse(timeParts[1].replaceAll(RegExp(r'[^0-9]'), '')) : 0;
          final ampm = hour >= 12 ? 'PM' : 'AM';
          final hour12 = hour % 12 == 0 ? 12 : hour % 12;
          formattedTime = "$hour12:${minute.toString().padLeft(2, '0')} $ampm";
        }
      }
    } catch (e) {
      // Fallback
    }
    
    return "$formattedDate at $formattedTime";
  }
}
