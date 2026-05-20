import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';

class EditProfileSheet extends StatefulWidget {
  final Map<String, dynamic> providerData;
  final String providerId;
  final VoidCallback onProfileUpdated;

  const EditProfileSheet({
    super.key,
    required this.providerData,
    required this.providerId,
    required this.onProfileUpdated,
  });

  static void show(
    BuildContext context, {
    required Map<String, dynamic> providerData,
    required String providerId,
    required VoidCallback onProfileUpdated,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => EditProfileSheet(
        providerData: providerData,
        providerId: providerId,
        onProfileUpdated: onProfileUpdated,
      ),
    );
  }

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late TextEditingController nameController;
  late TextEditingController areaController;
  late TextEditingController rateController;
  late String selectedPricingType;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.providerData['name_en'] ?? '');
    areaController = TextEditingController(text: widget.providerData['area_name'] ?? '');
    
    selectedPricingType = widget.providerData['pricing_type'] ?? 'hourly';
    
    int getInitialRate() {
      int val = 0;
      if (selectedPricingType == 'hourly') {
        val = widget.providerData['hourly_rate'] ?? 0;
      } else if (selectedPricingType == 'fixed') {
        val = widget.providerData['fixed_rate'] ?? 0;
      } else {
        val = widget.providerData['per_job_rate'] ?? 0;
      }
      if (val <= 0) val = widget.providerData['rate'] ?? 0;
      if (val <= 0) val = widget.providerData['hourly_rate'] ?? 0;
      if (val <= 0) val = 1500;
      return val;
    }
    
    rateController = TextEditingController(text: getInitialRate().toString());
  }

  @override
  void dispose() {
    nameController.dispose();
    areaController.dispose();
    rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                          setState(() {
                            selectedPricingType = 'hourly';
                            int val = widget.providerData['hourly_rate'] ?? 0;
                            if (val <= 0) val = widget.providerData['rate'] ?? 0;
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
                          setState(() {
                            selectedPricingType = 'fixed';
                            int val = widget.providerData['fixed_rate'] ?? 0;
                            if (val <= 0) val = widget.providerData['rate'] ?? 0;
                            if (val <= 0) val = widget.providerData['hourly_rate'] ?? 0;
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
                          setState(() {
                            selectedPricingType = 'per_job';
                            int val = widget.providerData['per_job_rate'] ?? 0;
                            if (val <= 0) val = widget.providerData['rate'] ?? 0;
                            if (val <= 0) val = widget.providerData['hourly_rate'] ?? 0;
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
                    
                    setState(() => isSaving = true);
                    
                    try {
                      final body = {
                        "name_en": name,
                        "area_name": area,
                        "pricing_type": selectedPricingType,
                        "rate": rateVal,
                      };
                      
                      final res = await http.put(
                        Uri.parse('${ApiService.baseUrl}/providers/${widget.providerId}/profile'),
                        headers: {
                          'Content-Type': 'application/json',
                          'ngrok-skip-browser-warning': 'true',
                        },
                        body: jsonEncode(body),
                      );
                      
                      if (!context.mounted) return;
                      if (res.statusCode == 200) {
                        Navigator.pop(context); // close bottom sheet
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Profile updated successfully!')),
                        );
                        widget.onProfileUpdated(); // refresh details
                      } else {
                        String errMsg = 'Failed to update profile';
                        try {
                          final data = jsonDecode(res.body);
                          if (data is Map && data.containsKey('detail')) {
                            errMsg = data['detail'];
                          } else if (data is Map && data.containsKey('message')) {
                            errMsg = data['message'];
                          }
                        } catch (_) {
                          errMsg = res.body;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('❌ $errMsg')),
                        );
                      }
                    } catch (err) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error updating profile: $err')),
                      );
                    } finally {
                      if (mounted) {
                        setState(() => isSaving = false);
                      }
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
  }
}
