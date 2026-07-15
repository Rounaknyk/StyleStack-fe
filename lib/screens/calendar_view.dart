import 'package:flutter/material.dart';

import '../config/design_system.dart';
import '../models/calendar_models.dart';
import '../services/api_service.dart';
import '../services/calendar_sync_service.dart';
import 'reminder_outfit_screen.dart';

class StyleCalendarView extends StatefulWidget {
  const StyleCalendarView({super.key});

  @override
  State<StyleCalendarView> createState() => _StyleCalendarViewState();
}

class _StyleCalendarViewState extends State<StyleCalendarView> {
  final _api = ApiService();
  late final CalendarSyncService _sync = CalendarSyncService(_api);
  DateTime _selected = DateTime.now();
  List<StyleCalendarEvent> _events = const [];
  bool _loading = true;
  bool _syncing = false;
  bool _googleConnected = false;
  String? _googleEmail;
  DateTime? _lastGoogleSync;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final events = await _api.fetchCalendarEvents(
        start: DateTime(now.year, now.month - 1),
        end: DateTime(now.year, now.month + 4),
      );
      final status = await _api.fetchGoogleCalendarStatus();
      if (mounted) {
        setState(() {
          _events = events;
          _googleConnected = status['connected'] as bool? ?? false;
          _googleEmail = status['email'] as String?;
          _lastGoogleSync = status['last_synced_at'] == null
              ? null
              : DateTime.parse(status['last_synced_at'] as String).toLocal();
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load your calendar.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connectGoogle() async {
    setState(() => _syncing = true);
    try {
      final result = await _sync.connectAndSync();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result['imported'] ?? 0} Google Calendar events imported.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : e.toString())),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _syncGoogleNow() async {
    setState(() => _syncing = true);
    try {
      final result = await _api.syncGoogleCalendar();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result['imported'] ?? 0} events synced.')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _disconnectGoogle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Google Calendar?'),
        content: const Text(
          'Automatic sync will stop and imported Google events will be removed. Your manually added dates will stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep connected'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _syncing = true);
    try {
      await _sync.disconnect();
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _addEvent() async {
    final title = TextEditingController();
    final details = TextEditingController();
    var date = _selected;
    var time = TimeOfDay.now();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add an important date'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Event name',
                    prefixIcon: Icon(Icons.celebration_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: details,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(_dateLabel(date)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                      initialDate: date.isBefore(DateTime.now())
                          ? DateTime.now()
                          : date,
                    );
                    if (picked != null) setDialogState(() => date = picked);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_outlined),
                  title: Text(time.format(context)),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: time,
                    );
                    if (picked != null) setDialogState(() => time = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Add date'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final start = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    try {
      await _api.createCalendarEvent({
        'title': title.text.trim(),
        'description': details.text.trim().isEmpty ? null : details.text.trim(),
        'start_at': start.toUtc().toIso8601String(),
        'end_at': start.add(const Duration(hours: 1)).toUtc().toIso8601String(),
        'occasion': 'event',
      });
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  List<StyleCalendarEvent> get _selectedEvents => _events.where((event) {
    final date = event.startAt;
    return date.year == _selected.year &&
        date.month == _selected.month &&
        date.day == _selected.day;
  }).toList();

  List<StyleCalendarEvent> get _upcomingEventDays {
    final now = DateTime.now().subtract(const Duration(days: 1));
    final seen = <String>{};
    return _events
        .where((event) {
          if (event.startAt.isBefore(now)) return false;
          final key =
              '${event.startAt.year}-${event.startAt.month}-${event.startAt.day}';
          return seen.add(key);
        })
        .take(12)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [DesignSystem.primary, DesignSystem.primaryLight],
              ),
              borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dress ahead, stress less',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Get your outfit one day before every event.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _GoogleCalendarConnectionCard(
            connected: _googleConnected,
            email: _googleEmail,
            lastSync: _lastGoogleSync,
            loading: _syncing,
            onConnect: _connectGoogle,
            onSync: _syncGoogleNow,
            onDisconnect: _disconnectGoogle,
          ),
          const SizedBox(height: 12),
          CalendarDatePicker(
            initialDate: _selected,
            firstDate: DateTime(DateTime.now().year - 1),
            lastDate: DateTime(DateTime.now().year + 3),
            onDateChanged: (value) => setState(() => _selected = value),
          ),
          if (_upcomingEventDays.isNotEmpty) ...[
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _upcomingEventDays.length,
                separatorBuilder: (_, _) => const SizedBox(width: 7),
                itemBuilder: (_, index) {
                  final event = _upcomingEventDays[index];
                  final selected =
                      event.startAt.year == _selected.year &&
                      event.startAt.month == _selected.month &&
                      event.startAt.day == _selected.day;
                  return ChoiceChip(
                    selected: selected,
                    avatar: Icon(
                      event.source == 'google'
                          ? Icons.g_mobiledata
                          : Icons.event_outlined,
                      size: 18,
                    ),
                    label: Text(
                      '${event.startAt.day} ${_month(event.startAt.month)}',
                    ),
                    onSelected: (_) =>
                        setState(() => _selected = event.startAt),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  _dateLabel(_selected),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _addEvent,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add date'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null && _events.isEmpty)
            _CalendarMessage(icon: Icons.cloud_off_outlined, text: _error!)
          else if (_selectedEvents.isEmpty)
            const _CalendarMessage(
              icon: Icons.event_available_outlined,
              text: 'Nothing planned. Add a date or sync Google Calendar.',
            )
          else
            ..._selectedEvents.map(
              (event) => _EventCard(
                event: event,
                onDelete: event.source == 'manual'
                    ? () async {
                        await _api.deleteCalendarEvent(event.id);
                        await _load();
                      }
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, this.onDelete});
  final StyleCalendarEvent event;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(event.startAt).format(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: DesignSystem.primary.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Column(
                children: [
                  Text(
                    '${event.startAt.day}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(time, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.outfitId == null
                        ? 'Outfit reminder scheduled for the day before'
                        : 'Your event outfit is ready',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: event.outfitId == null
                          ? null
                          : DesignSystem.primary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        event.source == 'google'
                            ? Icons.g_mobiledata
                            : Icons.edit_calendar_outlined,
                        size: 18,
                      ),
                      Text(
                        event.source == 'google'
                            ? 'Google Calendar'
                            : 'StyleStack',
                      ),
                    ],
                  ),
                  if (event.outfitId != null) ...[
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReminderOutfitScreen(
                            outfitId: event.outfitId!,
                            title: event.title,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.checkroom, size: 18),
                      label: const Text('See what to wear'),
                    ),
                  ],
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                tooltip: 'Delete date',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
      ),
    );
  }
}

class _GoogleCalendarConnectionCard extends StatelessWidget {
  const _GoogleCalendarConnectionCard({
    required this.connected,
    required this.email,
    required this.lastSync,
    required this.loading,
    required this.onConnect,
    required this.onSync,
    required this.onDisconnect,
  });

  final bool connected;
  final String? email;
  final DateTime? lastSync;
  final bool loading;
  final VoidCallback onConnect;
  final VoidCallback onSync;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4285F4).withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.calendar_month,
                    color: Color(0xFF4285F4),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        connected
                            ? 'Google Calendar connected'
                            : 'Import Google Calendar',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        connected
                            ? email ?? 'Automatic daily sync is active'
                            : 'Optional • you choose whether to connect',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (connected)
                  const Icon(Icons.check_circle, color: DesignSystem.success),
              ],
            ),
            const SizedBox(height: 11),
            Text(
              connected
                  ? 'Meetings and events are refreshed by StyleStack every day, even when the app is closed.'
                  : 'Allow read-only access to show your meetings here and prepare outfits one day before.',
            ),
            if (connected && lastSync != null) ...[
              const SizedBox(height: 6),
              Text(
                'Last synced: ${_dateLabel(lastSync!)} at ${TimeOfDay.fromDateTime(lastSync!).format(context)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            if (!connected)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: loading ? null : onConnect,
                  icon: loading
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: const Text('Connect Google Calendar'),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: loading ? null : onSync,
                      icon: loading
                          ? const SizedBox.square(
                              dimension: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: const Text('Sync now'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: loading ? null : onDisconnect,
                    child: const Text('Disconnect'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _CalendarMessage extends StatelessWidget {
  const _CalendarMessage({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Column(
      children: [
        Icon(icon, size: 48, color: DesignSystem.primary),
        const SizedBox(height: 10),
        Text(text, textAlign: TextAlign.center),
      ],
    ),
  );
}

String _dateLabel(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _month(int month) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][month - 1];
