import 'package:myungli_diary/core/api/http_client.dart';
import 'package:myungli_diary/core/platform/fakes.dart';

/// 쉼표로 이어 적은 광고 제거권 상품 id([value])를 집합으로 나눕니다.
///
/// 공백과 빈 값은 버립니다. 결과가 비었고 [mode]가 대역(`ApiMode.fake`)이면
/// 대역 상품 [fakeAdFreeProductId]만 광고 제거권으로 봅니다.
Set<String> adFreeProductIdsFrom(String value, {required ApiMode mode}) {
  final ids = {
    for (final part in value.split(','))
      if (part.trim().isNotEmpty) part.trim(),
  };
  if (ids.isEmpty && mode == ApiMode.fake) {
    return {fakeAdFreeProductId};
  }
  return ids;
}
