import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stylestack_fe/providers/gmail_sync_provider.dart';

void main() {
  test('runs once, reports phases, and refreshes the wardrobe', () async {
    final importCompleter = Completer<Map<String, int>>();
    final refreshCompleter = Completer<void>();
    void Function()? connectionComplete;
    var calls = 0;
    var refreshes = 0;
    final provider = GmailSyncProvider.withRunner(({onConnectionComplete}) {
      calls++;
      connectionComplete = onConnectionComplete;
      return importCompleter.future;
    });

    final firstRun = provider.start(
      refreshWardrobe: () {
        refreshes++;
        return refreshCompleter.future;
      },
    );

    expect(provider.isRunning, isTrue);
    expect(provider.phase, GmailSyncPhase.connecting);
    expect(provider.error, isNull);

    connectionComplete?.call();
    expect(provider.phase, GmailSyncPhase.syncing);

    final duplicateResult = await provider.start(
      refreshWardrobe: () async => refreshes++,
    );
    expect(duplicateResult, isFalse);
    expect(calls, 1);

    importCompleter.complete({'imported_items': 3, 'skipped_messages': 2});
    await Future<void>.delayed(Duration.zero);

    expect(provider.isRunning, isTrue);
    expect(provider.phase, GmailSyncPhase.refreshing);
    expect(provider.result?['imported_items'], 3);
    expect(refreshes, 1);

    refreshCompleter.complete();

    expect(await firstRun, isTrue);
    expect(provider.isRunning, isFalse);
    expect(provider.phase, GmailSyncPhase.completed);
  });

  test('exposes a readable error and can run again', () async {
    var shouldFail = true;
    final provider = GmailSyncProvider.withRunner(({
      onConnectionComplete,
    }) async {
      onConnectionComplete?.call();
      if (shouldFail) throw Exception('Gmail is unavailable.');
      return {'imported_items': 1};
    });

    expect(await provider.start(refreshWardrobe: () async {}), isFalse);
    expect(provider.isRunning, isFalse);
    expect(provider.phase, GmailSyncPhase.failed);
    expect(provider.error, 'Gmail is unavailable.');

    shouldFail = false;
    expect(await provider.start(refreshWardrobe: () async {}), isTrue);
    expect(provider.phase, GmailSyncPhase.completed);
    expect(provider.error, isNull);
  });

  test('reset clears state and ignores an in-flight result', () async {
    final importCompleter = Completer<Map<String, int>>();
    var refreshes = 0;
    final provider = GmailSyncProvider.withRunner(({onConnectionComplete}) {
      onConnectionComplete?.call();
      return importCompleter.future;
    });

    final run = provider.start(refreshWardrobe: () async => refreshes++);
    provider.reset();
    importCompleter.complete({'imported_items': 4});

    expect(await run, isFalse);
    expect(provider.isRunning, isFalse);
    expect(provider.phase, GmailSyncPhase.idle);
    expect(provider.result, isNull);
    expect(provider.error, isNull);
    expect(refreshes, 0);
  });
}
