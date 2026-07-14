import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/wardrobe_item.dart';
import '../models/clothing_analysis.dart';
import '../services/api_service.dart';

class WardrobeProvider extends ChangeNotifier {
  WardrobeProvider(this._api);
  final ApiService _api;

  List<WardrobeItem> _items = const [];
  bool _loading = false;
  bool _uploading = false;
  bool _deleting = false;
  bool _analyzing = false;
  String? _error;
  bool _loaded = false;
  Timer? _tagRefreshTimer;

  List<WardrobeItem> get items => _items;
  bool get loading => _loading;
  bool get uploading => _uploading;
  bool get deleting => _deleting;
  bool get analyzing => _analyzing;
  String? get error => _error;
  bool get loaded => _loaded;

  Future<void> loadItems({bool force = false}) async {
    if (_loading || (_loaded && !force)) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await _api.fetchItems();
      _loaded = true;
      _scheduleTagRefresh();
    } on ApiException catch (error) {
      _error = error.message;
    } catch (_) {
      _error = 'Could not load your wardrobe.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<WardrobeItem?> upload({
    required File image,
    required String name,
    required String category,
    String? color,
    String? season,
    String? formality,
    String? description,
    List<String> tags = const [],
  }) async {
    _uploading = true;
    _error = null;
    notifyListeners();
    try {
      final item = await _api.uploadItem(
        image: image,
        name: name,
        category: category,
        color: color,
        season: season,
        formality: formality,
        description: description,
        tags: tags,
      );
      _items = [item, ..._items];
      _loaded = true;
      _scheduleTagRefresh();
      return item;
    } on ApiException catch (error) {
      _error = error.message;
      return null;
    } catch (_) {
      _error = 'Upload failed. Please try again.';
      return null;
    } finally {
      _uploading = false;
      notifyListeners();
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

  Future<WardrobeItem?> refreshItem(String itemId) async {
    try {
      final item = await _api.fetchItem(itemId);
      final index = _items.indexWhere((existing) => existing.id == itemId);
      if (index >= 0) {
        _items = [..._items]..[index] = item;
      } else {
        _items = [item, ..._items];
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
    try {
      for (final itemId in itemIds) {
        await _api.deleteItem(itemId);
      }
      _items = _items.where((item) => !itemIds.contains(item.id)).toList();
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

  void reset() {
    _tagRefreshTimer?.cancel();
    _items = const [];
    _loaded = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _tagRefreshTimer?.cancel();
    super.dispose();
  }
}
