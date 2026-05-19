import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class NearbyProvidersScreen extends StatefulWidget {
  final String? serviceTypeFilter;
  final String? serviceLabel;

  const NearbyProvidersScreen({
    super.key,
    this.serviceTypeFilter,
    this.serviceLabel,
  });

  @override
  State<NearbyProvidersScreen> createState() => _NearbyProvidersScreenState();
}

class _NearbyProvidersScreenState extends State<NearbyProvidersScreen> {
  final MapController _mapController = MapController();

  LatLng? _pickerCenter;
  String _selectedAddress = "Locating your service address...";
  bool _isFetchingAddress = false;
  bool _isLoading = true;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    setState(() => _isLoading = true);
    try {
      final pos = await LocationService.getCurrentLocation(forceFresh: true);
      if (pos != null) {
        final loc = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _pickerCenter = loc;
          _isLoading = false;
        });
        _mapController.move(loc, 15.0);
        _updateAddress(pos.latitude, pos.longitude);
      } else {
        final loc = const LatLng(LocationService.defaultLat, LocationService.defaultLng);
        setState(() {
          _pickerCenter = loc;
          _isLoading = false;
        });
        _mapController.move(loc, 15.0);
        _updateAddress(LocationService.defaultLat, LocationService.defaultLng);
      }
    } catch (e) {
      final loc = const LatLng(LocationService.defaultLat, LocationService.defaultLng);
      setState(() {
        _pickerCenter = loc;
        _isLoading = false;
      });
      _mapController.move(loc, 15.0);
      _updateAddress(LocationService.defaultLat, LocationService.defaultLng);
    }
  }

  Future<void> _updateAddress(double lat, double lng) async {
    if (!mounted) return;
    setState(() => _isFetchingAddress = true);

    try {
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/providers/reverse_geocode?lat=$lat&lng=$lng'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        final address = data['full_address'] ?? data['address'] as String?;
        if (address != null) {
          setState(() {
            _selectedAddress = address;
            _isFetchingAddress = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _selectedAddress = "Custom Location (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})";
        _isFetchingAddress = false;
      });
    }
  }

  void _onMapMoved(LatLng center) {
    setState(() {
      _pickerCenter = center;
      _selectedAddress = "Locating your service address...";
      _isFetchingAddress = true;
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _updateAddress(center.latitude, center.longitude);
    });
  }

  void _centerOnUser() async {
    setState(() => _isFetchingAddress = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          bool? openSettings = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Location Services Disabled'),
              content: const Text('Please enable GPS to use this feature.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                TextButton(
                  onPressed: () {
                    Geolocator.openLocationSettings();
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
          if (openSettings != true) {
            setState(() {
              _isFetchingAddress = false;
              if (_pickerCenter != null) _updateAddress(_pickerCenter!.latitude, _pickerCenter!.longitude);
            });
            return;
          }
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          bool? openSettings = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Permission Denied'),
              content: const Text('Location permission was permanently denied. Please allow it in App Settings.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                TextButton(
                  onPressed: () {
                    Geolocator.openAppSettings();
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
          if (openSettings != true) {
            setState(() {
              _isFetchingAddress = false;
              if (_pickerCenter != null) _updateAddress(_pickerCenter!.latitude, _pickerCenter!.longitude);
            });
            return;
          }
        }
      }

      final pos = await LocationService.getCurrentLocation(forceFresh: true);
      if (pos != null && mounted) {
        final loc = LatLng(pos.latitude, pos.longitude);
        _mapController.move(loc, 15.5);
        _onMapMoved(loc);
      } else {
        if (mounted) {
          setState(() {
            _isFetchingAddress = false;
            if (_pickerCenter != null) {
              _updateAddress(_pickerCenter!.latitude, _pickerCenter!.longitude);
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetchingAddress = false;
          if (_pickerCenter != null) {
            _updateAddress(_pickerCenter!.latitude, _pickerCenter!.longitude);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userPos = _pickerCenter ?? const LatLng(LocationService.defaultLat, LocationService.defaultLng);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── MAIN MAP ──────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: userPos,
              initialZoom: 15.0,
              maxZoom: 18.0,
              minZoom: 10.0,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture && position.center != null) {
                  _onMapMoved(position.center!);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.khidmat.khidmat_ai_app',
                tileBuilder: (context, child, tile) {
                  return ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      0.8, 0,   0,   0, 0,
                      0,   0.8, 0,   0, 0,
                      0,   0,   0.8, 0, 0,
                      0,   0,   0,   1, 0,
                    ]),
                    child: child,
                  );
                },
              ),
            ],
          ),

          // ── STATIC CENTER PIN ─────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 40), // Shift up so tip aligns perfectly with map center
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.location_on,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    width: 6,
                    height: 12,
                    color: AppTheme.primaryGreen,
                  ),
                  Container(
                    width: 12,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── TOP GRADIENT HEADER ───────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Location',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              'Drag map to drop pin exactly at your location',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── MY LOCATION FLOATING ACTION BUTTON ───────────────────
          Positioned(
            right: 16,
            bottom: 230,
            child: GestureDetector(
              onTap: _centerOnUser,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.my_location, color: AppTheme.primaryGreen, size: 24),
              ),
            ),
          ),

          // ── BOTTOM LOCATION CARD ──────────────────────────────────
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on, color: AppTheme.primaryGreen, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'SERVICE AREA / ADDRESS',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _isFetchingAddress
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 16,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 16,
                              width: 150,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        )
                      : Text(
                          _selectedAddress,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isFetchingAddress
                        ? null
                        : () {
                            if (_pickerCenter != null) {
                              Navigator.pop(context, {
                                'lat': _pickerCenter!.latitude,
                                'lng': _pickerCenter!.longitude,
                                'address': _selectedAddress,
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'CONFIRM LOCATION',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── INITIAL LOADING OVERLAY ───────────────────────────────
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
