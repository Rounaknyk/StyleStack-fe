import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stylestack_fe/config/design_system.dart';
import 'package:stylestack_fe/models/onboarding_profile.dart';
import 'package:stylestack_fe/providers/onboarding_provider.dart';
import 'package:stylestack_fe/screens/onboarding_screen.dart';
import 'package:stylestack_fe/services/onboarding_service.dart';

void main() {
  testWidgets('mandatory questions gate progress and optional cards can skip', (
    tester,
  ) async {
    final repository = _ScreenRepository();
    final provider = OnboardingProvider(repository);
    var firebaseName = '';
    var finished = false;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          theme: DesignSystem.buildTheme(),
          home: OnboardingScreen(
            updateDisplayName: (name) async => firebaseName = name,
            onCompleted: () => finished = true,
          ),
        ),
      ),
    );

    FilledButton continueButton() => tester.widget<FilledButton>(
      find.byKey(const Key('onboarding_continue')),
    );

    expect(continueButton().onPressed, isNull);
    await tester.enterText(find.byKey(const Key('onboarding_name')), 'Rounak');
    await tester.pump();
    expect(continueButton().onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('onboarding_continue')));
    await tester.pumpAndSettle();

    expect(continueButton().onPressed, isNull);
    await tester.tap(find.byKey(const Key('onboarding_choice_man')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('onboarding_continue')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('onboarding_dob')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_continue')));
    await tester.pumpAndSettle();

    for (var index = 0; index < 5; index++) {
      await tester.tap(find.byKey(const Key('onboarding_skip')));
      await tester.pumpAndSettle();
    }

    expect(find.text("You're all set, Rounak!"), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding_finish')));
    await tester.pumpAndSettle();

    expect(finished, isTrue);
    expect(firebaseName, 'Rounak');
    expect(repository.saved?.gender, 'man');
  });
}

class _ScreenRepository implements OnboardingRepository {
  OnboardingProfile? saved;

  @override
  Future<OnboardingProfile> fetch() async => const OnboardingProfile();

  @override
  Future<OnboardingProfile> save(OnboardingProfile profile) async {
    saved = profile;
    return OnboardingProfile(
      completed: true,
      displayName: profile.displayName,
      gender: profile.gender,
      dateOfBirth: profile.dateOfBirth,
      bodyType: profile.bodyType,
      heightCm: profile.heightCm,
      stylePreferences: profile.stylePreferences,
      shoppingFrequency: profile.shoppingFrequency,
      styleGoals: profile.styleGoals,
    );
  }
}
