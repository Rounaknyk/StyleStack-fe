import 'package:flutter/material.dart';

import '../config/design_system.dart';
import '../config/custom_widgets.dart';
import '../models/calendar_models.dart';
import '../services/api_service.dart';
import 'reminder_outfit_screen.dart';

class NotificationInboxScreen extends StatefulWidget {
  const NotificationInboxScreen({super.key});

  @override
  State<NotificationInboxScreen> createState() =>
      _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends State<NotificationInboxScreen> {
  final _api = ApiService();
  List<StyleNotification> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _api.fetchNotifications();
      if (mounted) setState(() => _items = items);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const StyleStackLoadingIndicator(
              message: 'Checking your style reminders…',
            )
          : _items.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 180),
                Icon(
                  Icons.notifications_none,
                  size: 58,
                  color: DesignSystem.primary,
                ),
                SizedBox(height: 12),
                Text(
                  'Your outfit reminders will appear here.',
                  textAlign: TextAlign.center,
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final item = _items[index];
                return Card(
                  color: item.isRead
                      ? null
                      : DesignSystem.primary.withValues(alpha: .07),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        item.type == 'event_outfit'
                            ? Icons.event
                            : Icons.checkroom,
                      ),
                    ),
                    title: Text(item.title),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(item.body),
                    ),
                    trailing: item.isRead
                        ? null
                        : const Icon(
                            Icons.circle,
                            size: 9,
                            color: DesignSystem.primary,
                          ),
                    onTap: () async {
                      if (!item.isRead) {
                        await _api.markNotificationRead(item.id);
                      }
                      final outfitId = item.data['outfit_id'] as String?;
                      if (outfitId != null && context.mounted) {
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReminderOutfitScreen(
                              outfitId: outfitId,
                              title: item.title,
                            ),
                          ),
                        );
                      }
                      await _load();
                    },
                  ),
                );
              },
            ),
    ),
  );
}
