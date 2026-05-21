import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { english, urdu, romanUrdu }

class LanguageProvider extends ChangeNotifier {
  AppLanguage _language = AppLanguage.english;

  AppLanguage get language => _language;
  bool get isUrdu => _language == AppLanguage.urdu;
  bool get isRomanUrdu => _language == AppLanguage.romanUrdu;

  String get languageCode {
    if (isUrdu) return 'ur';
    if (isRomanUrdu) return 'ru';
    return 'en';
  }

  LanguageProvider() {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_language') ?? 'en';
    if (saved == 'ur') {
      _language = AppLanguage.urdu;
    } else if (saved == 'ru') {
      _language = AppLanguage.romanUrdu;
    } else {
      _language = AppLanguage.english;
    }
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage lang) async {
    if (_language == lang) return;
    _language = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    String code = 'en';
    if (lang == AppLanguage.urdu) code = 'ur';
    if (lang == AppLanguage.romanUrdu) code = 'ru';
    await prefs.setString('app_language', code);
  }

  void toggle() {
    if (_language == AppLanguage.english) {
      setLanguage(AppLanguage.urdu);
    } else if (_language == AppLanguage.urdu) {
      setLanguage(AppLanguage.romanUrdu);
    } else {
      setLanguage(AppLanguage.english);
    }
  }

  /// Shorthand: get text in current language
  /// [en] = English, [ur] = Pure Urdu, [ru] = Roman Urdu (optional, falls back to en)
  String t(String en, String ur, [String? ru]) {
    if (isUrdu) return ur;
    if (isRomanUrdu) return ru ?? en;
    return en;
  }
}
