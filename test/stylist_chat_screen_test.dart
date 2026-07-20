import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylestack_fe/config/design_system.dart';
import 'package:stylestack_fe/screens/stylist_chat_screen.dart';

void main() {
  testWidgets('stylist opens as a focused editorial prompt', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DesignSystem.buildTheme(),
        home: const StylistChatScreen(city: 'Mumbai'),
      ),
    );
    await tester.pump();

    expect(find.text('Your stylist'), findsOneWidget);
    expect(find.text('Hi, I’m your StyleStack stylist.'), findsOneWidget);
    expect(find.text('What are you dressing for?'), findsOneWidget);
    expect(find.text('Create my look'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Interview'), findsOneWidget);
    expect(find.text('Date night'), findsOneWidget);
  });
}
