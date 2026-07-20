import 'package:flutter_test/flutter_test.dart';
import 'package:stylestack_fe/models/wear_history_entry.dart';

void main() {
  test('parses a grouped wear-history entry with wardrobe items', () {
    final entry = WearHistoryEntry.fromJson({
      'id': 'log-1',
      'worn_at': '2026-07-20T08:00:00Z',
      'notes': 'Outfit outfit-1',
      'items': [
        {
          'id': 'item-1',
          'owner_firebase_uid': 'user-1',
          'name': 'White shirt',
          'category': 'shirt',
          'is_favorite': false,
          'tagged': true,
          'ai_tag_status': 'completed',
          'created_at': '2026-07-18T08:00:00Z',
          'updated_at': '2026-07-18T08:00:00Z',
        },
      ],
    });

    expect(entry.id, 'log-1');
    expect(entry.items, hasLength(1));
    expect(entry.items.single.name, 'White shirt');
    expect(entry.wornAt.toUtc(), DateTime.utc(2026, 7, 20, 8));
  });
}
