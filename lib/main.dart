import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/design_system.dart';
import 'config/brand_logo.dart';
import 'config/runtime_config.dart';
import 'providers/auth_provider.dart';
import 'providers/gmail_sync_provider.dart';
import 'providers/onboarding_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/wardrobe_provider.dart';
import 'providers/mvp_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/gmail_import_service.dart';
import 'services/onboarding_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // Initialize settings provider
  final settingsProvider = SettingsProvider();
  await settingsProvider.init();
  RuntimeConfig.setSettingsProvider(settingsProvider);

  runApp(StyleStackApp(settingsProvider: settingsProvider));
}

class StyleStackApp extends StatelessWidget {
  const StyleStackApp({required this.settingsProvider, super.key});

  final SettingsProvider settingsProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider(create: (_) => AuthProvider(AuthService())),
        ChangeNotifierProvider(create: (_) => WardrobeProvider(ApiService())),
        ChangeNotifierProvider(create: (_) => MvpProvider(ApiService())),
        ChangeNotifierProvider(
          create: (_) => OnboardingProvider(OnboardingService()),
        ),
        ChangeNotifierProvider(
          create: (_) => GmailSyncProvider(GmailImportService(ApiService())),
        ),
      ],
      child: MaterialApp(
        title: 'StyleStack',
        debugShowCheckedModeBanner: false,
        theme: DesignSystem.buildTheme(),
        home: const AuthGate(),
        builder: (context, child) => Stack(
          children: [
            child ?? const SizedBox.shrink(),
            Consumer<GmailSyncProvider>(
              builder: (context, sync, child) {
                if (!sync.isRunning) return const SizedBox.shrink();
                return Positioned(
                  top: MediaQuery.paddingOf(context).top,
                  left: 0,
                  right: 0,
                  child: const IgnorePointer(
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: Colors.transparent,
                      color: DesignSystem.primary,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _requestedUserId;

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, OnboardingProvider>(
      builder: (context, auth, onboarding, child) {
        if (!auth.initialized) {
          return const _StartupView();
        }

        final user = auth.user;
        if (user == null) {
          if (_requestedUserId != null) {
            _requestedUserId = null;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) context.read<OnboardingProvider>().reset();
            });
          }
          return const AuthScreen();
        }

        if (_requestedUserId != user.uid) {
          _requestedUserId = user.uid;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.read<OnboardingProvider>().loadForUser(user.uid);
            }
          });
          return const _StartupView();
        }

        if (onboarding.loading || !onboarding.loaded) {
          return const _StartupView();
        }

        if (onboarding.profile == null && onboarding.error != null) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_outlined,
                          size: 46,
                          color: DesignSystem.primary,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'We could not load your style profile',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          onboarding.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: DesignSystem.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          onPressed: () =>
                              onboarding.loadForUser(user.uid, force: true),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try again'),
                        ),
                        TextButton(
                          onPressed: auth.loading ? null : auth.signOut,
                          child: const Text('Sign out'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        if (!onboarding.completed) {
          return OnboardingScreen(
            updateDisplayName: (name) async {
              await user.updateDisplayName(name);
              await user.reload();
            },
          );
        }

        return const HomeScreen();
      },
    );
  }
}

class _StartupView extends StatelessWidget {
  const _StartupView();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StyleStackLogo(size: 58),
          SizedBox(height: 18),
          CircularProgressIndicator(),
        ],
      ),
    ),
  );
}
