import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/runtime_config.dart';
import '../models/onboarding_profile.dart';

abstract class OnboardingRepository {
  Future<OnboardingProfile> fetch();
  Future<OnboardingProfile> save(OnboardingProfile profile);
}

class OnboardingService implements OnboardingRepository {
  OnboardingService({http.Client? client, FirebaseAuth? firebaseAuth})
    : _client = client ?? http.Client(),
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final http.Client _client;
  final FirebaseAuth _firebaseAuth;

  @override
  Future<OnboardingProfile> fetch() async {
    final response = await _client.get(
      Uri.parse('${RuntimeConfig.apiBaseUrl}/users/me/onboarding'),
      headers: await _headers(),
    );
    return OnboardingProfile.fromJson(_decode(response));
  }

  @override
  Future<OnboardingProfile> save(OnboardingProfile profile) async {
    final response = await _client.put(
      Uri.parse('${RuntimeConfig.apiBaseUrl}/users/me/onboarding'),
      headers: await _headers(json: true),
      body: jsonEncode(profile.toJson()),
    );
    return OnboardingProfile.fromJson(_decode(response));
  }

  Future<Map<String, String>> _headers({bool json = false}) async {
    final token = await _firebaseAuth.currentUser?.getIdToken();
    if (token == null || token.isEmpty) {
      throw const OnboardingServiceException(
        'Your session expired. Please sign in again.',
      );
    }
    return {
      'Authorization': 'Bearer $token',
      if (json) 'Content-Type': 'application/json',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    dynamic body;
    try {
      body = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      body = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = body is Map<String, dynamic> ? body['detail'] : null;
      throw OnboardingServiceException(
        detail is String && detail.isNotEmpty
            ? detail
            : 'Could not save your StyleStack profile.',
      );
    }
    if (body is! Map<String, dynamic>) {
      throw const OnboardingServiceException(
        'StyleStack returned an unexpected response.',
      );
    }
    return body;
  }
}

class OnboardingServiceException implements Exception {
  const OnboardingServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}
