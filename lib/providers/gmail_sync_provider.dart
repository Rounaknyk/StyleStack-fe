import 'package:flutter/foundation.dart';

import '../services/gmail_import_service.dart';
import '../services/analytics_service.dart';

enum GmailSyncPhase { idle, connecting, syncing, refreshing, completed, failed }

typedef GmailSyncRunner =
    Future<Map<String, int>> Function({void Function()? onConnectionComplete});

class GmailSyncProvider extends ChangeNotifier {
  GmailSyncProvider(GmailImportService service)
    : _runSync = service.connectAndImport;

  @visibleForTesting
  GmailSyncProvider.withRunner(this._runSync);

  final GmailSyncRunner _runSync;

  bool _isRunning = false;
  GmailSyncPhase _phase = GmailSyncPhase.idle;
  Map<String, int>? _result;
  String? _error;
  int _generation = 0;

  bool get isRunning => _isRunning;
  GmailSyncPhase get phase => _phase;
  Map<String, int>? get result => _result;
  String? get error => _error;

  Future<bool> start({required Future<void> Function() refreshWardrobe}) async {
    if (_isRunning) return false;

    final generation = ++_generation;
    _isRunning = true;
    _phase = GmailSyncPhase.connecting;
    _result = null;
    _error = null;
    notifyListeners();

    try {
      final result = await _runSync(
        onConnectionComplete: () {
          if (generation != _generation || !_isRunning) return;
          _phase = GmailSyncPhase.syncing;
          notifyListeners();
        },
      );
      if (generation != _generation) return false;

      _result = Map<String, int>.unmodifiable(result);
      _phase = GmailSyncPhase.refreshing;
      notifyListeners();
      await refreshWardrobe();
      if (generation != _generation) return false;

      _phase = GmailSyncPhase.completed;
      await AnalyticsService.instance.event(
        'gmail_sync_completed',
        parameters: {
          'imported_items': result['imported_items'] ?? 0,
          'processed_emails': result['processed_emails'] ?? 0,
        },
      );
      return true;
    } catch (exception) {
      if (generation != _generation) return false;
      _error = _readableError(exception);
      _phase = GmailSyncPhase.failed;
      await AnalyticsService.instance.event('gmail_sync_failed');
      return false;
    } finally {
      if (generation == _generation) {
        _isRunning = false;
        notifyListeners();
      }
    }
  }

  void reset() {
    _generation++;
    _isRunning = false;
    _phase = GmailSyncPhase.idle;
    _result = null;
    _error = null;
    notifyListeners();
  }

  String _readableError(Object exception) {
    final message = exception.toString().replaceFirst(
      RegExp(r'^(Exception|Error):\s*'),
      '',
    );
    return message.isEmpty
        ? 'Could not sync Gmail. Please try again.'
        : message;
  }
}
