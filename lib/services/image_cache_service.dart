import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/wardrobe_item.dart';

/// A small, bounded disk cache for remote wardrobe and inspiration images.
///
/// Remote photos are server-owned. The app retains only resized copies for a
/// short time, so browsing feels instant without silently consuming hundreds
/// of megabytes on a user's device.
class _StyleStackCacheManager extends CacheManager with ImageCacheManager {
  _StyleStackCacheManager(super.config);
}

class StyleStackImageCache {
  StyleStackImageCache._();

  static const _migrationKey = 'image_cache_policy_v1_applied';

  static final CacheManager instance = _StyleStackCacheManager(
    Config(
      'stylestack-image-cache-v1',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 45,
    ),
  );

  static void configureMemoryCache() {
    // Keep decoded images from growing freely while the user scrolls grids.
    PaintingBinding.instance.imageCache.maximumSize = 120;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 32 * 1024 * 1024;
  }

  static Future<void> migrateLegacyCacheOnce() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_migrationKey) == true) return;

    // Earlier versions used CachedNetworkImage's unlimited default cache.
    // Clear it one time after upgrade; wardrobe data and uploads are untouched.
    await DefaultCacheManager().emptyCache();
    await preferences.setBool(_migrationKey, true);
  }

  /// Stores the images most likely to appear in the wardrobe grid before the
  /// user reaches that tab. This runs in the background: it never delays UI.
  /// Cache keys are stable across refreshed signed URLs, so a cached thumbnail
  /// remains available instantly on later app launches.
  static Future<void> warmWardrobeGrid(
    Iterable<WardrobeItem> items, {
    int limit = 24,
  }) async {
    // Prewarm only backend-generated thumbnails. Never download a full original
    // merely to prepare a grid, which would waste data and device storage.
    final candidates = items
        .where((item) => item.thumbnailUrl != null)
        .take(limit)
        .toList(growable: false);

    // A small concurrency cap prevents prewarming from competing with the
    // image the user is actively viewing on a slower connection.
    for (var index = 0; index < candidates.length; index += 4) {
      final batch = candidates.skip(index).take(4);
      await Future.wait(
        batch.map((item) async {
          try {
            await instance.getSingleFile(
              item.thumbnailUrl!,
              key: item.gridImageCacheKey,
            );
          } catch (_) {
            // Normal widgets will retry when the item is actually visible.
          }
        }),
      );
    }
  }
}
