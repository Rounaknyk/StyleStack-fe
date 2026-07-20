import 'dart:io';

import 'package:flutter/material.dart';

import '../config/design_system.dart';
import '../config/app_config.dart';
import '../services/api_service.dart';
import '../services/permission_prompt_service.dart';
import 'notification_inbox_screen.dart';

class TestLabView extends StatefulWidget {
  const TestLabView({super.key});

  @override
  State<TestLabView> createState() => _TestLabViewState();
}

class _TestLabViewState extends State<TestLabView> {
  final _api = ApiService();
  String? _running;
  String? _lastResult;
  bool? _lastSuccess;

  Future<void> _checkBackend() async {
    setState(() => _running = 'health');
    try {
      await _api.checkBackendHealth();
      _showResult(
        true,
        'Backend reached successfully at ${AppConfig.apiBaseUrl}.',
      );
    } catch (e) {
      _showResult(
        false,
        'Cannot reach ${AppConfig.apiBaseUrl}\n${e.runtimeType}: $e',
      );
    } finally {
      if (mounted) setState(() => _running = null);
    }
  }

  Future<bool> _prepareDevice() async {
    try {
      final token = await PermissionPromptService.requestNotificationToken(
        context,
      );
      if (token == null) {
        _showResult(
          false,
          'Push permission is unavailable. The production flow will still run and save its in-app notification.',
        );
        return false;
      }
      await _api.registerDevice(token, Platform.isIOS ? 'ios' : 'android');
      return true;
    } catch (e) {
      _showResult(
        false,
        'Push setup warning: $e\nThe production flow will still run and save its in-app notification.',
      );
      return false;
    }
  }

  Future<void> _simulate(String simulation) async {
    setState(() => _running = simulation);
    try {
      await _prepareDevice();
      final result = await _api.runNotificationSimulation(simulation);
      _showResult(true, result['detail'] as String? ?? 'Simulation completed.');
    } on ApiException catch (e) {
      _showResult(false, e.message);
    } catch (e) {
      _showResult(
        false,
        'Request failed at ${AppConfig.apiBaseUrl}\n${e.runtimeType}: $e',
      );
    } finally {
      if (mounted) setState(() => _running = null);
    }
  }

  Future<void> _testTransport() async {
    setState(() => _running = 'transport');
    try {
      final ready = await _prepareDevice();
      if (!ready) return;
      final result = await _api.sendTestNotification();
      final success = result['success_count'] ?? 0;
      _showResult(
        success > 0,
        success > 0
            ? 'Firebase accepted the test push for this device.'
            : 'Firebase did not deliver the test push.',
      );
    } on ApiException catch (e) {
      _showResult(false, e.message);
    } catch (_) {
      _showResult(false, 'Push transport test failed.');
    } finally {
      if (mounted) setState(() => _running = null);
    }
  }

  void _showResult(bool success, String message) {
    if (!mounted) return;
    setState(() {
      _lastSuccess = success;
      _lastResult = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [DesignSystem.primaryDark, DesignSystem.primary],
            ),
            borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.science_outlined, color: Colors.white, size: 32),
              SizedBox(height: 10),
              Text(
                'StyleStack Test Lab',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Run production notification flows now without waiting for the clock.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        if (_lastResult != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color:
                  (_lastSuccess == true
                          ? DesignSystem.success
                          : DesignSystem.error)
                      .withValues(alpha: .09),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _lastSuccess == true
                      ? Icons.check_circle
                      : Icons.error_outline,
                  color: _lastSuccess == true
                      ? DesignSystem.success
                      : DesignSystem.error,
                ),
                const SizedBox(width: 9),
                Expanded(child: Text(_lastResult!)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        _SimulationCard(
          icon: Icons.lan_outlined,
          title: 'Backend connection',
          description: 'Currently using ${AppConfig.apiBaseUrl}',
          buttonLabel: 'Check backend connection',
          loading: _running == 'health',
          enabled: _running == null,
          onRun: _checkBackend,
        ),
        _SimulationCard(
          icon: Icons.wb_sunny_outlined,
          title: 'Simulate the 8 AM outfit',
          description:
              'Runs the real daily outfit generator, saves the in-app alert, and sends the real push.',
          buttonLabel: 'Run 8 AM flow now',
          loading: _running == 'daily-outfit',
          enabled: _running == null,
          onRun: () => _simulate('daily-outfit'),
        ),
        _SimulationCard(
          icon: Icons.event_available_outlined,
          title: "Simulate tomorrow's events",
          description:
              'Finds tomorrow’s real calendar events, generates outfits, and sends their reminders.',
          buttonLabel: 'Run event reminders now',
          loading: _running == 'tomorrow-events',
          enabled: _running == null,
          onRun: () => _simulate('tomorrow-events'),
        ),
        _SimulationCard(
          icon: Icons.cell_tower_outlined,
          title: 'Test Firebase delivery only',
          description:
              'Checks device permission, token registration, Firebase, APNs or Android delivery.',
          buttonLabel: 'Send basic push',
          loading: _running == 'transport',
          enabled: _running == null,
          onRun: _testTransport,
        ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => const NotificationInboxScreen()),
          ),
          icon: const Icon(Icons.notifications_outlined),
          label: const Text('Open in-app notification inbox'),
        ),
        const SizedBox(height: 12),
        Text(
          'Tip: create an event dated tomorrow before running the event simulation.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SimulationCard extends StatelessWidget {
  const _SimulationCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.loading,
    required this.enabled,
    required this.onRun,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final bool loading;
  final bool enabled;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: DesignSystem.primary.withValues(alpha: .1),
                child: Icon(icon, color: DesignSystem.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(description),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: enabled ? onRun : null,
              icon: loading
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(loading ? 'Running production flow…' : buttonLabel),
            ),
          ),
        ],
      ),
    ),
  );
}
