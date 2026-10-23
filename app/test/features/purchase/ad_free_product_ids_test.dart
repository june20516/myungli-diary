import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/http_client.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/features/purchase/data/ad_free_product_ids.dart';

void main() {
  test('쉼표로 나누고 공백과 빈 값을 버립니다', () {
    expect(adFreeProductIdsFrom(' a, b ,,', mode: ApiMode.http), {'a', 'b'});
  });

  test('http 모드에서 비면 빈 집합', () {
    expect(adFreeProductIdsFrom('', mode: ApiMode.http), isEmpty);
  });

  test('fake 모드에서 비면 대역 광고 제거권 id', () {
    expect(adFreeProductIdsFrom('', mode: ApiMode.fake), {fakeAdFreeProductId});
  });

  test('fake 모드라도 값이 있으면 그 값', () {
    expect(adFreeProductIdsFrom('x', mode: ApiMode.fake), {'x'});
  });
}
