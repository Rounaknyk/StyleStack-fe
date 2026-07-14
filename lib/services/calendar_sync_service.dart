import 'package:google_sign_in/google_sign_in.dart';

import '../config/app_config.dart';
import 'api_service.dart';

class CalendarSyncService {
  CalendarSyncService(this._api);
  final ApiService _api;

  static const _calendarReadonly =
      'https://www.googleapis.com/auth/calendar.readonly';

  GoogleSignIn get _google => GoogleSignIn(
    scopes: const [_calendarReadonly],
    serverClientId: AppConfig.googleServerClientId,
    forceCodeForRefreshToken: true,
  );

  Future<Map<String, dynamic>> connectAndSync() async {
    final google = _google;
    await google.signOut();
    final account = await google.signIn();
    if (account == null) throw Exception('Calendar connection was cancelled.');
    final code = account.serverAuthCode;
    if (code == null || code.isEmpty) {
      throw Exception(
        'Google did not provide long-term Calendar access. Check the Web OAuth client ID.',
      );
    }
    return _api.connectGoogleCalendar(code, account.email);
  }

  Future<void> disconnect() async {
    await _api.disconnectGoogleCalendar();
    try {
      await _google.disconnect();
    } catch (_) {
      await _google.signOut();
    }
  }
}
