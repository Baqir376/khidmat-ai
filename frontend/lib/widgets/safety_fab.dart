import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class SafetyFab extends StatelessWidget {
  const SafetyFab({super.key});

  @override
  Widget build(BuildContext context) {
    final isEnabled = context.select<AppProvider, bool>((p) => p.isSafetyModeEnabled);

    return FloatingActionButton.extended(
      onPressed: () {
        context.read<AppProvider>().toggleSafetyMode(!isEnabled);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !isEnabled 
                  ? "Women's Safety Mode Enabled - Routing to verified female professionals only." 
                  : "Women's Safety Mode Disabled."
            ),
            backgroundColor: !isEnabled ? Colors.pink : Colors.grey,
            duration: const Duration(seconds: 3),
          ),
        );
      },
      backgroundColor: isEnabled ? Colors.pink : Colors.white,
      icon: Icon(
        Icons.security,
        color: isEnabled ? Colors.white : Colors.pink,
      ),
      label: Text(
        isEnabled ? "Safety Mode ON" : "Safety Mode",
        style: TextStyle(
          color: isEnabled ? Colors.white : Colors.pink,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
