import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/design_system.dart';
import '../config/custom_widgets.dart';
import '../models/outfit.dart';
import '../models/wear_history_entry.dart';
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
  List<WearHistoryEntry> _entries = const [];
  bool _loading = true;
  String? _error;
  int? _observedHistoryRevision;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = context.watch<MvpProvider>().wearHistoryRevision;
    final previous = _observedHistoryRevision;
    _observedHistoryRevision = revision;
    if (previous != null && previous != revision) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final entries = await _api.fetchWearHistory();
      if (mounted && generation == _loadGeneration) {
        setState(() => _entries = entries);
      }
    } on ApiException catch (error) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _error = 'Could not load outfit history.');
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
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
            const StyleStackPageIntro(
              eyebrow: 'Your style diary',
              title: 'Plan & remember',
              subtitle:
                  'Prepare for upcoming events, then revisit what you actually wore.',
              padding: EdgeInsets.zero,
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
                date: _date(entry.value.wornAt),
                time: _time(entry.value.wornAt),
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
  Widget build(BuildContext context) => StyleStackFeaturePanel(
    color: DesignSystem.primary,
    onTap: onTap,
    child: const Row(
      children: [
        StyleStackIconBadge(
          icon: Icons.calendar_month_outlined,
          backgroundColor: DesignSystem.primaryDark,
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Plan for what is next',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'See events and outfit reminders',
                style: TextStyle(color: Colors.white70, height: 1.35),
              ),
            ],
          ),
        ),
        Icon(Icons.arrow_forward_rounded, color: Colors.white),
      ],
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
  final WearHistoryEntry entry;
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        date,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(time, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 10),
                ...entry.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: item.gridImageUrl == null
                                ? const ColoredBox(
                                    color: DesignSystem.surfaceAlt,
                                    child: Icon(Icons.checkroom_outlined),
                                  )
                                : Image.network(
                                    item.gridImageUrl!,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => const ColoredBox(
                                      color: DesignSystem.surfaceAlt,
                                      child: Icon(Icons.checkroom_outlined),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                item.displayCategory,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 19,
                          color: DesignSystem.success,
                        ),
                      ],
                    ),
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
          Icons.checkroom_outlined,
          size: 54,
          color: DesignSystem.primaryLight,
        ),
        SizedBox(height: 14),
        Text(
          'Log an outfit from Today to start your wear timeline.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
