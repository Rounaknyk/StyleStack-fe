import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylestack_fe/screens/style_story_share_screen.dart';

void main() {
  testWidgets('story card uses a fixed 9:16 canvas with StyleStack branding', (
    tester,
  ) async {
    final transparentPixel = Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
        'AAAADUlEQVQIHWP4z8DwHwAFgAI/ScL9WQAAAABJRU5ErkJggg==',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: FittedBox(
            child: StyleStoryCard(
              canvasImage: MemoryImage(transparentPixel),
              styleName: 'Sunday layers',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('STYLESTACK'), findsOneWidget);
    expect(find.text('BUILT FROM YOUR WARDROBE'), findsOneWidget);
    expect(find.text('Sunday layers'), findsOneWidget);
    expect(find.text('CREATE YOUR LOOK'), findsOneWidget);

    final size = tester.getSize(find.byType(StyleStoryCard));
    expect(size, const Size(360, 640));
    expect(size.width / size.height, closeTo(9 / 16, .0001));
  });
}
