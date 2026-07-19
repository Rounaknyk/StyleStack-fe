import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/wardrobe_item.dart';

abstract class WardrobeCacheStore {
  Future<List<WardrobeItem>> read(String ownerUid);
  Future<void> replace(String ownerUid, List<WardrobeItem> items);
  Future<void> upsert(String ownerUid, WardrobeItem item);
  Future<void> delete(String ownerUid, Iterable<String> itemIds);
  Future<void> clear(String ownerUid);
}

class SqliteWardrobeCache implements WardrobeCacheStore {
  Database? _database;

  Future<Database> get _db async {
    if (_database != null) return _database!;
    final databasePath = await getDatabasesPath();
    _database = await openDatabase(
      path.join(databasePath, 'stylestack_cache.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE wardrobe_items (
            owner_uid TEXT NOT NULL,
            item_id TEXT NOT NULL,
            payload TEXT NOT NULL,
            cached_at INTEGER NOT NULL,
            PRIMARY KEY (owner_uid, item_id)
          )
        ''');
        await db.execute(
          'CREATE INDEX wardrobe_items_owner_cached '
          'ON wardrobe_items (owner_uid, cached_at DESC)',
        );
      },
    );
    return _database!;
  }

  @override
  Future<List<WardrobeItem>> read(String ownerUid) async {
    final rows = await (await _db).query(
      'wardrobe_items',
      columns: ['payload'],
      where: 'owner_uid = ?',
      whereArgs: [ownerUid],
      orderBy: 'cached_at DESC',
    );
    final items = <WardrobeItem>[];
    for (final row in rows) {
      try {
        items.add(
          WardrobeItem.fromJson(
            jsonDecode(row['payload']! as String) as Map<String, dynamic>,
          ),
        );
      } catch (_) {
        // Ignore a single damaged cache row. The API refresh repairs the cache.
      }
    }
    return items;
  }

  @override
  Future<void> replace(String ownerUid, List<WardrobeItem> items) async {
    final db = await _db;
    await db.transaction((transaction) async {
      await transaction.delete(
        'wardrobe_items',
        where: 'owner_uid = ?',
        whereArgs: [ownerUid],
      );
      for (final item in items) {
        await _insert(transaction, ownerUid, item);
      }
    });
  }

  @override
  Future<void> upsert(String ownerUid, WardrobeItem item) async {
    await _insert(await _db, ownerUid, item);
  }

  Future<void> _insert(
    DatabaseExecutor executor,
    String ownerUid,
    WardrobeItem item,
  ) => executor.insert('wardrobe_items', {
    'owner_uid': ownerUid,
    'item_id': item.id,
    'payload': jsonEncode(item.toJson()),
    'cached_at': item.createdAt.millisecondsSinceEpoch,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<void> delete(String ownerUid, Iterable<String> itemIds) async {
    final ids = itemIds.toList();
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    await (await _db).delete(
      'wardrobe_items',
      where: 'owner_uid = ? AND item_id IN ($placeholders)',
      whereArgs: [ownerUid, ...ids],
    );
  }

  @override
  Future<void> clear(String ownerUid) async {
    await (await _db).delete(
      'wardrobe_items',
      where: 'owner_uid = ?',
      whereArgs: [ownerUid],
    );
  }
}
