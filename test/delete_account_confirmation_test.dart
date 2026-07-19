import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylestack_fe/screens/profile_settings_view.dart';

void main() {
  testWidgets('delete confirmation closes without widget lifecycle errors', (
    tester,
  ) async {
    bool? confirmed;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                confirmed = await showDeleteAccountConfirmation(context);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
