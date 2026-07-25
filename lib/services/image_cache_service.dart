import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A small, bounded disk cache for remote wardrobe and inspiration images.
///
/// Remote photos are server-owned. The app retains only resized copies for a
/// short time, so browsing feels instant without silently consuming hundreds
/// of megabytes on a user's device.
class StyleStackImageCache {
  StyleStackImageCache._();

  static const _migrationKey = 'image_cache_policy_v1_applied';

  static final CacheManager instance = CacheManager(
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
}
