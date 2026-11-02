import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/platform/unavailable_store.dart';

void main() {
  group('NoAds', () {
    test('배너와 보상형은 null', () async {
      const ads = NoAds();
      expect(await ads.loadBanner(width: 320), isNull);
      expect(await ads.loadRewarded(userId: 'account'), isNull);
    });
  });
}
