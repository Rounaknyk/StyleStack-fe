import 'package:google_sign_in/google_sign_in.dart';

import 'api_service.dart';

class GmailImportService {
  GmailImportService(this._api);
  final ApiService _api;

  static const _gmailReadonly =
      'https://www.googleapis.com/auth/gmail.readonly';

  Future<Map<String, int>> connectAndImport() async {
    final google = GoogleSignIn(scopes: const [_gmailReadonly]);
    final account = await google.signIn();
    if (account == null) throw Exception('Gmail connection was cancelled.');
    final auth = await account.authentication;
    final token = auth.accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('Google did not provide Gmail access.');
    }
    return _api.importGmailOrders(token);
  }
}
