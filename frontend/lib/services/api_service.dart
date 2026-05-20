import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  static const String fallbackUrl = 'https://khidmat-ai.onrender.com/api';
  static String? _resolvedBaseUrl;

  static String get baseUrl {
    if (_resolvedBaseUrl != null) return _resolvedBaseUrl!;
    return fallbackUrl;
  }

  /// Pings local and emulator addresses concurrently to find the fastest direct local route
  static Future<void> optimizeConnectionSpeed() async {
    if (_resolvedBaseUrl != null) return;
    
    final candidates = [
      'https://khidmat-ai.onrender.com/api', // Render Public Deployment (Production Cloud)
      'http://192.168.5.246:8000/api', // Direct Local Wi-Fi
      'http://10.0.2.2:8000/api', // Android Emulator
      'http://localhost:8000/api',
      'http://127.0.0.1:8000/api',
      'http://10.0.3.2:8000/api',
      'http://100.126.106.34:8000/api', // Tailscale VPN
    ];

    debugPrint('[ApiService] Speed Optimization: Pinging candidates in parallel...');
    
    final completer = Completer<String?>();
    int pendingCount = candidates.length;
    
    void onPingFailed() {
      pendingCount--;
      if (pendingCount == 0 && !completer.isCompleted) {
        completer.complete(null);
      }
    }

    for (final url in candidates) {
      http.get(Uri.parse('$url/providers/nearby?limit=1'))
          .timeout(const Duration(milliseconds: 3000))
          .then((response) {
            if (response.statusCode == 200 || response.statusCode == 404) {
              if (!completer.isCompleted) {
                completer.complete(url);
              }
            } else {
              onPingFailed();
            }
          })
          .catchError((_) {
            onPingFailed();
          });
    }

    try {
      final fastestUrl = await completer.future.timeout(const Duration(milliseconds: 3200), onTimeout: () => null);
      if (fastestUrl != null) {
        _resolvedBaseUrl = fastestUrl;
        debugPrint('[ApiService] Speed Optimization: Successfully connected to fastest direct local endpoint: $_resolvedBaseUrl');
        return;
      }
    } catch (e) {
      debugPrint('[ApiService] Speed Optimization: Parallel check error: $e');
    }

    _resolvedBaseUrl = fallbackUrl;
    debugPrint('[ApiService] Speed Optimization: Direct local route not detected. Using fallback route: $fallbackUrl');
  }


  static Future<Map<String, dynamic>> submitBooking(
    String userInput, {
    bool womensSafetyMode = false,
    String? imageBase64,
    double lat = 24.8607,
    double lng = 67.0099,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/book'),
        headers: {
            'Content-Type': 'application/json',
            'ngrok-skip-browser-warning': 'true',
          },
        body: jsonEncode({
          'user_input': userInput,
          'lat': lat,
          'lng': lng,
          'womens_safety_mode': womensSafetyMode,
          'input_type': imageBase64 != null ? 'photo' : 'text',
          'image_base64': imageBase64,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        try {
          final errBody = jsonDecode(response.body);
          if (errBody['detail'] != null && errBody['detail']['error'] != null) {
            throw Exception(errBody['detail']['error']);
          }
        } catch (e) {
          if (e.toString().contains('Exception:')) rethrow;
        }
        throw Exception('Failed to find providers: ${response.statusCode}');
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      throw Exception(msg);
    }
  }

  /// Fetch nearby providers by GPS coordinates
  static Future<List<dynamic>> getNearbyProviders({
    required double lat,
    required double lng,
    String? serviceType,
    double radiusKm = 10.0,
    int limit = 20,
  }) async {
    try {
      String url = '$baseUrl/providers/nearby?lat=$lat&lng=$lng&radius_km=$radiusKm&limit=$limit';
      if (serviceType != null) url += '&service_type=$serviceType';
      final res = await http.get(
        Uri.parse(url),
        headers: {'ngrok-skip-browser-warning': 'true'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return jsonDecode(res.body)['providers'] ?? [];
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>> confirmBooking(
    String sessionId,
    String providerId,
    Map<String, dynamic> intent,
    Map<String, dynamic> fairPrice,
    String counterfactual, {
    String? citizenId,
    String? userName,
    double? userLat,
    double? userLng,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/book/confirm'),
        headers: {
            'Content-Type': 'application/json',
            'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'session_id': sessionId,
          'provider_id': providerId,
          'intent': intent,
          'fair_price': fairPrice,
          'counterfactual': counterfactual,
          'womens_safety_mode': false,
          'citizen_id': citizenId ?? "citizen_demo",
          'user_name': userName ?? "Customer",
          'user_lat': userLat,
          'user_lng': userLng,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to confirm booking: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<List<dynamic>> getMessages(String bookingId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/chat/$bookingId'),
      headers: {'ngrok-skip-browser-warning': 'true'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['messages'] ?? [];
    }
    return [];
  }

  static Future<void> sendMessage(String bookingId, String senderId, String text) async {
    await http.post(
      Uri.parse('$baseUrl/chat/'),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode({
        'booking_id': bookingId,
        'sender_id': senderId,
        'text': text,
      }),
    );
  }

  static Future<Map<String, dynamic>?> getBookingDetails(String bookingId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/$bookingId'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/$bookingId/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['detail'] ?? 'Failed to cancel booking');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Send OTP to user phone number
  static Future<Map<String, dynamic>> sendOtp(String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-otp'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({'phone': phone}),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['detail'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Verify OTP for user phone number
  static Future<bool> verifyOtp(String phone, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-otp'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({'phone': phone, 'otp': otp}),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return true;
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['detail'] ?? 'Invalid OTP code');
      }
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Send chat message to AI Chatbot endpoint
  static Future<Map<String, dynamic>> sendAIChat({
    required String message,
    required List<Map<String, String>> history,
    double lat = 24.8607,
    double lng = 67.0099,
    String language = 'en',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ai-chat'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'message': message,
          'history': history,
          'lat': lat,
          'lng': lng,
          'language': language,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to send AI chat: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}

