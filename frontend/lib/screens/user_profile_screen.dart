import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/language_provider.dart';
import '../theme/app_theme.dart';

class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  void _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final user = Supabase.instance.client.auth.currentUser;
    final userEmail = user?.email ?? 'user@example.com';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(lang.t('Profile & Settings', 'پروفائل اور سیٹنگز', 'Profile & Settings')),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User Info Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: AppTheme.primaryGreen, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang.t('Customer Profile', 'کسٹمر پروفائل', 'Customer Profile'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userEmail,
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Settings Section
          Text(
            lang.t('Settings', 'سیٹنگز', 'Settings'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 1,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language, color: AppTheme.primaryGreen),
                  title: Text(lang.t('App Language', 'ایپ کی زبان', 'App Language')),
                  trailing: DropdownButton<AppLanguage>(
                    value: lang.language,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: AppLanguage.english, child: Text('English 🇬🇧')),
                      DropdownMenuItem(value: AppLanguage.urdu, child: Text('اردو (Pure) 🇵🇰')),
                      DropdownMenuItem(value: AppLanguage.romanUrdu, child: Text('Roman Urdu 🇵🇰')),
                    ],
                    onChanged: (AppLanguage? newLang) {
                      if (newLang != null) {
                        lang.setLanguage(newLang);
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security, color: Colors.blue),
                  title: Text(lang.t('Account Security', 'اکاؤنٹ سیکیورٹی', 'Account Security')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(lang.t('TEE Security is active.', 'ٹی ای ای سیکیورٹی فعال ہے۔', 'TEE Security is active.'))),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Logout Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: Text(
                lang.t('Logout', 'لاگ آؤٹ', 'Logout'),
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
