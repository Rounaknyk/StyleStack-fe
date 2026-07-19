import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/wardrobe_item.dart';
import '../models/clothing_analysis.dart';
import '../services/api_service.dart';
import '../services/wardrobe_cache.dart';

class WardrobeProvider extends ChangeNotifier {
  WardrobeProvider(this._api, {WardrobeCacheStore? cache, String? ownerUid})
    : _cache = cache ?? SqliteWardrobeCache(),
      _ownerUidOverride = ownerUid;
  final ApiService _api;
  final WardrobeCacheStore _cache;
  final String? _ownerUidOverride;
  String? _lastOwnerUid;

  List<WardrobeItem> _items = const [];
  bool _loading = false;
  bool _syncing = false;
  bool _uploading = false;
  bool _deleting = false;
  bool _analyzing = false;
  String? _error;
  bool _loaded = false;
  int _uploadsInFlight = 0;
  Timer? _tagRefreshTimer;

  List<WardrobeItem> get items => _items;
  bool get loading => _loading;
  bool get syncing => _syncing;
  bool get uploading => _uploading;
  bool get deleting => _deleting;
  bool get analyzing => _analyzing;
  String? get error => _error;
  bool get loaded => _loaded;
  String? get _ownerUid {
    if (_ownerUidOverride != null) return _ownerUidOverride;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) _lastOwnerUid = uid;
      return uid ?? _lastOwnerUid;
    } catch (_) {
      // Widget/unit tests may construct the provider without Firebase.
      return _lastOwnerUid;
    }
  }

  Future<void> loadItems({bool force = false}) async {
    if (_syncing || (_loaded && !force)) return;
    _syncing = true;
    _error = null;
    final ownerUid = _ownerUid;

    if (!_loaded && ownerUid != null) {
      _loading = true;
      notifyListeners();
      try {
        final cachedRows = await _cache.read(ownerUid);
        final interrupted = cachedRows
            .where((item) => item.isUploading)
            .map((item) => item.id)
            .toList();
        if (interrupted.isNotEmpty) {
          await _cache.delete(ownerUid, interrupted);
        }
        final cached = cachedRows.where((item) => !item.isUploading).toList();
        if (cached.isNotEmpty) {
          _items = cached;
          _loaded = true;
          _loading = false;
          notifyListeners();
        }
      } catch (_) {
        // A cache failure must never prevent the network wardrobe from loading.
      }
    }

    _loading = _items.isEmpty;
    if (_loading) notifyListeners();
    try {
      final serverItems = await _api.fetchItems();
      final pending = _items.where((item) => item.isUploading).toList();
      _items = [
        ...pending,
        ...serverItems.where(
          (server) => pending.every((local) => local.id != server.id),
        ),
      ];
      _loaded = true;
      if (ownerUid != null) {
        try {
          await _cache.replace(ownerUid, _items);
        } catch (_) {
          // The fresh API result remains usable if local persistence fails.
        }
      }
      _scheduleTagRefresh();
    } on ApiException catch (error) {
      _error = error.message;
    } catch (_) {
      _error = 'Could not load your wardrobe.';
    } finally {
      _loading = false;
      _syncing = false;
      notifyListeners();
    }
  }

  Future<WardrobeItem?> upload({
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
  }) async {
    final pending = await _addPendingItem(
      image: image,
      name: name,
      category: category,
      brand: brand,
      color: color,
      season: season,
      formality: formality,
      description: description,
      tags: tags,
      aiAnalysis: aiAnalysis,
    );
    return _completeUpload(
      pending: pending,
      image: image,
      name: name,
      category: category,
      brand: brand,
      color: color,
      season: season,
      formality: formality,
      description: description,
      tags: tags,
      aiAnalysis: aiAnalysis,
    );
  }

  Future<WardrobeItem> uploadOptimistically({
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
  }) async {
    final pending = await _addPendingItem(
      image: image,
      name: name,
      category: category,
      brand: brand,
      color: color,
      season: season,
      formality: formality,
      description: description,
      tags: tags,
      aiAnalysis: aiAnalysis,
    );
    unawaited(
      _completeUpload(
        pending: pending,
        image: image,
        name: name,
        category: category,
        brand: brand,
        color: color,
        season: season,
        formality: formality,
        description: description,
        tags: tags,
        aiAnalysis: aiAnalysis,
      ),
    );
    return pending;
  }

  Future<WardrobeItem> _addPendingItem({
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
  }) async {
    final now = DateTime.now();
    final pending = WardrobeItem(
      id: 'local-${now.microsecondsSinceEpoch}',
      name: name,
      category: category,
      brand: brand?.trim().isEmpty == true ? null : brand,
      color: color?.trim().isEmpty == true ? null : color,
      description: description?.trim().isEmpty == true ? null : description,
      formality: formality?.trim().isEmpty == true ? null : formality,
      seasons: season?.trim().isEmpty == true || season == null
          ? const []
          : [season],
      tags: tags,
      aiCategory: aiAnalysis?.category,
      aiColor: aiAnalysis?.color,
      aiSeason: aiAnalysis?.season,
      aiFormality: aiAnalysis?.formality,
      aiDescription: aiAnalysis?.description,
      aiTagStatus: aiAnalysis == null ? 'pending' : 'completed',
      localImagePath: image.path,
      isUploading: true,
      createdAt: now,
    );
    _uploadsInFlight++;
    _uploading = true;
    _error = null;
    _items = [pending, ..._items];
    _loaded = true;
    final ownerUid = _ownerUid;
    if (ownerUid != null) {
      try {
        await _cache.upsert(ownerUid, pending);
      } catch (_) {
        // Keep the in-memory optimistic update even if local persistence fails.
      }
    }
    notifyListeners();
    return pending;
  }

  Future<WardrobeItem?> _completeUpload({
    required WardrobeItem pending,
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
  }) async {
    final ownerUid = _ownerUid;
    try {
      final item = await _api.uploadItem(
        image: image,
        name: name,
        category: category,
        brand: brand,
        color: color,
        season: season,
        formality: formality,
        description: description,
        tags: tags,
        aiAnalysis: aiAnalysis,
      );
      final index = _items.indexWhere((existing) => existing.id == pending.id);
      if (index >= 0) {
        _items = [..._items]..[index] = item;
      } else {
        _items = [item, ..._items];
      }
      if (ownerUid != null) {
        try {
          await _cache.delete(ownerUid, [pending.id]);
          await _cache.upsert(ownerUid, item);
        } catch (_) {
          // A successful server upload must not be rolled back for cache I/O.
        }
      }
      _loaded = true;
      _scheduleTagRefresh();
      return item;
    } on ApiException catch (error) {
      _error = error.message;
      await _rollbackPending(ownerUid, pending.id);
      return null;
    } catch (_) {
      _error = 'Upload failed. Please try again.';
      await _rollbackPending(ownerUid, pending.id);
      return null;
    } finally {
      _uploadsInFlight--;
      if (_uploadsInFlight < 0) _uploadsInFlight = 0;
      _uploading = _uploadsInFlight > 0;
      notifyListeners();
    }
  }

  Future<void> _rollbackPending(String? ownerUid, String pendingId) async {
    _items = _items.where((item) => item.id != pendingId).toList();
    if (ownerUid != null) {
      try {
        await _cache.delete(ownerUid, [pendingId]);
      } catch (_) {
        // The API result remains authoritative even if cache cleanup fails.
      }
    }
  }

  Future<ClothingAnalysis?> analyzeImage(File image) async {
    if (_analyzing) return null;
    _analyzing = true;
    _error = null;
    notifyListeners();
    try {
      return await _api.analyzeImage(image);
    } on ApiException catch (error) {
      _error = error.message;
      return null;
    } catch (_) {
      _error = 'AI could not analyze this image. Enter the details manually.';
      return null;
    } finally {
      _analyzing = false;
      notifyListeners();
    }
  }

  Future<List<ClothingAnalysis>> detectItems(File image) async {
    try {
      return await _api.detectItems(image);
    } on ApiException catch (error) {
      _error = error.message;
      return const [];
    } catch (_) {
      _error = 'AI could not detect items. You can still add one manually.';
      return const [];
    }
  }

  void beginAnalysis() {
    _analyzing = true;
    _error = null;
    notifyListeners();
  }

  void endAnalysis() {
    _analyzing = false;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<WardrobeItem?> refreshItem(String itemId) async {
    try {
      final item = await _api.fetchItem(itemId);
      final index = _items.indexWhere((existing) => existing.id == itemId);
      if (index >= 0) {
        _items = [..._items]..[index] = item;
      } else {
        _items = [item, ..._items];
      }
      final ownerUid = _ownerUid;
      if (ownerUid != null) {
        try {
          await _cache.upsert(ownerUid, item);
        } catch (_) {
          // Keep the fresh server item in memory.
        }
      }
      notifyListeners();
      return item;
    } on ApiException catch (error) {
      _error = error.message;
      notifyListeners();
      return null;
    }
  }

  Future<WardrobeItem?> updateItem(
    String itemId,
    Map<String, dynamic> fields,
  ) async {
    try {
      final item = await _api.updateItem(itemId, fields);
      final index = _items.indexWhere((existing) => existing.id == itemId);
      if (index >= 0) _items = [..._items]..[index] = item;
      final ownerUid = _ownerUid;
      if (ownerUid != null) {
        try {
          await _cache.upsert(ownerUid, item);
        } catch (_) {
          // Keep the fresh server item in memory.
        }
      }
      notifyListeners();
      return item;
    } on ApiException catch (error) {
      _error = error.message;
      notifyListeners();
      return null;
    }
  }

  void _scheduleTagRefresh() {
    _tagRefreshTimer?.cancel();
    if (!_items.any(
      (item) =>
          item.aiTagStatus == 'pending' || item.aiTagStatus == 'processing',
    )) {
      return;
    }
    _tagRefreshTimer = Timer(
      const Duration(seconds: 3),
      () => loadItems(force: true),
    );
  }

  Future<bool> deleteItems(Set<String> itemIds) async {
    if (itemIds.isEmpty || _deleting) return false;
    _deleting = true;
    _error = null;
    notifyListeners();
    final deletedItems = _items
        .where((item) => itemIds.contains(item.id))
        .toList();
    try {
      for (final itemId in itemIds) {
        await _api.deleteItem(itemId);
      }
      _items = _items.where((item) => !itemIds.contains(item.id)).toList();
      final ownerUid = _ownerUid;
      if (ownerUid != null) {
        try {
          await _cache.delete(ownerUid, itemIds);
        } catch (_) {
          // The server deletion is authoritative; a later sync repairs cache.
        }
      }
      await _evictImages(deletedItems);
      return true;
    } on ApiException catch (error) {
      _error = error.message;
      await loadItems(force: true);
      return false;
    } catch (_) {
      _error = 'Could not delete the selected items.';
      await loadItems(force: true);
      return false;
    } finally {
      _deleting = false;
      notifyListeners();
    }
  }

  Future<void> reset({bool clearCache = false}) async {
    _tagRefreshTimer?.cancel();
    final ownerUid = _ownerUid;
    final previousItems = _items;
    _items = const [];
    _loaded = false;
    _error = null;
    notifyListeners();
    if (clearCache && ownerUid != null) {
      try {
        await _cache.clear(ownerUid);
      } catch (_) {
        // Account/session teardown must continue even if cache cleanup fails.
      }
      await _evictImages(previousItems);
    }
  }

  Future<void> _evictImages(Iterable<WardrobeItem> items) async {
    for (final item in items) {
      final imageUrl = item.gridImageUrl;
      if (imageUrl == null) continue;
      try {
        await CachedNetworkImage.evictFromCache(
          imageUrl,
          cacheKey: 'wardrobe-${item.id}',
        );
      } catch (_) {
        // Image-cache cleanup is best-effort.
      }
    }
  }

  @override
  void dispose() {
    _tagRefreshTimer?.cancel();
    super.dispose();
  }
}
