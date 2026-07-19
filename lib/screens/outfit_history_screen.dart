import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/design_system.dart';
import '../config/custom_widgets.dart';
import '../models/outfit.dart';
import '../models/outfit_selfie.dart';
import '../providers/mvp_provider.dart';
import '../services/api_service.dart';
import 'calendar_view.dart';

class OutfitHistoryScreen extends StatelessWidget {
  const OutfitHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Outfit history')),
    body: const OutfitHistoryView(showHeading: false),
  );
}

class OutfitHistoryView extends StatefulWidget {
  const OutfitHistoryView({super.key, this.showHeading = true});
  final bool showHeading;

  @override
  State<OutfitHistoryView> createState() => _OutfitHistoryViewState();
}

class _OutfitHistoryViewState extends State<OutfitHistoryView> {
  final _api = ApiService();
  List<OutfitSelfieHistoryEntry> _entries = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final entries = await _api.fetchOutfitSelfieHistory();
      if (mounted) setState(() => _entries = entries);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load outfit history.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _date(DateTime value) {
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
    final local = value.toLocal();
    final today = DateTime.now();
    if (local.year == today.year &&
        local.month == today.month &&
        local.day == today.day) {
      return 'Today';
    }
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  String _time(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    return '$hour:${local.minute.toString().padLeft(2, '0')} ${local.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final tomorrow = context.watch<MvpProvider>().tomorrowOutfit;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
        children: [
          if (widget.showHeading) ...[
            Text('Your looks', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 5),
            Text(
              'A visual memory of what you actually wore.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: DesignSystem.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
          ],
          _CalendarCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Style calendar')),
                  body: const StyleCalendarView(),
                ),
              ),
            ),
          ),
          if (tomorrow != null) ...[
            const SizedBox(height: 14),
            _TomorrowCard(outfit: tomorrow),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                'Outfit timeline',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
              Text(
                '${_entries.length} looks',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const StyleStackLoadingIndicator(
              message: 'Loading your outfit history…',
              animationSize: 170,
              padding: EdgeInsets.symmetric(vertical: 12),
            )
          else if (_error != null)
            _ErrorCard(message: _error!, onRetry: _load)
          else if (_entries.isEmpty)
            const _EmptyHistory()
          else
            ..._entries.asMap().entries.map(
              (entry) => _TimelineEntry(
                entry: entry.value,
                date: _date(entry.value.capturedAt),
                time: _time(entry.value.capturedAt),
                last: entry.key == _entries.length - 1,
              ),
            ),
        ],
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: DesignSystem.primary,
    borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plan for what is next',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'See events and tomorrow’s outfit reminders',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    ),
  );
}

class _TomorrowCard extends StatelessWidget {
  const _TomorrowCard({required this.outfit});
  final Outfit outfit;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: DesignSystem.accent.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
    ),
    child: Row(
      children: [
        ...outfit.items
            .take(3)
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: item.imageUrl == null
                      ? null
                      : NetworkImage(item.imageUrl!),
                  child: item.imageUrl == null
                      ? const Icon(Icons.checkroom_outlined, size: 18)
                      : null,
                ),
              ),
            ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tomorrow’s preview',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                outfit.items.map((item) => item.name).join(' + '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.entry,
    required this.date,
    required this.time,
    required this.last,
  });
  final OutfitSelfieHistoryEntry entry;
  final String date;
  final String time;
  final bool last;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 24,
          child: Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: DesignSystem.secondary,
                  shape: BoxShape.circle,
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(width: 2, color: DesignSystem.border),
                ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
              border: Border.all(color: DesignSystem.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 92,
                    height: 116,
                    child: entry.imageUrl == null
                        ? const ColoredBox(
                            color: DesignSystem.surfaceAlt,
                            child: Icon(Icons.photo_camera_back_outlined),
                          )
                        : Image.network(
                            entry.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.broken_image_outlined),
                          ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        date,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Logged at $time',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      ...entry.items
                          .take(4)
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check,
                                    size: 15,
                                    color: DesignSystem.primary,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: OutlinedButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: Text(message),
    ),
  );
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 44, horizontal: 20),
    child: Column(
      children: [
        Icon(
          Icons.photo_camera_back_outlined,
          size: 54,
          color: DesignSystem.primaryLight,
        ),
        SizedBox(height: 14),
        Text(
          'Your first outfit selfie will start this timeline.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
