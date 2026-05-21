import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/language_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/safety_fab.dart';
import 'my_bookings_screen.dart';
import 'nearby_providers_screen.dart';
import 'ai_chatbot_screen.dart';
import '../services/location_service.dart';
import 'package:geolocator/geolocator.dart';

import 'user_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _promptController = TextEditingController();
  bool _hasImage = false;
  int _currentIndex = 0;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedCategory;

  // Real-time GPS coordinates
  double _userLat = LocationService.defaultLat;
  double _userLng = LocationService.defaultLng;
  bool _hasRealLocation = false;
  bool _fetchingLocation = false;
  String? _customAddress;

  final List<Map<String, String>> _categories = const [
    {'id': 'plumber', 'name': 'Plumber (Plumber) 🔧'},
    {'id': 'electrician', 'name': 'Electrician (Electrician) ⚡'},
    {'id': 'ac_mechanic', 'name': 'AC Mechanic (AC Technician) ❄️'},
    {'id': 'house_maid', 'name': 'House Maid (Ghar ki Kaam Wali) 🧹'},
    {'id': 'carpenter', 'name': 'Carpenter (Carpenter) 🪚'},
    {'id': 'painter', 'name': 'Painter (Rangsaaz) 🎨'},
    {'id': 'gardener', 'name': 'Gardener (Mali) 🪴'},
    {'id': 'tutor', 'name': 'Tutor / Teacher (Ustad) 📚'},
    {'id': 'beautician', 'name': 'Beautician (Makeup Artist) 💅'},
    {'id': 'generator', 'name': 'Generator Mechanic (Generator Wala) ⚙️'},
    {'id': 'welder', 'name': 'Welder (Loha Jodne Wala) 👨‍🏭'},
    {'id': 'tiler', 'name': 'Tiler / Mason (Tiles Wala) 🧱'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserLocation({bool showFeedback = false}) async {
    setState(() => _fetchingLocation = true);
    try {
      if (showFeedback) {
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
              setState(() => _fetchingLocation = false);
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
              setState(() => _fetchingLocation = false);
              return;
            }
          }
        }
      }

      final pos = await LocationService.getCurrentLocation(forceFresh: showFeedback);
      if (pos != null && mounted) {
        setState(() {
          _userLat = pos.latitude;
          _userLng = pos.longitude;
          _hasRealLocation = true;
          _fetchingLocation = false;
        });
        if (showFeedback && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📍 Location updated successfully!'),
              backgroundColor: AppTheme.primaryGreen,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() => _fetchingLocation = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _fetchingLocation = false);
      }
    }
  }

  void _submit() async {
    String finalPrompt = _promptController.text;
    if (_selectedDate != null) {
      finalPrompt += "\nDate: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}";
    }
    if (_selectedTime != null) {
      finalPrompt += "\nTime: ${_selectedTime!.format(context)}";
    }

    final provider = context.read<AppProvider>();
    final dummyBase64 = _hasImage ? "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=" : null;
    await provider.submitRequest(
      finalPrompt,
      imageBase64: dummyBase64,
      lat: _userLat,
      lng: _userLng,
    );
    
    if (provider.error == null && mounted) {
      Navigator.pushNamed(context, '/booking');
    } else if (mounted) {
      String displayError = provider.error ?? 'Service unavailable. We are sorry but no provider is giving service in this area';
      
      final lowerErr = displayError.toLowerCase();
      if (lowerErr.contains('failed to find providers') ||
          lowerErr.contains('service unavailable') ||
          lowerErr.contains('connection') ||
          lowerErr.contains('format') ||
          lowerErr.contains('html') ||
          lowerErr.contains('json') ||
          lowerErr.contains('http') ||
          displayError.trim().isEmpty) {
        displayError = 'Service unavailable. We are sorry but no provider is giving service in this area';
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Service Unavailable'),
          content: Text(displayError),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: AppTheme.primaryGreen)),
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<AppProvider, bool>((p) => p.isLoading);
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(lang.t('KaamSaaz', 'خدمت اے آئی', 'KaamSaaz')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            tooltip: lang.t('Settings', 'سیٹنگز', 'Settings'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UserProfileScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _currentIndex == 0 
          ? _buildServiceForm(isLoading) 
          : _currentIndex == 1
              ? AIChatbotScreen(userLat: _userLat, userLng: _userLng)
              : _currentIndex == 2
                  ? const MyBookingsScreen(status: 'pending')
                  : _currentIndex == 3
                      ? const MyBookingsScreen(status: 'confirmed')
                      : const MyBookingsScreen(status: 'completed'),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: AppTheme.primaryGreen,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.add_circle_outline),
            label: lang.t('New Request', 'نئی درخواست', 'Naya Request'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.smart_toy_outlined),
            label: lang.t('AI Chatbot', 'اے آئی چیٹ', 'AI Chatbot'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.hourglass_empty),
            label: lang.t('Pending', 'پینڈنگ', 'Pending'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.check_circle_outline),
            label: lang.t('Jobs Taken', 'فعال کام', 'Jobs Taken'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history),
            label: lang.t('Completed', 'مکمل شدہ', 'Completed'),
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0 ? const SafetyFab() : null,
    );
  }

  Widget _buildServiceForm(bool isLoading) {
    final lang = context.watch<LanguageProvider>();
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.t("What service do you need today?", "آج آپ کو کس سروس کی ضرورت ہے؟", "Aaj aap ko kis service ki zaroorat hai?"),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lang.t("Type in Roman Urdu, Urdu, or English (e.g. 'Mera AC kharab hai')", "اردو، رومن یا انگریزی میں لکھیں (جیسے 'میرا پنکھا خراب ہے')", "Urdu, Roman ya English mein likhein (jaise 'Mera AC kharab hai')"),
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),

              // ── GPS Location Banner ──────────────────────────────
              GestureDetector(
                onTap: () async {
                  if (!_hasRealLocation) await _fetchUserLocation(showFeedback: true);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _hasRealLocation
                          ? [const Color(0xFF00C853), const Color(0xFF1B5E20)]
                          : [Colors.orange.shade400, Colors.orange.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      if (_fetchingLocation)
                        const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      else
                        Icon(
                          _hasRealLocation ? Icons.my_location : Icons.location_searching,
                          color: Colors.white,
                          size: 20,
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                         child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _hasRealLocation
                                  ? (_customAddress != null ? lang.t('📍 Service Location Selected', '📍 منتخب کردہ مقام', '📍 Service Location Selected') : lang.t('📍 Live Location Active', '📍 لائیو لوکیشن فعال ہے', '📍 Live Location Active'))
                                  : lang.t('📡 Getting Your Location...', '📡 لوکیشن حاصل کی جا رہی ہے...', '📡 Location hasil ki ja rahi hai...'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              _hasRealLocation
                                  ? (_customAddress ?? lang.t('Showing nearest professionals to you', 'آپ کے قریبی خدمت گار دکھائے جا رہے ہیں', 'Aap ke qareebi professionals dikhaye ja rahe hain'))
                                  : lang.t('Tap to allow location access', 'لوکیشن کی اجازت دینے کے لیے ٹیپ کریں', 'Location access allow karne ke liye tap karain'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // View map button
                      GestureDetector(
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NearbyProvidersScreen(
                                serviceTypeFilter: _selectedCategory,
                                serviceLabel: _selectedCategory != null
                                    ? _categories
                                        .firstWhere(
                                          (c) => c['id'] == _selectedCategory,
                                          orElse: () => {'name': 'Service'},
                                        )['name']
                                        ?.split(' ')
                                        .first
                                    : null,
                              ),
                            ),
                          );
                          // If user selected location on the map picker
                          if (result != null && result is Map && mounted) {
                            if (result.containsKey('lat') && result.containsKey('lng')) {
                              setState(() {
                                _userLat = result['lat'];
                                _userLng = result['lng'];
                                _hasRealLocation = true;
                                _customAddress = result['address'];
                              });
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.map_outlined, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('Map', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true, // Prevents overflow!
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Select Service Category',
                  prefixIcon: const Icon(Icons.category, color: AppTheme.primaryGreen),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                  ),
                ),
                items: _categories.map((cat) {
                  return DropdownMenuItem<String>(
                    value: cat['id'],
                    child: Text(
                      cat['name']!,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCategory = val;
                      // Auto-populate prompt controller
                      if (val == 'plumber') {
                        _promptController.text = "Need a plumber urgently to fix a leaking pipe/tap.";
                      } else if (val == 'electrician') {
                        _promptController.text = "Need an electrician to fix a short circuit/fan installation.";
                      } else if (val == 'ac_mechanic') {
                        _promptController.text = "Mera AC kharab hai, check karne ke liye AC Mechanic chahiye.";
                      } else if (val == 'house_maid') {
                        _promptController.text = "Need a house maid for daily house cleaning.";
                      } else if (val == 'carpenter') {
                        _promptController.text = "Need a carpenter to repair a wooden door/cabinet.";
                      } else if (val == 'painter') {
                        _promptController.text = "Need a painter for wall painting services.";
                      } else if (val == 'gardener') {
                        _promptController.text = "Need a gardener for garden maintenance.";
                      } else if (val == 'tutor') {
                        _promptController.text = "Home tutor chahiye bache ko padhane ke liye.";
                      } else if (val == 'beautician') {
                        _promptController.text = "Ghar pe beauty parlor services / makeup ke liye beautician chahiye.";
                      } else if (val == 'generator') {
                        _promptController.text = "Generator repair karwana hai, starting problem fix karni hai.";
                      } else if (val == 'welder') {
                        _promptController.text = "Loha welding / gate repair ke liye professional welder chahiye.";
                      } else if (val == 'tiler') {
                        _promptController.text = "Ghar ke tiles lagwane / floor marble installation ke liye tiler chahiye.";
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _promptController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: "e.g. Need a plumber urgently near Gulberg...",
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _hasImage ? Icons.image : Icons.add_a_photo, 
                        color: _hasImage ? AppTheme.primaryGreen : AppTheme.textSecondary
                      ),
                      onPressed: () {
                        setState(() {
                          _hasImage = !_hasImage;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_hasImage ? "Photo attached to request!" : "Photo removed."),
                            duration: const Duration(seconds: 1),
                          )
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (date != null) {
                          setState(() {
                            _selectedDate = date;
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(_selectedDate != null ? "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}" : "Select Date"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _selectedDate != null ? AppTheme.primaryGreen : Colors.grey.shade700,
                        side: BorderSide(color: _selectedDate != null ? AppTheme.primaryGreen : Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null && mounted) {
                          setState(() {
                            _selectedTime = time;
                          });
                        }
                      },
                      icon: const Icon(Icons.access_time, size: 18),
                      label: Text(_selectedTime != null ? _selectedTime!.format(context) : "Select Time"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _selectedTime != null ? AppTheme.primaryGreen : Colors.grey.shade700,
                        side: BorderSide(color: _selectedTime != null ? AppTheme.primaryGreen : Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20, 
                          width: 20, 
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        )
                      : const Text(
                          "Find Professionals", 
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
