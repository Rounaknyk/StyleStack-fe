import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:stylestack_fe/config/design_system.dart';
import 'package:stylestack_fe/models/calendar_models.dart';
import 'package:stylestack_fe/models/outfit.dart';
import 'package:stylestack_fe/models/wardrobe_item.dart';
import 'package:stylestack_fe/providers/auth_provider.dart';
import 'package:stylestack_fe/providers/gmail_sync_provider.dart';
import 'package:stylestack_fe/providers/mvp_provider.dart';
import 'package:stylestack_fe/providers/wardrobe_provider.dart';
import 'package:stylestack_fe/screens/home_screen.dart';
import 'package:stylestack_fe/services/api_service.dart';
import 'package:stylestack_fe/services/auth_service.dart';

void main() {
  testWidgets('home tabs lay out on a compact phone during startup', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gateway = _SignedOutGateway();
    final auth = AuthProvider(gateway);
    final api = _StartupApi();
    final foruiTheme = DesignSystem.buildForuiTheme();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider(create: (_) => WardrobeProvider(api)),
          ChangeNotifierProvider(create: (_) => MvpProvider(api)),
          ChangeNotifierProvider(
            create: (_) => GmailSyncProvider.withRunner(
              ({onConnectionComplete}) async => const {},
            ),
          ),
        ],
        child: MaterialApp(
          supportedLocales: FLocalizations.supportedLocales,
          localizationsDelegates: const [
            ...FLocalizations.localizationsDelegates,
          ],
          theme: DesignSystem.buildTheme(),
          home: const HomeScreen(),
          builder: (context, child) => FTheme(
            data: foruiTheme,
            child: FToaster(
              child: FTooltipGroup(child: child ?? const SizedBox.shrink()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.byType(FBottomNavigationBar), findsOneWidget);

    auth.dispose();
    await gateway.dispose();
  });

  testWidgets('generated outfit board lays out without viewport failures', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gateway = _SignedOutGateway();
    final auth = AuthProvider(gateway);
    final api = _StartupApi(styled: true);
    final foruiTheme = DesignSystem.buildForuiTheme();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider(create: (_) => WardrobeProvider(api)),
          ChangeNotifierProvider(create: (_) => MvpProvider(api)),
          ChangeNotifierProvider(
            create: (_) => GmailSyncProvider.withRunner(
              ({onConnectionComplete}) async => const {},
            ),
          ),
        ],
        child: MaterialApp(
          supportedLocales: FLocalizations.supportedLocales,
          localizationsDelegates: const [
            ...FLocalizations.localizationsDelegates,
          ],
          theme: DesignSystem.buildTheme(),
          home: const HomeScreen(),
          builder: (context, child) => FTheme(
            data: foruiTheme,
            child: FToaster(
              child: FTooltipGroup(child: child ?? const SizedBox.shrink()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.text('Today’s outfit'), findsOneWidget);

    auth.dispose();
    await gateway.dispose();
  });
}

class _StartupApi extends ApiService {
  _StartupApi({this.styled = false});

  final bool styled;

  List<WardrobeItem> get _items => List.generate(
    styled ? 5 : 0,
    (index) => WardrobeItem(
      id: 'item-$index',
      name: 'Wardrobe item $index',
      category: 'shirt',
      createdAt: DateTime(2026, 7, 15),
    ),
  );

  @override
  Future<List<WardrobeItem>> fetchItems() async => _items;

  @override
  Future<UserPreferences> fetchPreferences() async =>
      UserPreferences(city: styled ? 'Goa' : null);

  @override
  Future<List<StyleCalendarEvent>> fetchCalendarEvents({
    DateTime? start,
    DateTime? end,
  }) async => const [];

  @override
  Future<Outfit> suggestOutfit({
    required String city,
    required String occasion,
    String? calendarEventId,
  }) async => Outfit(
    id: 'outfit-1',
    occasion: occasion,
    reasoning: 'Balanced colors and proportions for a polished daily look.',
    weather: const {'description': 'clear', 'temperature_c': 27},
    items: _items.take(2).toList(),
  );
}

class _SignedOutGateway implements AuthGateway {
  final _users = StreamController<User?>.broadcast();

  @override
  Stream<User?> get authStateChanges => _users.stream;

  @override
  Future<void> createAccountWithEmail(String email, String password) async {}

  @override
  Future<void> signInWithEmail(String email, String password) async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> startPhoneVerification({
    required String phoneNumber,
    required AuthPhoneVerificationSucceeded verificationCompleted,
    required AuthPhoneVerificationFailed verificationFailed,
    required AuthPhoneCodeSent codeSent,
    required AuthPhoneCodeTimedOut codeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {}

  @override
  Future<void> confirmPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {}

  @override
  Future<void> signOut() async {}

  Future<void> dispose() => _users.close();
}
