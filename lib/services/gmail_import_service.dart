import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';

import 'api_service.dart';

class GmailImportService {
  GmailImportService(this._api);
  final ApiService _api;

  static const _gmailReadonly =
      'https://www.googleapis.com/auth/gmail.readonly';

  Future<Map<String, int>> connectAndImport({
    void Function()? onConnectionComplete,
  }) async {
    final google = GoogleSignIn(scopes: const [_gmailReadonly]);
    final account = await google.signIn();
    if (account == null) throw Exception('Gmail connection was cancelled.');
    final auth = await account.authentication;
    final token = auth.accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('Google did not provide Gmail access.');
    }
    onConnectionComplete?.call();
    var job = await _api.startGmailImportJob(token);
    final jobId = job['job_id'] as String?;
    if (jobId == null || jobId.isEmpty) {
      throw Exception('StyleStack could not start Closet Sync.');
    }

    while (true) {
      final status = job['status'] as String? ?? 'failed';
      if (status == 'completed') {
        return {
          'scanned_messages': job['scanned_messages'] as int? ?? 0,
          'imported_items': job['imported_items'] as int? ?? 0,
          'skipped_items': job['skipped_items'] as int? ?? 0,
        };
      }
      if (status == 'failed') {
        throw Exception(
          job['error'] as String? ??
              'Could not finish Gmail sync. Please reconnect and retry.',
        );
      }
      await Future<void>.delayed(const Duration(seconds: 2));
      job = await _api.fetchGmailImportJob(jobId);
    }
  }
}
