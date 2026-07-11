import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';
import '../models/wardrobe_item.dart';

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
    if (user == null) throw const ApiException('Please sign in again.', 401);
    final token = await user.getIdToken();
    if (token == null) throw const ApiException('Could not create an authentication token.', 401);
    return token;
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
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.apiBaseUrl}/wardrobe/items'),
    )
      ..headers['Authorization'] = 'Bearer ${await _token()}'
      ..fields['name'] = name.trim()
      ..fields['category'] = category.trim();
    final extension = image.path.split('.').last.toLowerCase();
    final subtype = extension == 'png' ? 'png' : extension == 'webp' ? 'webp' : 'jpeg';
    request.files.add(await http.MultipartFile.fromPath(
      'image',
      image.path,
      contentType: MediaType('image', subtype),
    ));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return WardrobeItem.fromJson(_decode(response) as Map<String, dynamic>);
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
