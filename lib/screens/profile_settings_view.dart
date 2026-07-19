import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/design_system.dart';
import '../providers/auth_provider.dart';
import '../providers/gmail_sync_provider.dart';
import '../providers/mvp_provider.dart';
import '../providers/wardrobe_provider.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/api_service.dart';
import 'outfit_history_screen.dart';

Future<bool> showDeleteAccountConfirmation(BuildContext context) async {
  var canDelete = false;
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Delete your account?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This permanently deletes your wardrobe photos, outfits, '
                  'style history, calendar data, preferences, notifications, '
                  'and StyleStack sign-in account. This cannot be undone.',
                ),
                const SizedBox(height: 16),
                TextField(
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Type DELETE to confirm',
                  ),
                  onChanged: (value) => setDialogState(
                    () => canDelete = value.trim().toUpperCase() == 'DELETE',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep account'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: DesignSystem.error,
                ),
                onPressed: canDelete
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
                child: const Text('Delete permanently'),
              ),
            ],
          ),
        ),
      ) ??
      false;
}

class ProfileSettingsView extends StatefulWidget {
  const ProfileSettingsView({super.key});
  @override
  State<ProfileSettingsView> createState() => _ProfileSettingsViewState();
}

class _ProfileSettingsViewState extends State<ProfileSettingsView> {
  final _city = TextEditingController();
  final _timezone = TextEditingController(text: 'Asia/Kolkata');
  final _localhostUrl = TextEditingController();
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  bool _notifications = false;
  bool _seeded = false;
  bool _detectingLocation = false;
  bool _locationRequested = false;
  bool _runningNotificationSimulation = false;
  bool _schedulingNotificationSimulation = false;
  bool _deletingAccount = false;

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
    _localhostUrl.dispose();
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
      // Persist immediately so Today reflects the detected city without
      // requiring a second tap on Save (especially after account switching).
      final saved = await context.read<MvpProvider>().savePreferences({
        'city': location.city,
        'timezone': location.timezone,
      });
      _message(
        saved
            ? 'Location set to ${location.city}.'
            : 'Location detected, but could not save it yet.',
      );
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
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connect the Gmail account used for your shopping receipts.',
              style: TextStyle(fontWeight: FontWeight.w700, height: 1.35),
            ),
            SizedBox(height: 12),
            Text(
              'StyleStack checks all eligible confirmed Amazon deliveries in one background sync and skips purchases already imported.',
              style: TextStyle(height: 1.4),
            ),
            SizedBox(height: 10),
            Text(
              'The Gmail token is never saved and is cleared after the job. Myntra and Flipkart extraction are planned, but not enabled yet.',
              style: TextStyle(height: 1.4),
            ),
          ],
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
    final wardrobe = context.read<WardrobeProvider>();
    unawaited(
      context.read<GmailSyncProvider>().start(
        refreshWardrobe: () => wardrobe.loadItems(force: true),
      ),
    );
    _message('Closet Sync started. You can keep using StyleStack.');
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

  Future<String?> _registerPushDevice() async {
    final provider = context.read<MvpProvider>();
    final token = await NotificationService.requestToken();
    if (token == null) return null;
    await provider.registerDevice(token, Platform.operatingSystem);
    return token;
  }

  Future<void> _runMorningSimulation() async {
    final provider = context.read<MvpProvider>();
    if (mounted) setState(() => _runningNotificationSimulation = true);
    try {
      final token = await _registerPushDevice();
      if (token == null) {
        _message('Allow notifications on this physical device first.');
        return;
      }
      final result = await provider.runNotificationSimulation('daily-outfit');
      if (mounted) {
        _message(result['detail']?.toString() ?? 'Morning flow ran.');
      }
    } catch (error) {
      _message('Morning flow failed: ${error.toString()}');
    } finally {
      if (mounted) setState(() => _runningNotificationSimulation = false);
    }
  }

  Future<void> _scheduleDelayedSimulation() async {
    final provider = context.read<MvpProvider>();
    if (mounted) setState(() => _schedulingNotificationSimulation = true);
    try {
      final token = await _registerPushDevice();
      if (token == null) {
        _message('Allow notifications on this physical device first.');
        return;
      }
      final result = await provider.runNotificationSimulation(
        'daily-outfit-delay',
      );
      if (mounted) {
        _message(
          '${result['detail'] ?? 'Notification scheduled.'} You can close the app now.',
        );
      }
    } catch (error) {
      _message('Delayed notification failed: ${error.toString()}');
    } finally {
      if (mounted) setState(() => _schedulingNotificationSimulation = false);
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
    if (mounted) {
      _message(
        ok
            ? 'Wardrobe cleared.'
            : wardrobe.error ?? 'Could not clear wardrobe.',
      );
    }
  }

  Future<void> _deleteAccount() async {
    if (_deletingAccount) return;
    final confirmed = await showDeleteAccountConfirmation(context);
    if (!confirmed || !mounted) return;

    final gmailSync = context.read<GmailSyncProvider>();
    final wardrobe = context.read<WardrobeProvider>();
    final mvp = context.read<MvpProvider>();
    final auth = context.read<AuthProvider>();
    setState(() => _deletingAccount = true);
    try {
      await ApiService().deleteAccount();
      if (!mounted) return;
      gmailSync.reset();
      await wardrobe.reset(clearCache: true);
      mvp.reset();
      await auth.signOut();
    } on ApiException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('Could not delete your account. Please try again.');
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
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
    final gmailSync = context.watch<GmailSyncProvider>();
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
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Notification test lab',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'These buttons use the same backend delivery logic as the real 8 AM flow.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _runningNotificationSimulation
                          ? null
                          : _runMorningSimulation,
                      icon: _runningNotificationSimulation
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_circle_outline),
                      label: const Text('Run 8 AM flow now'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _schedulingNotificationSimulation
                          ? null
                          : _scheduleDelayedSimulation,
                      icon: _schedulingNotificationSimulation
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.timer_outlined),
                      label: const Text(
                        'Send 10 seconds after I close the app',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsSection(
            title: 'Closet Sync',
            subtitle: gmailSync.isRunning
                ? 'Sync continues while you use the rest of StyleStack.'
                : 'Bring eligible purchases into your wardrobe.',
            children: [
              _SettingsTile(
                icon: Icons.mail_outline,
                title: switch (gmailSync.phase) {
                  GmailSyncPhase.connecting => 'Connecting Gmail…',
                  GmailSyncPhase.syncing => 'Scanning delivered purchases…',
                  GmailSyncPhase.refreshing => 'Refreshing your wardrobe…',
                  GmailSyncPhase.completed => 'Closet Sync complete',
                  GmailSyncPhase.failed => 'Closet Sync needs attention',
                  GmailSyncPhase.idle => 'Auto-add from Gmail',
                },
                subtitle: switch (gmailSync.phase) {
                  GmailSyncPhase.completed =>
                    '${gmailSync.result?['imported_items'] ?? 0} items added or refreshed from ${gmailSync.result?['scanned_messages'] ?? 0} delivered emails. Tap to sync again.',
                  GmailSyncPhase.failed =>
                    gmailSync.error ??
                        'Could not complete Gmail sync. Tap to retry.',
                  GmailSyncPhase.connecting =>
                    'Choose your Google account to begin securely',
                  GmailSyncPhase.syncing =>
                    'Checking all eligible confirmed deliveries in the background',
                  GmailSyncPhase.refreshing =>
                    'Applying the latest items and AI details',
                  GmailSyncPhase.idle =>
                    'Connect the Gmail used for Amazon. One sync checks all eligible delivered purchases.',
                },
                trailing: gmailSync.isRunning
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: gmailSync.isRunning ? null : _importFromGmail,
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
                icon: Icons.person_remove_outlined,
                title: _deletingAccount
                    ? 'Deleting account…'
                    : 'Delete account',
                subtitle: 'Permanently erase all StyleStack data',
                trailing: _deletingAccount
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _deletingAccount ? null : _deleteAccount,
                destructive: true,
              ),
              const Divider(height: 1),
              _SettingsTile(
                icon: Icons.logout,
                title: 'Sign out',
                onTap: () async {
                  context.read<GmailSyncProvider>().reset();
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
      Material(
        color: DesignSystem.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
          side: const BorderSide(color: DesignSystem.border),
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    minVerticalPadding: 10,
    leading: Icon(
      icon,
      color: destructive ? DesignSystem.error : DesignSystem.primary,
    ),
    title: Text(
      title,
      style: destructive ? const TextStyle(color: DesignSystem.error) : null,
    ),
    subtitle: subtitle == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(subtitle!, style: const TextStyle(height: 1.35)),
          ),
    trailing:
        trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right)),
    onTap: onTap,
  );
}
