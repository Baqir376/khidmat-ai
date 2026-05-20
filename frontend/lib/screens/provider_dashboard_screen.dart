import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'provider/widgets/edit_profile_sheet.dart';
import 'provider/widgets/job_list_view.dart';

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
    
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchJobs(silent: true);
    });

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
      
      final pendingRes = await http.get(
        Uri.parse(pendingUrl),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      
      final confirmedRes = await http.get(
        Uri.parse(confirmedUrl),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );

      final completedRes = await http.get(
        Uri.parse(completedUrl),
        headers: {'ngrok-skip-browser-warning': 'true'},
      );
      
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

        bool hasChanged = false;
        if (newPending.length != pendingJobs.length || 
            newConfirmed.length != confirmedJobs.length ||
            newCompleted.length != completedJobs.length) {
          hasChanged = true;
        } else {
          for (int i = 0; i < newPending.length; i++) {
            if (newPending[i]['id'] != pendingJobs[i]['id'] || 
                newPending[i]['status'] != pendingJobs[i]['status'] ||
                newPending[i]['quoted_price'] != pendingJobs[i]['quoted_price']) {
              hasChanged = true;
              break;
            }
          }
          if (!hasChanged) {
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
        _tabController.animateTo(1);
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
        _tabController.animateTo(2);
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

    EditProfileSheet.show(
      context,
      providerData: providerData!,
      providerId: providerId,
      onProfileUpdated: _fetchProviderProfile,
    );
  }

  void _openChat(Map<String, dynamic> job) {
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
              JobListView(
                jobs: pendingJobs,
                providerId: providerId,
                isPending: true,
                isCompleted: false,
                onAccept: _acceptJob,
                onDecline: _declineJob,
                onComplete: _completeJob,
                onChat: _openChat,
              ),
              JobListView(
                jobs: confirmedJobs,
                providerId: providerId,
                isPending: false,
                isCompleted: false,
                onAccept: _acceptJob,
                onDecline: _declineJob,
                onComplete: _completeJob,
                onChat: _openChat,
              ),
              JobListView(
                jobs: completedJobs,
                providerId: providerId,
                isPending: false,
                isCompleted: true,
                onAccept: _acceptJob,
                onDecline: _declineJob,
                onComplete: _completeJob,
                onChat: _openChat,
              ),
            ],
          ),
    );
  }
}
