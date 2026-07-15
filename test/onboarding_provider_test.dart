import 'package:flutter_test/flutter_test.dart';
import 'package:stylestack_fe/models/onboarding_profile.dart';
import 'package:stylestack_fe/providers/onboarding_provider.dart';
import 'package:stylestack_fe/services/onboarding_service.dart';

void main() {
  test(
    'profile uses canonical onboarding wire keys and safe list defaults',
    () {
      final profile = OnboardingProfile.fromJson({
        'onboarding_completed': true,
        'display_name': 'Rounak',
        'gender_identity': 'man',
        'date_of_birth': '1995-08-15',
        'height_cm': 173,
        'style_preferences': null,
        'onboarding_goals': ['daily_outfit_ideas'],
      });

      expect(profile.completed, isTrue);
      expect(profile.gender, 'man');
      expect(profile.stylePreferences, isEmpty);
      expect(profile.styleGoals, ['daily_outfit_ideas']);
      expect(profile.toJson()['gender_identity'], 'man');
      expect(profile.toJson()['date_of_birth'], '1995-08-15');
      expect(profile.toJson()['onboarding_goals'], ['daily_outfit_ideas']);
    },
  );

  test('provider loads once per user and completes onboarding', () async {
    final repository = _FakeRepository();
    final provider = OnboardingProvider(repository);

    await provider.loadForUser('user-1');
    await provider.loadForUser('user-1');
    expect(repository.fetchCalls, 1);
    expect(provider.loaded, isTrue);
    expect(provider.completed, isFalse);

    final completed = await provider.complete(
      OnboardingProfile(
        displayName: 'Rounak',
        gender: 'man',
        dateOfBirth: DateTime(1995, 8, 15),
      ),
    );
    expect(completed, isTrue);
    expect(provider.completed, isTrue);
    expect(repository.saved?.displayName, 'Rounak');
  });

  test('provider exposes repository errors without throwing', () async {
    final provider = OnboardingProvider(
      _FakeRepository(error: 'Profile service unavailable'),
    );

    await provider.loadForUser('user-1');

    expect(provider.loaded, isTrue);
    expect(provider.error, 'Profile service unavailable');
  });
}

class _FakeRepository implements OnboardingRepository {
  _FakeRepository({this.error});

  final String? error;
  int fetchCalls = 0;
  OnboardingProfile? saved;

  @override
  Future<OnboardingProfile> fetch() async {
    fetchCalls++;
    if (error != null) throw OnboardingServiceException(error!);
    return const OnboardingProfile();
  }

  @override
  Future<OnboardingProfile> save(OnboardingProfile profile) async {
    if (error != null) throw OnboardingServiceException(error!);
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
