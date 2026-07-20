import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

import 'config/design_system.dart';
import 'config/custom_widgets.dart';
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
    final foruiTheme = DesignSystem.buildForuiTheme();
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
        title: 'StyleStack: Your Style AI',
        debugShowCheckedModeBanner: false,
        supportedLocales: FLocalizations.supportedLocales,
        localizationsDelegates: const [
          ...FLocalizations.localizationsDelegates,
        ],
        theme: foruiTheme.toApproximateMaterialTheme().copyWith(
          scaffoldBackgroundColor: DesignSystem.background,
          appBarTheme: DesignSystem.buildTheme().appBarTheme,
          textTheme: DesignSystem.buildTheme().textTheme,
          inputDecorationTheme: DesignSystem.buildTheme().inputDecorationTheme,
          filledButtonTheme: DesignSystem.buildTheme().filledButtonTheme,
          outlinedButtonTheme: DesignSystem.buildTheme().outlinedButtonTheme,
          textButtonTheme: DesignSystem.buildTheme().textButtonTheme,
          floatingActionButtonTheme:
              DesignSystem.buildTheme().floatingActionButtonTheme,
          snackBarTheme: DesignSystem.buildTheme().snackBarTheme,
          bottomSheetTheme: DesignSystem.buildTheme().bottomSheetTheme,
        ),
        // Firebase phone authentication can reopen Android with a
        // `/link?deep_link_id=...` reCAPTCHA callback. Firebase Auth consumes
        // that callback natively; it is not a Flutter screen route.
        onGenerateInitialRoutes: (_) => [
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: Navigator.defaultRouteName),
            builder: (_) => const AuthGate(),
          ),
        ],
        onGenerateRoute: generateStyleStackRoute,
        builder: (context, child) => FTheme(
          data: foruiTheme,
          child: FToaster(
            child: FTooltipGroup(
              child: Stack(
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
          ),
        ),
      ),
    );
  }
}

@visibleForTesting
Route<void>? generateStyleStackRoute(RouteSettings settings) {
  final routeName = settings.name;
  if (routeName == null ||
      !routeName.startsWith('/link?') ||
      !routeName.contains('firebaseapp.com/__/auth/callback')) {
    return null;
  }

  // Android can deliver the callback after the app has already started. Use a
  // transparent, self-dismissing route so the existing AuthScreen (including
  // its phone and OTP state) stays mounted while Firebase completes
  // verification.
  return PageRouteBuilder<void>(
    settings: settings,
    opaque: false,
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (_, _, _) => const _FirebaseAuthCallbackRoute(),
  );
}

class _FirebaseAuthCallbackRoute extends StatefulWidget {
  const _FirebaseAuthCallbackRoute();

  @override
  State<_FirebaseAuthCallbackRoute> createState() =>
      _FirebaseAuthCallbackRouteState();
}

class _FirebaseAuthCallbackRouteState
    extends State<_FirebaseAuthCallbackRoute> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
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
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StyleStackLoadingIndicator(
              message: 'Preparing your StyleStack…',
              animationSize: 150,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    ),
  );
}
