import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import 'nearby_providers_screen.dart';

class ProviderLoginScreen extends StatefulWidget {
  const ProviderLoginScreen({super.key});

  @override
  State<ProviderLoginScreen> createState() => _ProviderLoginScreenState();
}

class _ProviderLoginScreenState extends State<ProviderLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _professionController = TextEditingController();
  final _areaController = TextEditingController();
  final _rateController = TextEditingController();

  String _selectedProfession = 'plumber';
  final List<Map<String, String>> _professions = const [
    {'id': 'plumber', 'name': 'Plumber (Plumber)'},
    {'id': 'electrician', 'name': 'Electrician (Electrician)'},
    {'id': 'ac_mechanic', 'name': 'AC Mechanic (AC Technician)'},
    {'id': 'house_maid', 'name': 'House Maid (Ghar ki Kaam Wali)'},
    {'id': 'carpenter', 'name': 'Carpenter (Carpenter)'},
    {'id': 'painter', 'name': 'Painter (Rangsaaz)'},
    {'id': 'gardener', 'name': 'Gardener (Mali)'},
    {'id': 'tutor', 'name': 'Tutor / Teacher (Ustad)'},
    {'id': 'beautician', 'name': 'Beautician (Makeup Artist)'},
    {'id': 'generator', 'name': 'Generator Mechanic (Generator Wala)'},
    {'id': 'welder', 'name': 'Welder (Loha Jodne Wala)'},
    {'id': 'tiler', 'name': 'Tiler / Mason (Tiles Wala)'},
  ];

  String _pricingType = 'hourly';
  String _selectedGender = 'male';
  bool _isLoading = false;
  bool _isSignUp = false;

  // ── GPS Location State ──────────────────────────────────────────
  double? _capturedLat;
  double? _capturedLng;
  String _locationStatus = 'not_fetched'; // not_fetched | fetching | captured | denied
  String _locationLabel = 'Tap to get your current location';

  InputDecoration _inputDecoration(String label, IconData? icon, {String? suffix, Widget? prefixWidget}) {
    return InputDecoration(
      labelText: label,
      suffixText: suffix,
      prefixIcon: prefixWidget ?? (icon != null ? Icon(icon, color: AppTheme.primaryGreen) : null),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
      ),
    );
  }

  // ── GPS capture ─────────────────────────────────────────────────
  Future<void> _captureLocation() async {
    setState(() {
      _locationStatus = 'fetching';
      _locationLabel = 'Opening map picker...';
    });

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const NearbyProvidersScreen(),
        ),
      );

      if (result != null && result is Map && mounted) {
        final lat = result['lat'] as double?;
        final lng = result['lng'] as double?;
        final address = result['address'] as String?;

        if (lat != null && lng != null) {
          setState(() {
            _capturedLat = lat;
            _capturedLng = lng;
            _locationStatus = 'captured';
            _locationLabel = '📍 ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
            if (address != null && address.isNotEmpty) {
              _areaController.text = address;
            }
          });
          _snack('📍 Location updated successfully!');
        } else {
          setState(() {
            _locationStatus = 'not_fetched';
            _locationLabel = 'Tap to get your current location';
          });
        }
      } else {
        setState(() {
          _locationStatus = 'not_fetched';
          _locationLabel = 'Tap to get your current location';
        });
      }
    } catch (e) {
      debugPrint('Map picker error: $e');
      setState(() {
        _locationStatus = 'denied';
        _locationLabel = 'Error opening map picker';
      });
    }
    debugPrint('Captured location status: $_locationStatus ($_locationLabel)');
  }

  Future<bool?> _showOtpVerificationDialog(String phone) async {
    String? mockOtp;
    // Call backend to send OTP
    try {
      final res = await ApiService.sendOtp(phone);
      if (res['success'] != true) {
        throw Exception(res['message'] ?? 'Failed to send OTP');
      }
      mockOtp = res['mock_otp'];
    } catch (e) {
      if (!mounted) return false;
      _snack('Failed to send OTP: $e');
      return false;
    }

    if (!mounted) return false;
    final List<TextEditingController> controllers = List.generate(6, (_) => TextEditingController());
    final List<FocusNode> focusNodes = List.generate(6, (_) => FocusNode());
    bool verifying = false;
    String? errorText;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogStateCtx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.phonelink_ring_outlined,
                        color: AppTheme.primaryGreen,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Verify Your Phone",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "We have sent a 6-digit OTP code to\n$phone",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    if (mockOtp != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        "Test OTP: $mockOtp",
                        style: const TextStyle(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    
                    // OTP Grid (6 input boxes)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(6, (index) {
                        return SizedBox(
                          width: 36,
                          height: 48,
                          child: TextField(
                            controller: controllers[index],
                            focusNode: focusNodes[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              counterText: "",
                              contentPadding: EdgeInsets.zero,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                              ),
                            ),
                            onChanged: (value) {
                              if (value.isNotEmpty) {
                                if (index < 5) {
                                  focusNodes[index + 1].requestFocus();
                                } else {
                                  focusNodes[index].unfocus();
                                }
                              } else if (value.isEmpty && index > 0) {
                                focusNodes[index - 1].requestFocus();
                              }
                            },
                          ),
                        );
                      }),
                    ),
                    
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorText!,
                        style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: verifying ? null : () => Navigator.pop(dialogStateCtx, false),
                            child: const Text("Cancel"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: verifying
                                ? null
                                : () async {
                                    final otp = controllers.map((c) => c.text).join();
                                    if (otp.length < 6) {
                                      setDialogState(() {
                                        errorText = "Please enter all 6 digits";
                                      });
                                      return;
                                    }
                                    
                                    setDialogState(() {
                                      verifying = true;
                                      errorText = null;
                                    });
                                    
                                    try {
                                      final verified = await ApiService.verifyOtp(phone, otp);
                                      if (!dialogStateCtx.mounted) return;
                                      if (verified) {
                                        Navigator.pop(dialogStateCtx, true);
                                      } else {
                                        setDialogState(() {
                                          verifying = false;
                                          errorText = "Invalid OTP code. Try again.";
                                        });
                                      }
                                    } catch (e) {
                                      setDialogState(() {
                                        verifying = false;
                                        errorText = e.toString();
                                      });
                                    }
                                  },
                            child: verifying
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text("Verify", style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  // ── Helper: Extract a clean human-readable message from backend detail ──────
  /// Strips JSON braces, "Exception:" prefix, and returns a clean string.
  String? _extractDetailMessage(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    String msg = raw.trim();
    // Remove 'Exception: ' prefix
    if (msg.startsWith('Exception: ')) msg = msg.substring(11).trim();
    // If it looks like a JSON object, try to parse it
    if (msg.startsWith('{')) {
      try {
        final Map<String, dynamic> parsed = jsonDecode(msg);
        if (parsed.containsKey('error')) return parsed['error'].toString();
        if (parsed.containsKey('message')) return parsed['message'].toString();
        if (parsed.containsKey('detail')) {
          final d = parsed['detail'];
          if (d is String) return d;
          if (d is Map) {
            if (d.containsKey('error')) return d['error'].toString();
            if (d.containsKey('message')) return d['message'].toString();
          }
        }
      } catch (_) {}
    }
    return msg;
  }

  // ── Dialog: Show market range info when rate is out of range ────────────────
  Future<void> _showMarketRangeDialog({
    required String message,
    int? marketMin,
    int? marketMax,
    required String serviceName,
    required String areaName,
  }) async {
    final serviceLabel = _professions
        .firstWhere((p) => p['id'] == serviceName, orElse: () => {'name': serviceName})['name']!;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.price_check, color: Colors.orange.shade700, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Rate Out of Market Range',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            if (marketMin != null && marketMax != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FFF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📊 Fair Market Rate for Your Area',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _RangeLabel(label: 'Min', value: 'Rs. $marketMin', color: Colors.green.shade700),
                        const Text('—', style: TextStyle(color: Colors.grey)),
                        _RangeLabel(label: 'Max', value: 'Rs. $marketMax', color: Colors.green.shade700),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Service: $serviceLabel | Area: $areaName',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              '💡 Please update your rate to be within the market range shown above, then try registering again.',
              style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Got It — I\'ll Update My Rate',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Main auth flow ──────────────────────────────────────────────
  Future<void> _authenticate() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _snack('Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        await _doSignUp(email, password);
      } else {
        await _doLogin(email, password);
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      _snack(error.message);
    } catch (e) {
      if (!mounted) return;
      _snack('An unexpected error occurred');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _doSignUp(String email, String password) async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final area = _areaController.text.trim();
    final rateText = _rateController.text.trim();

    if (name.isEmpty || phone.isEmpty || area.isEmpty || rateText.isEmpty) {
      _snack('Please fill in all details including your rate');
      setState(() => _isLoading = false);
      return;
    }

    final rate = int.tryParse(rateText) ?? 1500;

    // Validate rate with backend first
    try {
      final validateRes = await http.post(
        Uri.parse('${ApiService.baseUrl}/providers/validate-rate'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'service_type_id': _selectedProfession,
          'rate': rate,
          'area_name': area,
          'pricing_type': _pricingType,
        }),
      ).timeout(const Duration(seconds: 8));

      if (validateRes.statusCode == 200) {
        final data = jsonDecode(validateRes.body);
        if (data['valid'] == false) {
          // Extract market range and show a helpful dialog
          final int? marketMin = data['min'] is int ? data['min'] : (data['min'] as num?)?.toInt();
          final int? marketMax = data['max'] is int ? data['max'] : (data['max'] as num?)?.toInt();
          final String friendlyMsg = _extractDetailMessage(data['message']) ??
              'Your rate Rs. $rate is outside the fair market range for this service.';
          setState(() => _isLoading = false);
          if (!mounted) return;
          await _showMarketRangeDialog(
            message: friendlyMsg,
            marketMin: marketMin,
            marketMax: marketMax,
            serviceName: _selectedProfession,
            areaName: area,
          );
          return;
        }
      } else {
        // Non-200 response — extract human-readable message
        String errMsg = 'Rate validation failed. Please check your rate.';
        try {
          final data = jsonDecode(validateRes.body);
          errMsg = _extractDetailMessage(data['detail'].toString()) ?? errMsg;
        } catch (_) {}
        setState(() => _isLoading = false);
        _snack('⚠️ $errMsg');
        return;
      }
    } catch (e) {
      debugPrint('Backend validate-rate call error: $e');
      // Don't block registration if backend is unreachable — warn but continue
      _snack('⚠️ Could not verify market rate. Proceeding with registration.');
    }

    // 1. Phone OTP Verification
    final phoneVerified = await _showOtpVerificationDialog(phone);
    if (phoneVerified != true) {
      setState(() => _isLoading = false);
      return;
    }


    // If location not yet captured, try once more silently
    if (_locationStatus == 'not_fetched' || _locationStatus == 'fetching') {
      await _captureLocation();
    }

    final lat = _capturedLat ?? LocationService.defaultLat;
    final lng = _capturedLng ?? LocationService.defaultLng;

    // ── Step 1: Supabase Auth ───────────────────────────────────
    final response = await Supabase.instance.client.auth.signUp(
      email: email,
      password: password,
      data: {
        'role': 'provider',
        'name': name,
        'phone': phone,
        'profession': _selectedProfession,
        'area': area,
        'pricing_type': _pricingType,
        'rate': rate,
        'lat': lat,
        'lng': lng,
        'gender': _selectedGender,
      },
    );

    if (response.user == null) {
      _snack('Sign up failed — please try again');
      return;
    }

    final userId = response.user!.id;

    // ── Step 2: Store provider in Supabase documents table ──────
    try {
      await Supabase.instance.client.from('documents').insert({
        'collection': 'providers',
        'doc_id': userId,
        'data': {
          'id': userId,
          'user_id': userId,
          'service_type_id': _selectedProfession,
          'name_en': name,
          'name_ur': name,
          'area_name': area,
          'phone': phone,
          'lat': lat,
          'lng': lng,
          'coverage_radius_km': 15,
          'is_available': true,
          'trust_score': 85,
          'trust_badge': 'Gold',
          'rating': 4.5,
          'total_reviews': 0,
          'jobs_completed': 0,
          'cnic_verified': false,
          'experience_years': 1,
          'gender': _selectedGender,
          'pricing_type': _pricingType,
          'hourly_rate': _pricingType == 'hourly' ? rate : 0,
          'per_job_rate': _pricingType == 'per_job' ? rate : 0,
          'fixed_rate': _pricingType == 'fixed' ? rate : 0,
          'rate': rate,
          'location_set_at': DateTime.now().toIso8601String(),
        },
      });
    } catch (e) {
      debugPrint('Supabase documents insert: $e');
    }

    // ── Step 3: Also register with backend /providers/register ──
    try {
      final res = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/providers/register'),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: jsonEncode({
              'name_en': name,
              'phone': phone,
              'service_type_id': _selectedProfession,
              'pricing_type': _pricingType,
              'hourly_rate': _pricingType == 'hourly' ? rate : 0,
              'per_job_rate': _pricingType == 'per_job' ? rate : 0,
              'fixed_rate': _pricingType == 'fixed' ? rate : 0,
              'rate': rate,
              'area_name': area,
              'lat': lat,
              'lng': lng,
              'gender': _selectedGender,
              'supabase_user_id': userId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final backendId = data['provider_id'] as String?;
        debugPrint('Backend provider registered: $backendId');

        // Store backend provider_id in Supabase so dashboard can resolve it
        if (backendId != null) {
          try {
            await Supabase.instance.client.from('documents').upsert({
              'collection': 'provider_id_map',
              'doc_id': userId,
              'data': {
                'supabase_user_id': userId,
                'backend_provider_id': backendId,
                'lat': lat,
                'lng': lng,
              },
            });
          } catch (_) {}
        }
      } else {
        String errMsg = 'Backend registration failed';
        try {
          final data = jsonDecode(res.body);
          if (data is Map && data.containsKey('detail')) {
            final detail = data['detail'];
            errMsg = _extractDetailMessage(detail.toString()) ?? errMsg;
          }
        } catch (_) {}
        _snack('❌ $errMsg');
        setState(() => _isLoading = false);
        return;
      }
    } catch (e) {
      debugPrint('Backend register call: $e');
      _snack('❌ Failed to register with backend database. Please try again.');
      setState(() => _isLoading = false);
      return;
    }

    if (!mounted) return;
    _snack('✅ Account created! Location saved. You can now log in.');
    setState(() => _isSignUp = false);
  }

  Future<void> _doLogin(String email, String password) async {
    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.session != null && mounted) {
      final userId = response.session!.user.id;
      Navigator.pushReplacementNamed(
        context,
        '/provider_dashboard',
        arguments: userId,
      );
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Location banner widget ──────────────────────────────────────
  Widget _buildLocationBanner() {
    final isCapturing = _locationStatus == 'fetching';
    final isCaptured = _locationStatus == 'captured';
    final isDenied = _locationStatus == 'denied';

    Color bgStart =
        isCaptured ? const Color(0xFF00C853) : isDenied ? Colors.orange.shade600 : Colors.blueGrey.shade600;
    Color bgEnd =
        isCaptured ? const Color(0xFF1B5E20) : isDenied ? Colors.orange.shade900 : Colors.blueGrey.shade900;

    return GestureDetector(
      onTap: isCapturing ? null : _captureLocation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [bgStart, bgEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: bgStart.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon / spinner
            if (isCapturing)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            else
              Icon(
                isCaptured
                    ? Icons.my_location
                    : isDenied
                        ? Icons.location_off
                        : Icons.location_searching,
                color: Colors.white,
                size: 22,
              ),

            const SizedBox(width: 14),

            // Text column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCaptured
                        ? '📍 Location Captured!'
                        : isDenied
                            ? '⚠️ Location Access Denied'
                            : isCapturing
                                ? 'Getting your location...'
                                : '📡 Share Your Location',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isCaptured
                        ? 'Customers near you will find you first!'
                        : isDenied
                            ? 'Tap to try again — location helps customers find you'
                            : 'Tap to use GPS — helps nearby customers discover you',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),

            // Coordinate badge
            if (isCaptured)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      _capturedLat!.toStringAsFixed(4),
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _capturedLng!.toStringAsFixed(4),
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            else if (!isCapturing)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  'Get GPS',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppTheme.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────────
              Text(
                _isSignUp ? 'Provider Registration' : 'Professional Login',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isSignUp
                    ? 'Register as a service provider to start getting jobs.'
                    : 'Enter your credentials to view your jobs.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // ── Email ──────────────────────────────────────────
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration('Email Address', Icons.email),
              ),
              const SizedBox(height: 16),

              // ── Sign-Up only fields ────────────────────────────
              if (_isSignUp) ...[
                TextField(
                  controller: _nameController,
                  decoration: _inputDecoration('Full Name', Icons.person),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration('Phone Number', Icons.phone),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _selectedProfession,
                  decoration: _inputDecoration('Profession', Icons.work),
                  items: _professions.map((prof) {
                    return DropdownMenuItem<String>(
                      value: prof['id'],
                      child: Text(
                        prof['name']!,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedProfession = val);
                  },
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _areaController,
                  decoration: _inputDecoration(
                    'Service Area (e.g., DHA Lahore, Gulshan Karachi)',
                    Icons.map,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Live Location Banner ──────────────────────────
                _buildLocationBanner(),
                const SizedBox(height: 20),

                // ── Gender Section ──────────────────────────────
                Text(
                  'Select Gender',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose your gender for registration and matching',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _GenderChip(
                      label: 'Male',
                      icon: Icons.male,
                      selected: _selectedGender == 'male',
                      onTap: () => setState(() => _selectedGender = 'male'),
                    ),
                    const SizedBox(width: 8),
                    _GenderChip(
                      label: 'Female',
                      icon: Icons.female,
                      selected: _selectedGender == 'female',
                      onTap: () => setState(() => _selectedGender = 'female'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Pricing Section ──────────────────────────────
                Text(
                  'Your Charges',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Set how you charge for your services',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),

                // Pricing type chips
                Row(
                  children: [
                    _PricingChip(
                      label: 'Hourly',
                      icon: Icons.access_time,
                      selected: _pricingType == 'hourly',
                      onTap: () => setState(() => _pricingType = 'hourly'),
                    ),
                    const SizedBox(width: 8),
                    _PricingChip(
                      label: 'Per Job',
                      icon: Icons.task_alt,
                      selected: _pricingType == 'per_job',
                      onTap: () => setState(() => _pricingType = 'per_job'),
                    ),
                    const SizedBox(width: 8),
                    _PricingChip(
                      label: 'Fixed',
                      icon: Icons.price_check,
                      selected: _pricingType == 'fixed',
                      onTap: () => setState(() => _pricingType = 'fixed'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _rateController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _inputDecoration(
                    _pricingType == 'hourly'
                        ? 'Rate per Hour (PKR)'
                        : _pricingType == 'per_job'
                            ? 'Rate per Job (PKR)'
                            : 'Fixed Rate (PKR)',
                    null,
                    suffix: 'PKR',
                    prefixWidget: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 12),
                        const Text(
                          'Rs.',
                          style: TextStyle(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Password ───────────────────────────────────────
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: _inputDecoration('Password', Icons.lock),
              ),

              const SizedBox(height: 24),

              // ── Submit button ──────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _authenticate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _isSignUp ? 'Sign Up & Save Location' : 'Login to Dashboard',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              Center(
                child: TextButton(
                  onPressed: () => setState(() => _isSignUp = !_isSignUp),
                  child: Text(
                    _isSignUp
                        ? 'Already a provider? Log In'
                        : 'Want to become a provider? Sign Up',
                    style: TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _professionController.dispose();
    _areaController.dispose();
    _rateController.dispose();
    super.dispose();
  }
}

// ── Helper widget: Pricing type chip ─────────────────────────────
class _PricingChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PricingChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryGreen : Colors.transparent,
          border: Border.all(
            color: selected ? AppTheme.primaryGreen : Colors.grey.shade400,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16,
                color: selected ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helper widget: Gender selector chip ──────────────────────────
class _GenderChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _GenderChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryGreen : Colors.transparent,
          border: Border.all(
            color: selected ? AppTheme.primaryGreen : Colors.grey.shade400,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18,
                color: selected ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helper widget: Min/Max range label ───────────────────────────
class _RangeLabel extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _RangeLabel({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            )),
      ],
    );
  }
}
