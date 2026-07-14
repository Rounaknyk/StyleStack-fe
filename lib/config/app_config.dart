import 'dart:io';

class AppConfig {
  static const _definedBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '87320160492-oc6bkr97kcr3n700tvgjh21ol9hi9l98.apps.googleusercontent.com',
  );

  static String get apiBaseUrl {
    if (_definedBaseUrl.isNotEmpty) return _definedBaseUrl;
    return Platform.isAndroid
        ? 'http://10.0.2.2:8000/api/v1'
        : 'http://192.168.1.7:8000/api/v1';
  }
}
