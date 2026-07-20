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
import 'package:stylestack_fe/providers/mvp_provider.dart';
import 'package:stylestack_fe/screens/outfit_view.dart';
import 'package:stylestack_fe/services/api_service.dart';
import 'package:stylestack_fe/services/auth_service.dart';

void main() {
  testWidgets('Today styling tools lay out on a compact phone', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gateway = _SignedOutGateway();
    final auth = AuthProvider(gateway);
    final foruiTheme = DesignSystem.buildForuiTheme();
    final api = _TodayApi();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider(create: (_) => MvpProvider(api)),
        ],
        child: MaterialApp(
          supportedLocales: FLocalizations.supportedLocales,
          localizationsDelegates: const [
            ...FLocalizations.localizationsDelegates,
          ],
          theme: DesignSystem.buildTheme(),
          home: const Scaffold(
            body: DailyOutfitView(
              onOpenHistory: _noOp,
              onOpenProfile: _noOp,
              onCreateStyle: _noOpAsync,
              onAddItem: _noOpAsync,
            ),
          ),
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
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text('YOUR STYLING STUDIO'), findsOneWidget);
    expect(find.text('Ask your\nstylist'), findsOneWidget);

    await tester.tap(find.byTooltip('Create another look'));
    await tester.pump();
    expect(find.text('Creating your next look'), findsOneWidget);

    api.completePendingLook();
    await tester.pumpAndSettle();

    auth.dispose();
    await gateway.dispose();
  });
}

void _noOp() {}

Future<void> _noOpAsync() async {}

class _TodayApi extends ApiService {
  int _suggestionCalls = 0;
  Completer<Outfit>? _pendingLook;

  List<WardrobeItem> get _items => List.generate(
    2,
    (index) => WardrobeItem(
      id: 'item-$index',
      name: index == 0 ? 'White shirt' : 'Navy trousers',
      category: index == 0 ? 'shirt' : 'pants',
      createdAt: DateTime(2026, 7, 20),
    ),
  );

  @override
  Future<UserPreferences> fetchPreferences() async =>
      const UserPreferences(city: 'Goa');

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
  }) {
    final outfit = Outfit(
      id: 'outfit-${_suggestionCalls + 1}',
      occasion: occasion,
      reasoning: 'Balanced proportions and a clean tonal palette.',
      weather: const {
        'description': 'clear',
        'temperature_c': 27,
        'city': 'Goa',
      },
      items: _items,
    );
    if (_suggestionCalls++ == 0) return Future.value(outfit);
    _pendingLook = Completer<Outfit>();
    return _pendingLook!.future;
  }

  void completePendingLook() {
    final pending = _pendingLook;
    if (pending != null && !pending.isCompleted) {
      pending.complete(
        Outfit(
          id: 'outfit-complete',
          occasion: 'daily alternative',
          reasoning: 'A fresh combination with intentional proportions.',
          weather: const {
            'description': 'clear',
            'temperature_c': 27,
            'city': 'Goa',
          },
          items: _items,
        ),
      );
    }
  }
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
