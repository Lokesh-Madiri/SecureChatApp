import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  static const String _keyStorageKey = 'encryption_key';
  String? _encryptionKey;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _encryptionKey = prefs.getString(_keyStorageKey);

    if (_encryptionKey == null) {
      // Generate a simple key for basic encoding (not real encryption)
      _encryptionKey = _generateSimpleKey();
      await prefs.setString(_keyStorageKey, _encryptionKey!);
    }
  }

  String _generateSimpleKey() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  String encrypt(String plaintext) {
    try {
      // Simple encoding (not real encryption) for demonstration
      final bytes = utf8.encode(plaintext + _encryptionKey!);
      return base64.encode(bytes);
    } catch (e) {
      print("Encryption error: $e");
      return plaintext; // Return plaintext as fallback
    }
  }

  Future<String> decrypt(String ciphertext) async {
    try {
      // First try to decode as base64
      final bytes = base64.decode(ciphertext);
      String decoded = utf8.decode(bytes);

      // Remove the key suffix if it exists
      if (_encryptionKey != null && decoded.endsWith(_encryptionKey!)) {
        return decoded.substring(0, decoded.length - _encryptionKey!.length);
      }

      // If it doesn't end with the key, it might be an old format or plaintext
      return decoded;
    } catch (e) {
      print("Decryption error: $e");

      // If base64 decoding fails, assume it's plaintext
      return ciphertext;
    }
  }

  // Method to handle migration of old messages
  Future<String> decryptWithFallback(String ciphertext) async {
    try {
      // First try the normal decryption
      return await decrypt(ciphertext);
    } catch (e) {
      print("Primary decryption failed: $e");

      // If normal decryption fails, try to handle as plaintext
      return ciphertext;
    }
  }

  Future<void> resetKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyStorageKey);
    _encryptionKey = _generateSimpleKey();
    await prefs.setString(_keyStorageKey, _encryptionKey!);
  }
}
