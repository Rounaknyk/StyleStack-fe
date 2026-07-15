import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _useLocalhostKey = 'use_localhost_api';
  static const String _localhostUrlKey = 'localhost_url';

  bool _useLocalhost = false;
  String _localhostUrl = 'http://192.168.1.7:8000/api/v1';
  late SharedPreferences _prefs;

  bool get useLocalhost => _useLocalhost;
  String get localhostUrl => _localhostUrl;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _useLocalhost = _prefs.getBool(_useLocalhostKey) ?? false;
    _localhostUrl = _prefs.getString(_localhostUrlKey) ?? 'http://192.168.1.7:8000/api/v1';
  }

  Future<void> setUseLocalhost(bool value) async {
    _useLocalhost = value;
    await _prefs.setBool(_useLocalhostKey, value);
    notifyListeners();
  }

  Future<void> setLocalhostUrl(String url) async {
    _localhostUrl = url;
    await _prefs.setString(_localhostUrlKey, url);
    notifyListeners();
  }
}
