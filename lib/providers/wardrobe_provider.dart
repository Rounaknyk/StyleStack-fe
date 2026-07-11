import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/wardrobe_item.dart';
import '../services/api_service.dart';

class WardrobeProvider extends ChangeNotifier {
  WardrobeProvider(this._api);
  final ApiService _api;

  List<WardrobeItem> _items = const [];
  bool _loading = false;
  bool _uploading = false;
  String? _error;
  bool _loaded = false;

  List<WardrobeItem> get items => _items;
  bool get loading => _loading;
  bool get uploading => _uploading;
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
    } on ApiException catch (error) {
      _error = error.message;
    } catch (_) {
      _error = 'Could not load your wardrobe.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> upload(File image, String name, String category) async {
    _uploading = true;
    _error = null;
    notifyListeners();
    try {
      await _api.uploadItem(image: image, name: name, category: category);
      _loaded = false;
      await loadItems(force: true);
      return true;
    } on ApiException catch (error) {
      _error = error.message;
      return false;
    } catch (_) {
      _error = 'Upload failed. Please try again.';
      return false;
    } finally {
      _uploading = false;
      notifyListeners();
    }
  }

  void reset() {
    _items = const [];
    _loaded = false;
    _error = null;
    notifyListeners();
  }
}
