import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylestack_fe/config/custom_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all StyleStack motion assets are bundled valid Lottie documents',
    () async {
      for (final asset in <String>[
        StyleStackMotionAssets.universalLoader,
        StyleStackMotionAssets.outfitDesigner,
        StyleStackMotionAssets.emptyCloset,
      ]) {
        final source = await rootBundle.loadString(asset);
        final document = jsonDecode(source) as Map<String, dynamic>;

        expect(document['layers'], isA<List<dynamic>>(), reason: asset);
        expect(
          (document['layers'] as List<dynamic>),
          isNotEmpty,
          reason: asset,
        );
        expect(document['w'], isA<num>(), reason: asset);
        expect(document['h'], isA<num>(), reason: asset);
      }
    },
  );
}
