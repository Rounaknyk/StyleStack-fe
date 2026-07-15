import 'package:flutter/foundation.dart';

import '../models/onboarding_profile.dart';
import '../services/onboarding_service.dart';

class OnboardingProvider extends ChangeNotifier {
  OnboardingProvider(this._repository);

  final OnboardingRepository _repository;
  OnboardingProfile? _profile;
  String? _loadedUserId;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  OnboardingProfile? get profile => _profile;
  bool get loading => _loading;
  bool get saving => _saving;
  String? get error => _error;
  bool get loaded => _loadedUserId != null && !_loading;
  bool get completed => _profile?.completed ?? false;

  Future<void> loadForUser(String userId, {bool force = false}) async {
    if (_loading || (!force && _loadedUserId == userId)) return;
    if (_loadedUserId != userId) {
      _profile = null;
      _error = null;
    }
    _loadedUserId = userId;
    _loading = true;
    notifyListeners();
    try {
      _profile = await _repository.fetch();
      _error = null;
    } on OnboardingServiceException catch (error) {
      _error = error.message;
    } catch (_) {
      _error = 'Cannot reach StyleStack. Check your connection and retry.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> complete(OnboardingProfile profile) async {
    if (_saving) return false;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      _profile = await _repository.save(profile);
      _error = null;
      return _profile?.completed ?? false;
    } on OnboardingServiceException catch (error) {
      _error = error.message;
      return false;
    } catch (_) {
      _error = 'Could not finish setup. Please try again.';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  void reset() {
    _profile = null;
    _loadedUserId = null;
    _loading = false;
    _saving = false;
    _error = null;
    notifyListeners();
  }
}
