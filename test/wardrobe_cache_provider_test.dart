import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stylestack_fe/models/clothing_analysis.dart';
import 'package:stylestack_fe/models/wardrobe_item.dart';
import 'package:stylestack_fe/providers/wardrobe_provider.dart';
import 'package:stylestack_fe/services/api_service.dart';
import 'package:stylestack_fe/services/wardrobe_cache.dart';

void main() {
  test(
    'shows cached wardrobe before background API refresh completes',
    () async {
      final cached = _item('cached', 'Cached shirt');
      final fresh = _item('fresh', 'Fresh shirt');
      final api = _CompletingApi();
      final cache = _MemoryWardrobeCache()..items = [cached];
      final provider = WardrobeProvider(api, cache: cache, ownerUid: 'user-1');

      final loading = provider.loadItems();
      await Future<void>.delayed(Duration.zero);

      expect(provider.items, [cached]);
      expect(provider.loading, isFalse);

      api.items.complete([fresh]);
      await loading;

      expect(provider.items, [fresh]);
      expect(cache.items, [fresh]);
    },
  );

  test(
    'optimistic upload is cached immediately and rolls back on failure',
    () async {
      final api = _CompletingApi();
      final cache = _MemoryWardrobeCache();
      final provider = WardrobeProvider(api, cache: cache, ownerUid: 'user-1');

      final pending = await provider.uploadOptimistically(
        image: File('/tmp/new-shirt.jpg'),
        name: 'New shirt',
        category: 'shirt',
      );

      expect(pending.isUploading, isTrue);
      expect(provider.items.single.id, pending.id);
      expect(cache.items.single.id, pending.id);

      api.upload.completeError(const ApiException('Upload unavailable'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(provider.items, isEmpty);
      expect(cache.items, isEmpty);
      expect(provider.error, 'Upload unavailable');
    },
  );
}

WardrobeItem _item(String id, String name) => WardrobeItem(
  id: id,
  name: name,
  category: 'shirt',
  createdAt: DateTime.utc(2026, 7, 19),
);

class _CompletingApi extends ApiService {
  final items = Completer<List<WardrobeItem>>();
  final upload = Completer<WardrobeItem>();

  @override
  Future<List<WardrobeItem>> fetchItems() => items.future;

  @override
  Future<WardrobeItem> uploadItem({
    required File image,
    required String name,
    required String category,
    String? brand,
    String? color,
    String? season,
    String? formality,
    String? description,
    List<String> tags = const [],
    ClothingAnalysis? aiAnalysis,
  }) => upload.future;
}

class _MemoryWardrobeCache implements WardrobeCacheStore {
  List<WardrobeItem> items = [];

  @override
  Future<void> clear(String ownerUid) async => items = [];

  @override
  Future<void> delete(String ownerUid, Iterable<String> itemIds) async {
    final ids = itemIds.toSet();
    items = items.where((item) => !ids.contains(item.id)).toList();
  }

  @override
  Future<List<WardrobeItem>> read(String ownerUid) async => [...items];

  @override
  Future<void> replace(String ownerUid, List<WardrobeItem> items) async {
    this.items = [...items];
  }

  @override
  Future<void> upsert(String ownerUid, WardrobeItem item) async {
    items = [item, ...items.where((existing) => existing.id != item.id)];
  }
}
