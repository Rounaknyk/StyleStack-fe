import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylestack_fe/main.dart';

void main() {
  testWidgets(
    'Firebase phone callback keeps the existing authentication screen mounted',
    (tester) async {
      const callbackRoute =
          '/link?deep_link_id=https://stylestack-9032f.firebaseapp.com/'
          '__/auth/callback?authType=verifyApp';

      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Text('phone-entry-state'),
          onGenerateRoute: generateStyleStackRoute,
        ),
      );

      navigatorKey.currentState!.pushNamed(callbackRoute);
      await tester.pump();
      await tester.pump();

      expect(find.text('phone-entry-state'), findsOneWidget);
      expect(navigatorKey.currentState!.canPop(), isFalse);
    },
  );

  test('unrelated links remain available to other route handlers', () {
    expect(
      generateStyleStackRoute(const RouteSettings(name: '/wardrobe')),
      isNull,
    );
  });
}
