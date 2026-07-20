import 'package:flutter_test/flutter_test.dart';
import 'package:stylestack_fe/models/outfit.dart';
import 'package:stylestack_fe/providers/mvp_provider.dart';
import 'package:stylestack_fe/services/api_service.dart';

void main() {
  test('logging an outfit advances the wear-history revision', () async {
    final api = _WearApi();
    final provider = MvpProvider(api);
    final outfit = Outfit(
      id: 'outfit-1',
      occasion: 'daily',
      reasoning: 'A balanced everyday look.',
      weather: const {},
      items: const [],
    );
    var notifications = 0;
    provider.addListener(() => notifications++);

    expect(await provider.markOutfitWorn(outfit), isTrue);

    expect(api.loggedOutfitIds, ['outfit-1']);
    expect(provider.wearHistoryRevision, 1);
    expect(notifications, 1);
  });
}

class _WearApi extends ApiService {
  final List<String> loggedOutfitIds = [];

  @override
  Future<int> wearOutfit(String outfitId) async {
    loggedOutfitIds.add(outfitId);
    return 0;
  }
}
