import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stylestack_fe/services/rewarded_ad_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('two free refreshes are followed by a rewarded refresh', () async {
    final service = RewardedAdService.instance;

    expect(await service.dailyRefreshAccess('user-a'), DailyRefreshAccess.free);
    await service.consumeRefresh('user-a', DailyRefreshAccess.free);
    expect(await service.dailyRefreshAccess('user-a'), DailyRefreshAccess.free);
    await service.consumeRefresh('user-a', DailyRefreshAccess.free);

    expect(
      await service.dailyRefreshAccess('user-a'),
      DailyRefreshAccess.rewardedAdRequired,
    );
    expect(await service.dailyRefreshAccess('user-b'), DailyRefreshAccess.free);
  });

  test('earned calendar bonus is consumed only once', () async {
    final service = RewardedAdService.instance;
    await service.consumeRefresh('user-a', DailyRefreshAccess.free);
    await service.consumeRefresh('user-a', DailyRefreshAccess.free);
    await service.grantBonusRefresh('user-a');

    expect(
      await service.dailyRefreshAccess('user-a'),
      DailyRefreshAccess.bonus,
    );
    await service.consumeRefresh('user-a', DailyRefreshAccess.bonus);
    expect(
      await service.dailyRefreshAccess('user-a'),
      DailyRefreshAccess.rewardedAdRequired,
    );
  });

  test('calendar reward offer is remembered per user', () async {
    final service = RewardedAdService.instance;

    expect(await service.hasSeenCalendarOffer('user-a'), isFalse);
    await service.markCalendarOfferSeen('user-a');

    expect(await service.hasSeenCalendarOffer('user-a'), isTrue);
    expect(await service.hasSeenCalendarOffer('user-b'), isFalse);
  });
}
