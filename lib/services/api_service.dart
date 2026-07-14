import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';
import '../models/wardrobe_item.dart';
import '../models/clothing_analysis.dart';
import '../models/outfit.dart';
import '../models/calendar_models.dart';
import '../models/outfit_selfie.dart';

class ApiException implements Exception {
  const ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<String> _token() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const ApiException('Please sign in again.', 401);
    }
    final token = await user.getIdToken();
    if (token == null) {
      throw const ApiException(
        'Could not create an authentication token.',
        401,
      );
    }
    return token;
  }

  Future<void> checkBackendHealth() async {
    final apiUri = Uri.parse(AppConfig.apiBaseUrl);
    final healthUri = apiUri.replace(path: '/health', query: null);
    final response = await _client
        .get(healthUri)
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      throw ApiException(
        'Backend health check returned ${response.statusCode}.',
      );
    }
  }

  Future<List<WardrobeItem>> fetchItems() async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/wardrobe/items'),
      headers: {'Authorization': 'Bearer ${await _token()}'},
    );
    final body = _decode(response);
    return (body as List<dynamic>)
        .map((item) => WardrobeItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<WardrobeItem> uploadItem({
    required File image,
    required String name,
    required String category,
    String? color,
    String? season,
    String? formality,
    String? description,
    List<String> tags = const [],
    ClothingAnalysis? aiAnalysis,
  }) async {
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('${AppConfig.apiBaseUrl}/wardrobe/items'),
          )
          ..headers['Authorization'] = 'Bearer ${await _token()}'
          ..fields['name'] = name.trim()
          ..fields['category'] = category.trim();
    if (color?.trim().isNotEmpty == true) {
      request.fields['color'] = color!.trim();
    }
    if (season?.trim().isNotEmpty == true) {
      request.fields['season'] = season!.trim();
    }
    if (formality?.trim().isNotEmpty == true) {
      request.fields['formality'] = formality!.trim();
    }
    if (description?.trim().isNotEmpty == true) {
      request.fields['description'] = description!.trim();
    }
    if (tags.isNotEmpty) {
      request.fields['tags'] = tags.join(',');
    }
    if (aiAnalysis != null) {
      request.fields.addAll({
        'ai_category': aiAnalysis.category,
        'ai_color': aiAnalysis.color,
        'ai_season': aiAnalysis.season,
        'ai_formality': aiAnalysis.formality,
        'ai_description': aiAnalysis.description,
        'ai_tags': aiAnalysis.tags.join(','),
      });
    }
    final extension = image.path.split('.').last.toLowerCase();
    final subtype = extension == 'png'
        ? 'png'
        : extension == 'webp'
        ? 'webp'
        : 'jpeg';
    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        image.path,
        contentType: MediaType('image', subtype),
      ),
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return WardrobeItem.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<ClothingAnalysis> analyzeImage(File image) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.apiBaseUrl}/wardrobe/analyze-image'),
    )..headers['Authorization'] = 'Bearer ${await _token()}';
    final extension = image.path.split('.').last.toLowerCase();
    final subtype = extension == 'png'
        ? 'png'
        : extension == 'webp'
        ? 'webp'
        : 'jpeg';
    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        image.path,
        contentType: MediaType('image', subtype),
      ),
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return ClothingAnalysis.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<List<ClothingAnalysis>> detectItems(File image) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.apiBaseUrl}/wardrobe/detect-items'),
    )..headers['Authorization'] = 'Bearer ${await _token()}';
    final extension = image.path.split('.').last.toLowerCase();
    final subtype = extension == 'png'
        ? 'png'
        : extension == 'webp'
        ? 'webp'
        : 'jpeg';
    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        image.path,
        contentType: MediaType('image', subtype),
      ),
    );
    final response = await http.Response.fromStream(await request.send());
    return ClothingDetection.fromJson(
      _decode(response) as Map<String, dynamic>,
    ).items;
  }

  Future<OutfitSelfieAnalysis> analyzeOutfitSelfie(File image) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.apiBaseUrl}/wardrobe/outfit-selfies/analyze'),
    )..headers['Authorization'] = 'Bearer ${await _token()}';
    final extension = image.path.split('.').last.toLowerCase();
    final subtype = extension == 'png'
        ? 'png'
        : extension == 'webp'
        ? 'webp'
        : 'jpeg';
    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        image.path,
        contentType: MediaType('image', subtype),
      ),
    );
    final response = await http.Response.fromStream(await request.send());
    return OutfitSelfieAnalysis.fromJson(
      _decode(response) as Map<String, dynamic>,
    );
  }

  Future<OutfitSelfieConfirmationResult> confirmOutfitSelfie(
    String selfieId,
    List<OutfitSelfieDetection> detections,
  ) async {
    final response = await _client.post(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/wardrobe/outfit-selfies/$selfieId/confirm',
      ),
      headers: {
        'Authorization': 'Bearer ${await _token()}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'detections': detections
            .map(
              (item) => {
                'detection_id': item.id,
                'selected': item.selected,
                'wardrobe_item_id': item.wardrobeItemId,
              },
            )
            .toList(),
      }),
    );
    return OutfitSelfieConfirmationResult.fromJson(
      _decode(response) as Map<String, dynamic>,
    );
  }

  Future<void> discardOutfitSelfie(String selfieId) async {
    final response = await _client.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/wardrobe/outfit-selfies/$selfieId'),
      headers: {'Authorization': 'Bearer ${await _token()}'},
    );
    _decode(response);
  }

  Future<List<OutfitSelfieHistoryEntry>> fetchOutfitSelfieHistory() async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/wardrobe/outfit-selfies/history'),
      headers: {'Authorization': 'Bearer ${await _token()}'},
    );
    return (_decode(response) as List<dynamic>)
        .map(
          (item) =>
              OutfitSelfieHistoryEntry.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> deleteItem(String itemId) async {
    final response = await _client.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/wardrobe/items/$itemId'),
      headers: {'Authorization': 'Bearer ${await _token()}'},
    );
    _decode(response);
  }

  Future<WardrobeItem> fetchItem(String itemId) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/wardrobe/items/$itemId'),
      headers: {'Authorization': 'Bearer ${await _token()}'},
    );
    return WardrobeItem.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<WardrobeItem> updateItem(
    String itemId,
    Map<String, dynamic> fields,
  ) async {
    final response = await _client.put(
      Uri.parse('${AppConfig.apiBaseUrl}/wardrobe/items/$itemId'),
      headers: {
        'Authorization': 'Bearer ${await _token()}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(fields),
    );
    return WardrobeItem.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<Outfit> suggestOutfit({
    required String city,
    required String occasion,
    String? calendarEventId,
  }) async {
    final payload = <String, String>{'city': city, 'occasion': occasion};
    if (calendarEventId != null) {
      payload['calendar_event_id'] = calendarEventId;
    }
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/outfits/suggest'),
      headers: {
        'Authorization': 'Bearer ${await _token()}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );
    return Outfit.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<int> wearOutfit(String outfitId) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/outfits/$outfitId/wear'),
      headers: {'Authorization': 'Bearer ${await _token()}'},
    );
    return (_decode(response) as Map<String, dynamic>)['logged_items'] as int;
  }

  Future<Outfit> fetchOutfit(String outfitId) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/outfits/$outfitId'),
      headers: {'Authorization': 'Bearer ${await _token()}'},
    );
    return Outfit.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<UserPreferences> fetchPreferences() async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/users/me/preferences'),
      headers: {'Authorization': 'Bearer ${await _token()}'},
    );
    return UserPreferences.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<UserPreferences> updatePreferences(Map<String, dynamic> fields) async {
    final response = await _client.put(
      Uri.parse('${AppConfig.apiBaseUrl}/users/me/preferences'),
      headers: {
        'Authorization': 'Bearer ${await _token()}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(fields),
    );
    return UserPreferences.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<void> registerDevice(String token, String platform) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/users/me/devices'),
      headers: {
        'Authorization': 'Bearer ${await _token()}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'token': token, 'platform': platform}),
    );
    _decode(response);
  }

  Future<Map<String, int>> sendTestNotification() async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/users/me/test-notification'),
      headers: {'Authorization': 'Bearer ${await _token()}'},
    );
    final result = _decode(response) as Map<String, dynamic>;
    return {
      'success_count': result['success_count'] as int,
      'failure_count': result['failure_count'] as int,
    };
  }

  Future<Map<String, dynamic>> runNotificationSimulation(
    String simulation,
  ) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/users/me/simulations/$simulation'),
      headers: {'Authorization': 'Bearer ${await _token()}'},
    );
    return _decode(response) as Map<String, dynamic>;
  }

  Future<Map<String, int>> importGmailOrders(String accessToken) async {
    final payload = <String, Object>{
      'access_token': accessToken,
      'max_messages': 50,
    };
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/imports/gmail'),
      headers: {
        'Authorization': 'Bearer ${await _token()}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );
    final result = _decode(response) as Map<String, dynamic>;
    return {
      'scanned_messages': result['scanned_messages'] as int? ?? 0,
      'imported_items': result['imported_items'] as int? ?? 0,
      'skipped_items': result['skipped_items'] as int? ?? 0,
    };
  }

  Future<List<StyleCalendarEvent>> fetchCalendarEvents({
    DateTime? start,
    DateTime? end,
  }) async {
    final query = <String, String>{};
    if (start != null) query['start'] = start.toUtc().toIso8601String();
    if (end != null) query['end'] = end.toUtc().toIso8601String();
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/calendar/events',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer ${await _token()}'},
    );
    return (_decode(response) as List<dynamic>)
        .map(
          (item) => StyleCalendarEvent.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<StyleCalendarEvent> createCalendarEvent(
    Map<String, dynamic> fields,
  ) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/calendar/events'),
      headers: {
        'Authorization': 'Bearer ${await _token()}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(fields),
    );
    return StyleCalendarEvent.fromJson(
      _decode(response) as Map<String, dynamic>,
    );
  }

  Future<void> deleteCalendarEvent(String eventId) async {
    final response = await _client.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/calendar/events/$eventId'),
      headers: {'Authorization': 'Bearer ${await _token()}'},
    );
    _decode(response);
  }

  Future<Map<String, dynamic>> fetchGoogleCalendarStatus() async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/calendar/google/status'),
      headers: {'Authorization': 'Bearer ${await _token()}'},
    );
    return _decode(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> connectGoogleCalendar(
    String serverAuthCode,
    String email,
  ) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/calendar/google/connect'),
      headers: {
        'Authorization': 'Bearer ${await _token()}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'server_auth_code': serverAuthCode, 'email': email}),
    );
    return _decode(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> syncGoogleCalendar() async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/calendar/google/sync'),
      headers: {'Authorization': 'Bearer ${await _token()}'},
    );
    return _decode(response) as Map<String, dynamic>;
  }

  Future<void> disconnectGoogleCalendar() async {
    final response = await _client.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/calendar/google/connection'),
      headers: {'Authorization': 'Bearer ${await _token()}'},
    );
    _decode(response);
  }

  Future<List<StyleNotification>> fetchNotifications() async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/calendar/notifications'),
      headers: {'Authorization': 'Bearer ${await _token()}'},
    );
    return (_decode(response) as List<dynamic>)
        .map((item) => StyleNotification.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> markNotificationRead(String notificationId) async {
    final response = await _client.post(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/calendar/notifications/$notificationId/read',
      ),
      headers: {'Authorization': 'Bearer ${await _token()}'},
    );
    _decode(response);
  }

  dynamic _decode(http.Response response) {
    dynamic body;
    try {
      body = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      body = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = body is Map<String, dynamic> ? body['detail'] : null;
      throw ApiException(
        detail is String ? detail : 'Request failed. Please try again.',
        response.statusCode,
      );
    }
    return body;
  }
}
