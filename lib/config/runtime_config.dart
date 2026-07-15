import '../providers/settings_provider.dart';

class RuntimeConfig {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://stylestack-be.onrender.com/api/v1',
  );
  static SettingsProvider? _settingsProvider;

  static void setSettingsProvider(SettingsProvider provider) {
    _settingsProvider = provider;
  }

  static String get apiBaseUrl {
    // If using localhost is enabled and we have a settings provider, use localhost URL
    if (_settingsProvider?.useLocalhost == true) {
      return _settingsProvider!.localhostUrl;
    }

    // Otherwise use the hosted URL
    return _configuredBaseUrl;
  }
}
