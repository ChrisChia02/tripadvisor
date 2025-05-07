import 'dart:async'; // Add this import
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart'; // Add this

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  late final StreamController<String?> _simpleIdController; // Properly declared

  AuthService() {
    _simpleIdController =
        StreamController<String?>.broadcast(); // Initialized in constructor
  }

  Stream<String?> get simpleIdStream => _simpleIdController.stream;

  Future<void> initAuthListener() async {
    _auth.authStateChanges().listen((user) async {
      if (user != null) {
        try {
          final response = await http.get(
            Uri.parse(
              'https://tripadvisor-hgg4.onrender.com/users/${user.uid}',
            ),
          );

          if (response.statusCode == 200) {
            final userData = jsonDecode(response.body);
            final simpleId = userData['simple_id'] as String?;
            await _storage.write(key: 'simple_id', value: simpleId);
            _simpleIdController.add(simpleId);
          }
        } catch (e) {
          debugPrint('Error fetching simple_id: $e');
          _simpleIdController.add(null);
        }
      } else {
        await _storage.delete(key: 'simple_id');
        _simpleIdController.add(null);
      }
    });
  }

  Future<String?> getSimpleId() async {
    return await _storage.read(key: 'simple_id');
  }

  void dispose() {
    _simpleIdController.close(); // Prevent memory leaks
  }

  Future<void> login(String email, String password) async {
    try {
      // 1. Authenticate with Firebase
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Fetch simple_id from YOUR backend
      final response = await http.get(
        Uri.parse(
          'https://tripadvisor-hgg4.onrender.com/users/${userCredential.user!.uid}',
        ),
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        await _storage.write(key: 'simple_id', value: userData['simple_id']);
        _simpleIdController.add(userData['simple_id']); // Notify listeners
      } else {
        throw Exception('Failed to fetch simple_id');
      }
    } catch (e) {
      debugPrint('Login error: $e');
      rethrow;
    }
  }
}
