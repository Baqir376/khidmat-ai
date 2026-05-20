import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { english, urdu }

class LanguageProvider extends ChangeNotifier {
  AppLanguage _language = AppLanguage.english;

  AppLanguage get language => _language;
  bool get isUrdu => _language == AppLanguage.urdu;
  String get languageCode => isUrdu ? 'ur' : 'en';

  LanguageProvider() {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_language') ?? 'en';
    _language = saved == 'ur' ? AppLanguage.urdu : AppLanguage.english;
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage lang) async {
    if (_language == lang) return;
    _language = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', lang == AppLanguage.urdu ? 'ur' : 'en');
  }

  void toggle() {
    setLanguage(isUrdu ? AppLanguage.english : AppLanguage.urdu);
  }

  /// Shorthand: get text in current language
  String t(String en, String ur) => isUrdu ? ur : en;
}
