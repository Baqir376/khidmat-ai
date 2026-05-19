import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class ProviderDashboardScreen extends StatefulWidget {
  const ProviderDashboardScreen({super.key});

  @override
  State<ProviderDashboardScreen> createState() => _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String providerId;
  
  List<dynamic> pendingJobs = [];
  List<dynamic> confirmedJobs = [];
  List<dynamic> completedJobs = [];
  bool isLoading = true;
  String providerName = 'Professional';
  Map<String, dynamic>? providerData;
  Timer? _pollingTimer;
  StreamSubscription<Position>? _locationSub;
  bool _locationSharing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    final currentUser = Supabase.instance.client.auth.currentUser;
    final args = ModalRoute.of(context)?.settings.arguments;
    
    if (args is String) {
      providerId = args;
    } else if (currentUser != null) {
      providerId = currentUser.id;
    } else {
      providerId = 'PROV-1';
    }
    
    debugPrint("ProviderDashboardScreen: Selected Provider ID = $providerId");
    
    _fetchProviderProfile();
    _fetchJobs();
    
    // Poll for real-time updates safely to avoid leaks
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchJobs(silent: true);
    });

    // Start broadcasting provider GPS location every 30 seconds
    _startLocationBroadcast();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pollingTimer?.cancel();
    _locationSub?.cancel();
    super.dispose();
  }

  Future<void> _startLocationBroadcast() async {
    final pos = await LocationService.getCurrentLocation();
    if (pos != null) {
      await _pushLocation(pos.latitude, pos.longitude);
      if (mounted) setState(() => _locationSharing = true);
    }
    // Keep updating every time device moves 50+ meters
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
      ),
    ).listen((pos) async {
      await _pushLocation(pos.latitude, pos.longitude);
    });
  }

  Future<void> _pushLocation(double lat, double lng) async {
    try {
      await http.put(
        Uri.parse('${ApiService.baseUrl}/providers/$providerId/location'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({'lat': lat, 'lng': lng}),
      );
    } catch (_) {}
  }

  Future<void> _fetchProviderProfile() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/providers/by_user/$providerId'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      debugPrint("Provider Profile Status: ${res.statusCode}");
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final p = data['provider'];
        if (p != null && mounted) {
          setState(() {
            providerName = p['name_en'] ?? p['name'] ?? 'Professional';
            providerData = p;
            if (p['id'] != null) {
              providerId = p['id'];
            }
          });
          // Re-fetch jobs using the corrected providerId!
          _fetchJobs();
        }
      }
    } catch (e) {
      debugPrint("Error fetching provider profile: $e");
    }
  }

  Future<void> _fetchJobs({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => isLoading = true);
    }
    
    try {
      final pendingUrl = '${ApiService.baseUrl}/bookings?status=pending&provider_id=$providerId';
      final confirmedUrl = '${ApiService.baseUrl}/bookings?status=confirmed&provider_id=$providerId';
      final completedUrl = '${ApiService.baseUrl}/bookings?status=completed&provider_id=$providerId';
      
      debugPrint("ProviderDashboardScreen fetching pending: $pendingUrl");
      final pendingRes = await http.get(
        Uri.parse(pendingUrl),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      
      debugPrint("ProviderDashboardScreen fetching confirmed: $confirmedUrl");
      final confirmedRes = await http.get(
        Uri.parse(confirmedUrl),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );

      debugPrint("ProviderDashboardScreen fetching completed: $completedUrl");
      final completedRes = await http.get(
        Uri.parse(completedUrl),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      
      debugPrint("Pending Status: ${pendingRes.statusCode}, Confirmed Status: ${confirmedRes.statusCode}, Completed Status: ${completedRes.statusCode}");
      
      if (mounted) {
        List<dynamic> newPending = [];
        List<dynamic> newConfirmed = [];
        List<dynamic> newCompleted = [];
        
        if (pendingRes.statusCode == 200) {
          final data = jsonDecode(pendingRes.body);
          newPending = data['bookings'] ?? [];
        }
        if (confirmedRes.statusCode == 200) {
          final data = jsonDecode(confirmedRes.body);
          newConfirmed = data['bookings'] ?? [];
        }
        if (completedRes.statusCode == 200) {
          final data = jsonDecode(completedRes.body);
          newCompleted = data['bookings'] ?? [];
        }

        // Compare structure to check if anything has actually changed
        bool hasChanged = false;
        if (newPending.length != pendingJobs.length || 
            newConfirmed.length != confirmedJobs.length ||
            newCompleted.length != completedJobs.length) {
          hasChanged = true;
        } else {
          // Compare pending elements
          for (int i = 0; i < newPending.length; i++) {
            if (newPending[i]['id'] != pendingJobs[i]['id'] || 
                newPending[i]['status'] != pendingJobs[i]['status'] ||
                newPending[i]['quoted_price'] != pendingJobs[i]['quoted_price']) {
              hasChanged = true;
              break;
            }
          }
          if (!hasChanged) {
            // Compare confirmed elements
            for (int i = 0; i < newConfirmed.length; i++) {
              if (newConfirmed[i]['id'] != confirmedJobs[i]['id'] || 
                  newConfirmed[i]['status'] != confirmedJobs[i]['status'] ||
                  newConfirmed[i]['quoted_price'] != confirmedJobs[i]['quoted_price']) {
                hasChanged = true;
                break;
              }
            }
          }
          if (!hasChanged) {
            // Compare completed elements
            for (int i = 0; i < newCompleted.length; i++) {
              if (newCompleted[i]['id'] != completedJobs[i]['id'] || 
                  newCompleted[i]['status'] != completedJobs[i]['status'] ||
                  newCompleted[i]['quoted_price'] != completedJobs[i]['quoted_price']) {
                hasChanged = true;
                break;
              }
            }
          }
        }

        if (hasChanged || isLoading) {
          setState(() {
            pendingJobs = newPending;
            confirmedJobs = newConfirmed;
            completedJobs = newCompleted;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching jobs: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _acceptJob(String jobId) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiService.baseUrl}/bookings/$jobId/accept'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );
      
      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job Confirmed & Escrow Secured!'),
            backgroundColor: AppTheme.primaryGreen,
          )
        );
        _fetchJobs();
        _tabController.animateTo(1); // switch to confirmed tab
      } else {
        throw Exception(jsonDecode(res.body)['detail'] ?? 'Failed to accept job');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
      );
    }
  }

  Future<void> _declineJob(String jobId) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiService.baseUrl}/bookings/$jobId/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );
      
      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job Request Declined'),
            backgroundColor: Colors.red,
          )
        );
        _fetchJobs();
      } else {
        throw Exception(jsonDecode(res.body)['detail'] ?? 'Failed to decline job');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
      );
    }
  }

  Future<void> _completeJob(String jobId) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiService.baseUrl}/bookings/$jobId/complete'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );
      
      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job marked as completed successfully! Escrow released! 💸'),
            backgroundColor: AppTheme.primaryGreen,
          )
        );
        _fetchJobs();
        _tabController.animateTo(2); // switch to completed tab!
      } else {
        throw Exception(jsonDecode(res.body)['detail'] ?? 'Failed to complete job');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
      );
    }
  }

  void _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/welcome');
    }
  }

  void _showEditProfileBottomSheet() {
    if (providerData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile details are loading. Please try again in a moment.')),
      );
      return;
    }

    final nameController = TextEditingController(text: providerData!['name_en'] ?? '');
    final areaController = TextEditingController(text: providerData!['area_name'] ?? '');
    
    // Determine active pricing type and initial rate value
    String selectedPricingType = providerData!['pricing_type'] ?? 'hourly';
    
    int getInitialRate() {
      int val = 0;
      if (selectedPricingType == 'hourly') {
        val = providerData!['hourly_rate'] ?? 0;
      } else if (selectedPricingType == 'fixed') {
        val = providerData!['fixed_rate'] ?? 0;
      } else {
        val = providerData!['per_job_rate'] ?? 0;
      }
      if (val <= 0) val = providerData!['rate'] ?? 0;
      if (val <= 0) val = providerData!['hourly_rate'] ?? 0;
      if (val <= 0) val = 1500;
      return val;
    }
    
    final rateController = TextEditingController(text: getInitialRate().toString());
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetStateCtx, setSheetState) {
            String rateLabel = "Hourly Rate (PKR/hr)";
            if (selectedPricingType == 'fixed') {
              rateLabel = "Fixed Rate (PKR)";
            } else if (selectedPricingType == 'per_job') {
              rateLabel = "Per Job Rate (PKR)";
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Edit Professional Profile",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Update your name, working location, pricing models and service fees.",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Full Name
                      const Text(
                        "Full Name",
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: "Enter your full name",
                          prefixIcon: const Icon(Icons.person_outline, color: AppTheme.primaryGreen),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 18),
                      
                      // Service Area
                      const Text(
                        "Service Area / Location Name",
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: areaController,
                        decoration: InputDecoration(
                          hintText: "e.g. Clifton, Karachi",
                          prefixIcon: const Icon(Icons.map_outlined, color: AppTheme.primaryGreen),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 18),
                      
                      // Pricing Model Choice
                      const Text(
                        "Pricing Model",
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text("Hourly"),
                              selected: selectedPricingType == 'hourly',
                              selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                color: selectedPricingType == 'hourly' ? AppTheme.primaryGreen : Colors.black87,
                                fontWeight: selectedPricingType == 'hourly' ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: (val) {
                                if (val) {
                                  setSheetState(() {
                                    selectedPricingType = 'hourly';
                                    int val = providerData!['hourly_rate'] ?? 0;
                                    if (val <= 0) val = providerData!['rate'] ?? 0;
                                    if (val <= 0) val = 1500;
                                    rateController.text = val.toString();
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text("Fixed"),
                              selected: selectedPricingType == 'fixed',
                              selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                color: selectedPricingType == 'fixed' ? AppTheme.primaryGreen : Colors.black87,
                                fontWeight: selectedPricingType == 'fixed' ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: (val) {
                                if (val) {
                                  setSheetState(() {
                                    selectedPricingType = 'fixed';
                                    int val = providerData!['fixed_rate'] ?? 0;
                                    if (val <= 0) val = providerData!['rate'] ?? 0;
                                    if (val <= 0) val = providerData!['hourly_rate'] ?? 0;
                                    if (val <= 0) val = 1500;
                                    rateController.text = val.toString();
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text("Per Job"),
                              selected: selectedPricingType == 'per_job',
                              selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                color: selectedPricingType == 'per_job' ? AppTheme.primaryGreen : Colors.black87,
                                fontWeight: selectedPricingType == 'per_job' ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: (val) {
                                if (val) {
                                  setSheetState(() {
                                    selectedPricingType = 'per_job';
                                    int val = providerData!['per_job_rate'] ?? 0;
                                    if (val <= 0) val = providerData!['rate'] ?? 0;
                                    if (val <= 0) val = providerData!['hourly_rate'] ?? 0;
                                    if (val <= 0) val = 1500;
                                    rateController.text = val.toString();
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      
                      // Rate Input
                      Text(
                        rateLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: rateController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: "e.g. 1500",
                           prefixText: "PKR ",
                          prefixStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 28),
                      
                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: isSaving ? null : () async {
                            final name = nameController.text.trim();
                            final area = areaController.text.trim();
                            final rateVal = int.tryParse(rateController.text.trim()) ?? 0;
                            
                            if (name.isEmpty || area.isEmpty || rateVal <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please fill all fields with valid information')),
                              );
                              return;
                            }
                            
                            setSheetState(() => isSaving = true);
                            
                            try {
                              final body = {
                                "name_en": name,
                                "area_name": area,
                                "pricing_type": selectedPricingType,
                                "rate": rateVal,
                              };
                              
                              final res = await http.put(
                                Uri.parse('${ApiService.baseUrl}/providers/$providerId/profile'),
                                headers: {
                                  'Content-Type': 'application/json',
                                  'ngrok-skip-browser-warning': 'true',
                                },
                                body: jsonEncode(body),
                              );
                              
                              if (!sheetStateCtx.mounted) return;
                              if (res.statusCode == 200) {
                                Navigator.pop(sheetStateCtx); // close bottom sheet
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Profile updated successfully!')),
                                );
                                _fetchProviderProfile(); // refresh details
                              } else {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to update profile: ${res.body}')),
                                );
                              }
                            } catch (err) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error updating profile: $err')),
                              );
                            } finally {
                              setSheetState(() => isSaving = false);
                            }
                          },
                          child: isSaving
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : const Text(
                                  "Save Changes",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Professional Dashboard', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
            Row(
              children: [
                Expanded(
                  child: Text('Welcome, $providerName', 
                    style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue, width: 0.5),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.security, color: Colors.blue, size: 10),
                      SizedBox(width: 2),
                      Text('TEE SECURE', style: TextStyle(color: Colors.blue, fontSize: 9, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (_locationSharing)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.primaryGreen, width: 0.5),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.location_on, color: AppTheme.primaryGreen, size: 10),
                        SizedBox(width: 2),
                        Text('LIVE', style: TextStyle(color: AppTheme.primaryGreen, fontSize: 9, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryGreen,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryGreen,
          tabs: [
            Tab(text: 'Incoming (${pendingJobs.length})'),
            Tab(text: 'My Jobs (${confirmedJobs.length})'),
            Tab(text: 'Completed (${completedJobs.length})'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: AppTheme.primaryGreen),
            onPressed: _showEditProfileBottomSheet,
            tooltip: 'Edit Profile',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black54),
            onPressed: _logout,
          )
        ],
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
        : TabBarView(
            controller: _tabController,
            children: [
              _buildJobList(pendingJobs, isPending: true, isCompleted: false),
              _buildJobList(confirmedJobs, isPending: false, isCompleted: false),
              _buildJobList(completedJobs, isPending: false, isCompleted: true),
            ],
          ),
    );
  }

  Widget _buildJobList(List<dynamic> jobs, {required bool isPending, required bool isCompleted}) {
    if (jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending 
                ? Icons.search_off 
                : (isCompleted ? Icons.history : Icons.task_alt), 
              size: 64, 
              color: Colors.grey.shade300
            ),
            const SizedBox(height: 16),
            Text(
              isPending 
                ? 'No incoming requests right now.' 
                : (isCompleted ? 'You have no completed jobs yet.' : 'You have no active confirmed jobs.'),
              style: const TextStyle(color: Colors.grey, fontSize: 16)
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isPending 
                            ? ((job['is_recommended'] == true || job['provider_id'] == providerId) 
                                ? Colors.amber.shade50 
                                : Colors.blue.shade50)
                            : (isCompleted ? Colors.green.shade50 : AppTheme.primaryGreen.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(20),
                        border: isPending && (job['is_recommended'] == true || job['provider_id'] == providerId)
                            ? Border.all(color: Colors.amber.shade300, width: 1)
                            : isPending
                                ? Border.all(color: Colors.blue.shade200, width: 1)
                                : null,
                      ),
                      child: Text(
                        isPending 
                            ? ((job['is_recommended'] == true || job['provider_id'] == providerId) 
                                ? '⭐ RECOMMENDED MATCH' 
                                : '📍 NEARBY JOB (${job['distance_to_provider_km'] != null ? double.parse(job['distance_to_provider_km'].toString()).toStringAsFixed(1) : '15.0'} km)')
                            : (isCompleted ? 'COMPLETED' : 'CONFIRMED'),
                        style: TextStyle(
                          color: isPending 
                              ? ((job['is_recommended'] == true || job['provider_id'] == providerId) 
                                  ? Colors.amber.shade800 
                                  : Colors.blue.shade700)
                              : (isCompleted ? Colors.green.shade800 : AppTheme.primaryGreen),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      job['user_name'] ?? 'Customer',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ],
                ),
                 const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, size: 18, color: AppTheme.primaryGreen),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                job['service_address'] ?? job['service_area'] ?? 'Location not provided', 
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (job['service_lat'] != null && job['service_lng'] != null && double.tryParse(job['service_lat'].toString()) != 0.0) ...[
                                const SizedBox(height: 4),
                                Text(
                                  "Coordinates: ${double.parse(job['service_lat'].toString()).toStringAsFixed(5)}, ${double.parse(job['service_lng'].toString()).toStringAsFixed(5)}",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (!isCompleted && job['service_lat'] != null && job['service_lng'] != null && double.tryParse(job['service_lat'].toString()) != 0.0) ...[
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () async {
                          final lat = job['service_lat'];
                          final lng = job['service_lng'];
                          final url = Uri.parse('https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=16/$lat/$lng');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Could not launch maps application.')),
                              );
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.navigation_outlined, size: 16, color: AppTheme.primaryGreen),
                              SizedBox(width: 6),
                              Text(
                                'Get Exact Navigation (OpenStreetMap)',
                                style: TextStyle(
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isCompleted ? Colors.green.shade200 : Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isCompleted ? Icons.check_circle : Icons.access_time, 
                        size: 20, 
                        color: isCompleted ? Colors.green : Colors.orange
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isPending 
                            ? 'Customer wants you to do the job on:\n${formatScheduledDateTime(job['scheduled_date'], job['scheduled_time'])}\n\nConfirm according to your availability.'
                            : isCompleted 
                              ? 'Job completed successfully on:\n${formatScheduledDateTime(job['completed_at'] ?? job['updated_at'] ?? job['scheduled_date'], job['scheduled_time'])}'
                              : 'Scheduled for:\n${formatScheduledDateTime(job['scheduled_date'], job['scheduled_time'])}', 
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (isPending)
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: OutlinedButton.icon(
                          onPressed: () => _declineJob(job['id']),
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          label: const Text('DECLINE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 4,
                        child: ElevatedButton.icon(
                          onPressed: () => _acceptJob(job['id']),
                          icon: const Icon(Icons.check_circle, color: Colors.white),
                          label: const Text('ACCEPT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  )
                else if (isCompleted)
                  Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.verified, color: Colors.green, size: 20),
                            SizedBox(width: 8),
                            Text('Payment Released successfully! 💸', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.5)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shield, color: AppTheme.primaryGreen, size: 20),
                            SizedBox(width: 8),
                            Text('Escrow Funded - Proceed to Job', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? 'unknown';
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (ctx) => ChatScreen(
                                    bookingId: job['id'],
                                    otherPersonName: job['user_name'] ?? 'Customer',
                                    currentUserId: currentUserId,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: const Text("Chat"),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: const BorderSide(color: AppTheme.primaryGreen),
                                foregroundColor: AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _completeJob(job['id']),
                              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                              label: const Text("MARK DONE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGreen,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
              ],
            ),
          ),
        );
      },
    );
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
}
