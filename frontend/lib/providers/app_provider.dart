import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppProvider with ChangeNotifier {
  bool isSafetyModeEnabled = false;
  bool isLoading = false;
  Map<String, dynamic>? currentBookingResponse;
  double? lastSearchLat;
  double? lastSearchLng;
  String? error;

  void toggleSafetyMode(bool value) {
    isSafetyModeEnabled = value;
    notifyListeners();
  }

  void setActiveBooking(Map<String, dynamic> booking) {
    currentBookingResponse = {
      'pipeline_status': 'completed',
      'booking': booking,
      'final_price': booking['final_price'] ?? booking['quoted_price'],
    };
    notifyListeners();
  }

  Future<void> submitRequest(
    String prompt, {
    String? imageBase64,
    double lat = 24.8607,
    double lng = 67.0099,
  }) async {
    isLoading = true;
    error = null;
    lastSearchLat = lat;
    lastSearchLng = lng;
    notifyListeners();

    try {
      currentBookingResponse = await ApiService.submitBooking(
        prompt,
        womensSafetyMode: isSafetyModeEnabled,
        imageBase64: imageBase64,
        lat: lat,
        lng: lng,
      );
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '').trim();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> confirmBooking(String providerId) async {
    if (currentBookingResponse == null) return;
    
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final sessionId = currentBookingResponse!['session_id'];
      final intent = currentBookingResponse!['intent'];
      final fairPrice = currentBookingResponse!['fair_price'];
      final counterfactual = currentBookingResponse!['counterfactual'] ?? "";

      final user = Supabase.instance.client.auth.currentUser;
      final citizenId = user?.id;
      final userName = user?.userMetadata?['name'] ?? "Customer";

      final confirmResponse = await ApiService.confirmBooking(
        sessionId, providerId, intent, fairPrice, counterfactual,
        citizenId: citizenId, userName: userName,
        userLat: lastSearchLat, userLng: lastSearchLng,
      );
      
      // Update the current response with the new data
      currentBookingResponse = confirmResponse;
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '').trim();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshBooking(String bookingId) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/bookings/$bookingId'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      if (res.statusCode == 200) {
        final booking = jsonDecode(res.body);
        if (currentBookingResponse != null && currentBookingResponse!['booking'] != null) {
          currentBookingResponse!['booking'] = booking;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Error refreshing booking: $e");
    }
  }

  Future<void> cancelActiveBooking(String bookingId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await ApiService.cancelBooking(bookingId);
      
      // Update local state if it matches the current booking
      if (currentBookingResponse != null &&
          currentBookingResponse!['booking'] != null &&
          currentBookingResponse!['booking']['id'] == bookingId) {
        currentBookingResponse!['booking']['status'] = 'cancelled';
      }
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '').trim();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}

