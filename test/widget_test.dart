import 'package:flutter_test/flutter_test.dart';
import 'package:stylestack_fe/models/wardrobe_item.dart';

void main() {
  test('WardrobeItem parses backend JSON', () {
    final item = WardrobeItem.fromJson({
      'id': 'item-1',
      'name': 'Black blazer',
      'category': 'Outerwear',
      'image_url': 'https://example.test/image.jpg',
      'thumbnail_url': 'https://example.test/thumb.jpg',
      'is_favorite': true,
    });

    expect(item.id, 'item-1');
    expect(item.name, 'Black blazer');
    expect(item.imageUrl, 'https://example.test/image.jpg');
    expect(item.gridImageUrl, 'https://example.test/thumb.jpg');
    expect(item.isFavorite, isTrue);
  });

  test('WardrobeItem falls back to full image before thumbnail is ready', () {
    final item = WardrobeItem.fromJson({
      'id': 'item-2',
      'name': 'Processing item',
      'category': 'other',
      'image_url': 'https://example.test/incoming.jpg',
    });

    expect(item.gridImageUrl, 'https://example.test/incoming.jpg');
  });
}
