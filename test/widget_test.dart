import 'package:flutter_test/flutter_test.dart';
import 'package:stylestack_fe/models/wardrobe_item.dart';

void main() {
  test('WardrobeItem parses backend JSON', () {
    final item = WardrobeItem.fromJson({
      'id': 'item-1',
      'name': 'Black blazer',
      'category': 'Outerwear',
      'image_url': 'https://example.test/image.jpg',
      'is_favorite': true,
    });

    expect(item.id, 'item-1');
    expect(item.name, 'Black blazer');
    expect(item.imageUrl, 'https://example.test/image.jpg');
    expect(item.isFavorite, isTrue);
  });
}
