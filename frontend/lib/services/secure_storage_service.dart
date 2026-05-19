import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SecureLocalStorage extends LocalStorage {
  final FlutterSecureStorage _storage;

  SecureLocalStorage()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock,
          ),
        );

  // Key used to store Supabase session securely in TEE
  static const _sessionKey = 'supabase_session_secure_tee';

  @override
  Future<void> initialize() async {
    // No explicit initialization needed for flutter_secure_storage
  }

  @override
  Future<bool> hasAccessToken() async {
    try {
      return await _storage.containsKey(key: _sessionKey);
    } catch (e) {
      debugPrint("[SecureLocalStorage] Error checking TEE hasAccessToken: $e");
      return false;
    }
  }

  @override
  Future<String?> accessToken() async {
    try {
      return await _storage.read(key: _sessionKey);
    } catch (e) {
      debugPrint("[SecureLocalStorage] Error reading TEE accessToken: $e");
      return null;
    }
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await _storage.delete(key: _sessionKey);
      debugPrint("[SecureLocalStorage] Successfully removed persisted session from TEE.");
    } catch (e) {
      debugPrint("[SecureLocalStorage] Error removing TEE persisted session: $e");
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await _storage.write(key: _sessionKey, value: persistSessionString);
      debugPrint("[SecureLocalStorage] Successfully persisted session to TEE Secure Enclave / Keystore.");
    } catch (e) {
      debugPrint("[SecureLocalStorage] Error persisting session to TEE: $e");
    }
  }
}
