import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/design_system.dart';
import '../providers/auth_provider.dart';
import '../providers/mvp_provider.dart';
import '../providers/wardrobe_provider.dart';
import '../services/api_service.dart';
import '../services/gmail_import_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import 'outfit_history_screen.dart';

class ProfileSettingsView extends StatefulWidget {
  const ProfileSettingsView({super.key});
  @override
  State<ProfileSettingsView> createState() => _ProfileSettingsViewState();
}

class _ProfileSettingsViewState extends State<ProfileSettingsView> {
  final _city = TextEditingController();
  final _timezone = TextEditingController(text: 'Asia/Kolkata');
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  bool _notifications = false;
  bool _seeded = false;
  bool _detectingLocation = false;
  bool _locationRequested = false;
  bool _importingGmail = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<MvpProvider>().loadPreferences(),
    );
  }

  @override
  void dispose() {
    _city.dispose();
    _timezone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final provider = context.read<MvpProvider>();
    if (_notifications) {
      try {
        final token = await NotificationService.requestToken();
        if (token == null) {
          if (mounted) setState(() => _notifications = false);
          _message('Notification permission was not granted.');
        } else {
          await provider.registerDevice(token, Platform.operatingSystem);
        }
      } catch (_) {
        if (mounted) setState(() => _notifications = false);
        _message('Push notifications require a configured physical device.');
      }
    }
    final ok = await provider.savePreferences({
      'city': _city.text.trim(),
      'timezone': _timezone.text.trim(),
      'notification_enabled': _notifications,
      'notification_time':
          '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}:00',
    });
    if (!mounted) return;
    _message(
      ok
          ? 'Preferences saved.'
          : provider.error ?? 'Could not save preferences.',
    );
  }

  Future<void> _detectLocation() async {
    setState(() => _detectingLocation = true);
    try {
      final location = await LocationService.detectCity();
      if (!mounted) return;
      setState(() {
        _city.text = location.city;
        if (location.timezone.contains('/')) _timezone.text = location.timezone;
      });
      _message('Location set to ${location.city}.');
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _detectingLocation = false);
    }
  }

  Future<void> _importFromGmail() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect Gmail?'),
        content: const Text(
          'Closet Sync uses read-only access and scans order emails from supported fashion stores. Gmail tokens and email contents are not stored.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Connect Gmail'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _importingGmail = true);
    try {
      final result = await GmailImportService(ApiService()).connectAndImport();
      if (!mounted) return;
      await context.read<WardrobeProvider>().loadItems(force: true);
      if (!mounted) return;
      _message(
        '${result['imported_items']} items added from ${result['scanned_messages']} order emails.',
      );
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _importingGmail = false);
    }
  }

  Future<void> _sendTestNotification() async {
    final provider = context.read<MvpProvider>();
    try {
      final token = await NotificationService.requestToken();
      if (token == null) {
        _message('Allow notifications in device Settings first.');
        return;
      }
      final delivered = await provider.sendTestNotification(
        token,
        Platform.operatingSystem,
      );
      if (!mounted) return;
      _message(
        delivered
            ? 'Test notification sent.'
            : provider.error ?? 'Test notification failed.',
      );
    } catch (_) {
      _message('Could not get a notification token on this device.');
    }
  }

  Future<void> _clearWardrobe() async {
    final wardrobe = context.read<WardrobeProvider>();
    if (wardrobe.items.isEmpty) {
      _message('Your wardrobe is already empty.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear your wardrobe?'),
        content: Text(
          'This permanently deletes all ${wardrobe.items.length} wardrobe items. Your account remains active.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: DesignSystem.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete items'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await wardrobe.deleteItems(
      wardrobe.items.map((item) => item.id).toSet(),
    );
    if (mounted)
      _message(
        ok
            ? 'Wardrobe cleared.'
            : wardrobe.error ?? 'Could not clear wardrobe.',
      );
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MvpProvider>();
    final prefs = provider.preferences;
    if (!_seeded && prefs != null) {
      _city.text = prefs.city ?? '';
      _timezone.text = prefs.timezone;
      final parts = prefs.notificationTime.split(':');
      _time = TimeOfDay(
        hour: int.tryParse(parts.first) ?? 8,
        minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      );
      _notifications = prefs.notificationEnabled;
      _seeded = true;
      if (_city.text.isEmpty && !_locationRequested) {
        _locationRequested = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _detectLocation());
      }
    }
    final auth = context.watch<AuthProvider>();
    final email = auth.user?.email ?? 'StyleStack user';
    final displayName = auth.user?.displayName?.trim();
    final title = displayName == null || displayName.isEmpty
        ? email.split('@').first
        : displayName;

    return RefreshIndicator(
      onRefresh: () => provider.loadPreferences(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
        children: [
          _ProfileHeader(title: title, email: email),
          const SizedBox(height: 22),
          _SettingsSection(
            title: 'Preferences',
            subtitle: 'Tune comfort and reminders. Styling remains automatic.',
            children: [
              _SettingsTile(
                icon: Icons.location_on_outlined,
                title: 'Current city',
                subtitle: _city.text.isEmpty ? 'Not detected yet' : _city.text,
                trailing: _detectingLocation
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton(
                        onPressed: _detectLocation,
                        child: const Text('Detect'),
                      ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                secondary: const Icon(Icons.wb_sunny_outlined),
                value: _notifications,
                title: const Text('Morning outfit alert'),
                subtitle: Text('Daily at ${_time.format(context)}'),
                onChanged: (value) => setState(() => _notifications = value),
              ),
              const Divider(height: 1),
              _SettingsTile(
                icon: Icons.schedule_outlined,
                title: 'Reminder time',
                subtitle: _time.format(context),
                onTap: () async {
                  final selected = await showTimePicker(
                    context: context,
                    initialTime: _time,
                  );
                  if (selected != null) setState(() => _time = selected);
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: provider.saving ? null : _save,
                        child: Text(
                          provider.saving ? 'Saving…' : 'Save preferences',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: 'Send a test notification',
                      onPressed: provider.testingNotification
                          ? null
                          : _sendTestNotification,
                      icon: provider.testingNotification
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.notifications_active_outlined),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsSection(
            title: 'Closet Sync',
            subtitle: 'Bring eligible purchases into your wardrobe.',
            children: [
              _SettingsTile(
                icon: Icons.mail_outline,
                title: _importingGmail
                    ? 'Scanning order emails…'
                    : 'Auto-add from Gmail',
                subtitle: 'Amazon, Flipkart, Myntra and Ajio',
                trailing: _importingGmail
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: _importingGmail ? null : _importFromGmail,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsSection(
            title: 'Account',
            children: [
              _SettingsTile(
                icon: Icons.photo_camera_back_outlined,
                title: 'Outfit history',
                subtitle: 'Review your real looks',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OutfitHistoryScreen(),
                  ),
                ),
              ),
              const Divider(height: 1),
              _SettingsTile(
                icon: Icons.delete_sweep_outlined,
                title: 'Clear wardrobe',
                subtitle: 'Permanently delete wardrobe items',
                onTap: _clearWardrobe,
                destructive: true,
              ),
              const Divider(height: 1),
              _SettingsTile(
                icon: Icons.logout,
                title: 'Sign out',
                onTap: () async {
                  context.read<WardrobeProvider>().reset();
                  context.read<MvpProvider>().reset();
                  await context.read<AuthProvider>().signOut();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.title, required this.email});
  final String title;
  final String email;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        radius: 34,
        backgroundColor: DesignSystem.primary,
        child: Text(
          title.isEmpty ? 'S' : title[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(width: 15),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 2),
            Text(email, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ],
  );
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    this.subtitle,
    required this.children,
  });
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      if (subtitle != null) ...[
        const SizedBox(height: 3),
        Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
      ],
      const SizedBox(height: 10),
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
          border: Border.all(color: DesignSystem.border),
        ),
        child: Column(children: children),
      ),
    ],
  );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(
      icon,
      color: destructive ? DesignSystem.error : DesignSystem.primary,
    ),
    title: Text(
      title,
      style: destructive ? const TextStyle(color: DesignSystem.error) : null,
    ),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing:
        trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right)),
    onTap: onTap,
  );
}
