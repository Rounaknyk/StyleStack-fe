import 'package:flutter/foundation.dart';

import '../models/calendar_models.dart';
import '../models/outfit.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';

class MvpProvider extends ChangeNotifier {
  MvpProvider(this._api);
  final ApiService _api;
  Outfit? outfit;
  Outfit? tomorrowOutfit;
  Outfit? eventOutfit;
  StyleCalendarEvent? styledEvent;
  List<StyleCalendarEvent> todayEvents = const [];
  UserPreferences? preferences;
  bool loadingOutfit = false;
  bool loadingTomorrow = false;
  bool loadingTodayEvents = false;
  bool loadingEventOutfit = false;
  bool loadingPreferences = false;
  bool saving = false;
  bool testingNotification = false;
  bool preferencesAttempted = false;
  int wearHistoryRevision = 0;
  String? error;
  String? eventError;

  StyleCalendarEvent? get priorityEvent =>
      todayEvents.isEmpty ? null : todayEvents.first;

  Future<void> loadTodayEvents({bool force = false}) async {
    if (loadingTodayEvents) return;
    loadingTodayEvents = true;
    notifyListeners();
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));
      final events = await _api.fetchCalendarEvents(start: start, end: end);
      events.removeWhere((event) {
        if (event.allDay) return false;
        final effectiveEnd =
            event.endAt ?? event.startAt.add(const Duration(hours: 2));
        return effectiveEnd.isBefore(now);
      });
      events.sort((a, b) {
        if (a.allDay != b.allDay) return a.allDay ? 1 : -1;
        return a.startAt.compareTo(b.startAt);
      });
      final previousId = priorityEvent?.id;
      todayEvents = events;
      if (priorityEvent?.id != previousId) {
        eventOutfit = null;
        styledEvent = null;
      }
      eventError = null;
    } on ApiException catch (e) {
      eventError = e.message;
    } catch (_) {
      eventError = 'Could not check today\'s calendar.';
    } finally {
      loadingTodayEvents = false;
      notifyListeners();
    }
  }

  Future<bool> generateEventOutfit(
    String city,
    StyleCalendarEvent event, {
    bool force = false,
  }) async {
    if (loadingEventOutfit || city.trim().isEmpty) return false;
    if (!force && eventOutfit != null && styledEvent?.id == event.id) {
      return true;
    }
    loadingEventOutfit = true;
    eventError = null;
    notifyListeners();
    try {
      if (!force && event.outfitId != null) {
        final saved = await _api.fetchOutfit(event.outfitId!);
        final eventName = event.title.trim().toLowerCase();
        if (eventName.isNotEmpty &&
            saved.occasion.toLowerCase().contains(eventName)) {
          eventOutfit = saved;
        } else {
          eventOutfit = await _api.suggestOutfit(
            city: city,
            occasion: _eventOccasion(event),
            calendarEventId: event.id,
          );
        }
      } else {
        eventOutfit = await _api.suggestOutfit(
          city: city,
          occasion: _eventOccasion(event),
          calendarEventId: event.id,
        );
      }
      styledEvent = event;
      await AnalyticsService.instance.event(
        'outfit_generated',
        parameters: {'context': 'calendar_event', 'forced': force ? 1 : 0},
      );
      return true;
    } on ApiException catch (e) {
      eventError = e.message;
      return false;
    } catch (_) {
      eventError = 'Could not prepare a look for ${event.title}.';
      return false;
    } finally {
      loadingEventOutfit = false;
      notifyListeners();
    }
  }

  String _eventOccasion(StyleCalendarEvent event) {
    final parts = <String>[event.title.trim()];
    final occasion = event.occasion.trim();
    if (occasion.isNotEmpty &&
        occasion.toLowerCase() != 'event' &&
        occasion.toLowerCase() != event.title.trim().toLowerCase()) {
      parts.add(occasion);
    }
    final description = event.description?.trim() ?? '';
    if (description.isNotEmpty) parts.add(description);
    final value = parts.join(' - ');
    return value.length <= 80 ? value : value.substring(0, 80).trimRight();
  }

  Future<void> loadPreferences({bool force = false}) async {
    if (loadingPreferences || (preferencesAttempted && !force)) return;
    preferencesAttempted = true;
    loadingPreferences = true;
    notifyListeners();
    try {
      preferences = await _api.fetchPreferences();
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Cannot reach the StyleStack backend. Check the API address.';
    } finally {
      loadingPreferences = false;
      notifyListeners();
    }
  }

  Future<bool> savePreferences(Map<String, dynamic> fields) async {
    saving = true;
    notifyListeners();
    try {
      preferences = await _api.updatePreferences(fields);
      error = null;
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } catch (_) {
      error = 'Cannot reach the StyleStack backend. Check the API address.';
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<bool> generateOutfit(String city, String occasion) async {
    loadingOutfit = true;
    error = null;
    notifyListeners();
    try {
      outfit = await _api.suggestOutfit(city: city, occasion: occasion);
      await AnalyticsService.instance.event(
        'outfit_generated',
        parameters: {
          'context': occasion.contains('alternative') ? 'refresh' : 'daily',
        },
      );
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } catch (_) {
      error = 'Cannot reach the StyleStack backend. Check the API address.';
      return false;
    } finally {
      loadingOutfit = false;
      notifyListeners();
    }
  }

  Future<bool> generateTomorrowOutfit(String city) async {
    if (loadingTomorrow || city.trim().isEmpty) return false;
    loadingTomorrow = true;
    notifyListeners();
    try {
      tomorrowOutfit = await _api.suggestOutfit(
        city: city,
        occasion: 'tomorrow alternative',
      );
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } catch (_) {
      error = 'Could not prepare tomorrow\'s preview.';
      return false;
    } finally {
      loadingTomorrow = false;
      notifyListeners();
    }
  }

  Future<bool> markWorn() async {
    if (outfit == null) return false;
    return markOutfitWorn(outfit!);
  }

  Future<bool> markOutfitWorn(Outfit target) async {
    try {
      await _api.wearOutfit(target.id);
      await AnalyticsService.instance.event(
        'outfit_logged',
        parameters: {'item_count': target.items.length},
      );
      wearHistoryRevision++;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      error = 'Cannot reach the StyleStack backend. Check the API address.';
      notifyListeners();
      return false;
    }
  }

  Future<void> registerDevice(String token, String platform) =>
      _api.registerDevice(token, platform);

  Future<bool> sendTestNotification(String token, String platform) async {
    testingNotification = true;
    error = null;
    notifyListeners();
    try {
      await _api.registerDevice(token, platform);
      final result = await _api.sendTestNotification();
      if ((result['success_count'] ?? 0) < 1) {
        error = 'Firebase did not deliver the notification to this device.';
        return false;
      }
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } catch (_) {
      error = 'Cannot reach the StyleStack backend. Check the API address.';
      return false;
    } finally {
      testingNotification = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> runNotificationSimulation(String simulation) {
    return _api.runNotificationSimulation(simulation);
  }

  void reset() {
    outfit = null;
    tomorrowOutfit = null;
    eventOutfit = null;
    styledEvent = null;
    todayEvents = const [];
    preferences = null;
    preferencesAttempted = false;
    error = null;
    notifyListeners();
  }
}
