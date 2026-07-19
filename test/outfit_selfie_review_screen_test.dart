import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:stylestack_fe/config/design_system.dart';
import 'package:stylestack_fe/models/outfit_selfie.dart';
import 'package:stylestack_fe/models/wardrobe_item.dart';
import 'package:stylestack_fe/providers/wardrobe_provider.dart';
import 'package:stylestack_fe/screens/outfit_selfie_review_screen.dart';
import 'package:stylestack_fe/services/api_service.dart';

void main() {
  testWidgets('long wardrobe names do not overflow detection cards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final image = File(
      '${Directory.systemTemp.path}/stylestack-selfie-review.png',
    );
    image.writeAsBytesSync(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
    addTearDown(() {
      if (image.existsSync()) image.deleteSync();
    });

    final wardrobeItem = WardrobeItem(
      id: 'wardrobe-item-1',
      name: 'Multicolor Shirt',
      category: 'shirt',
      color: 'multicolor',
      aiTagStatus: 'completed',
      createdAt: DateTime(2026, 7, 15),
    );
    final longUnselectedItem = WardrobeItem(
      id: 'wardrobe-item-2',
      name: List.filled(
        12,
        'Extremely descriptive imported wardrobe product name',
      ).join(' '),
      category: 'jacket',
      color: 'black',
      aiTagStatus: 'completed',
      createdAt: DateTime(2026, 7, 15),
    );
    final detection = OutfitSelfieDetection(
      id: 'detection-1',
      detectedName: 'Color-block sweatshirt',
      category: 'shirt',
      color: 'multicolor',
      description: List.filled(
        8,
        'A detailed AI description that should wrap inside the card.',
      ).join(' '),
      visualTags: const ['color-block', 'crew-neck'],
      confidence: .92,
      selected: true,
      wardrobeItemId: wardrobeItem.id,
      wardrobeItem: wardrobeItem,
    );
    final api = _ReviewApi(
      analysis: OutfitSelfieAnalysis(
        qualityAcceptable: true,
        qualityScore: .95,
        qualityFeedback: 'Clear image',
        selfieId: 'selfie-1',
        detections: [detection],
      ),
      wardrobe: [wardrobeItem, longUnselectedItem],
    );
    final wardrobeProvider = WardrobeProvider(api);
    await wardrobeProvider.loadItems();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: wardrobeProvider,
        child: MaterialApp(
          theme: DesignSystem.buildTheme(),
          home: FTheme(
            data: DesignSystem.buildForuiTheme(),
            child: OutfitSelfieReviewScreen(
              image: image,
              api: api,
              onRetake: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -480));
    await tester.pumpAndSettle();

    expect(find.text('92% match'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Multicolor Shirt • multicolor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Multicolor Shirt • multicolor'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _ReviewApi extends ApiService {
  _ReviewApi({required this.analysis, required this.wardrobe});

  final OutfitSelfieAnalysis analysis;
  final List<WardrobeItem> wardrobe;

  @override
  Future<OutfitSelfieAnalysis> analyzeOutfitSelfie(File image) async =>
      analysis;

  @override
  Future<List<WardrobeItem>> fetchItems() async => wardrobe;
}
