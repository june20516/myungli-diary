import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/platform/ads.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';

import '../support/app_harness.dart';
import '../support/onboarding_steps.dart';

/// 배너를 [gate]가 열릴 때까지 늦게 주는 광고 대역(하위 화면에서 돌아와 배너를 다시 불러오는
/// 때와 같음, #936 원인 ①).
final class _LateBannerAds implements Ads {
  new(this.gate);

  final Completer<void> gate;
  final _inner = FakeAds();

  @override
  Future<BannerAdHandle?> loadBanner({required int width}) async {
    await gate.future;
    return await _inner.loadBanner(width: width);
  }

  @override
  Future<RewardedAdHandle?> loadRewarded({required String userId}) =>
      _inner.loadRewarded(userId: userId);
}

/// [screenId] 화면의 세로 스크롤 위치(가장 바깥).
ScrollPosition _scroll(WidgetTester tester, String screenId) => tester
    .stateList<ScrollableState>(
      find.descendant(
        of: find.byKey(ValueKey(screenId)),
        matching: find.byType(Scrollable),
      ),
    )
    .firstWhere((state) => state.position.axis == Axis.vertical)
    .position;

Future<void> _scrollToEnd(WidgetTester tester, String screenId) async {
  for (var i = 0; i < 10; i++) {
    final position = _scroll(tester, screenId);
    if (position.pixels >= position.maxScrollExtent) break;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
  }
  await settleWithIo(tester);
}

void main() {
  // 탭 순서: 0 오늘, 1 달력, 2 일기(끝에서 다음 쪽이 붙는 목록이라 씌우지 않음), 3 나.
  for (final (tab, screenId) in [
    (0, ScreenIds.today),
    (1, ScreenIds.calendar),
    (3, ScreenIds.mySaju),
  ]) {
    testWidgets('$screenId: 끝에 닿은 뒤 배너가 늦게 나타나도 끝에 붙어 있습니다(#936)', (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 3
        // 세 화면 모두 스크롤이 생기는 낮은 화면(390x600).
        ..physicalSize = const Size(1170, 1800);
      addTearDown(tester.view.reset);
      final gate = Completer<void>();
      await pumpApp(
        tester,
        scenario: 'member',
        overrides: [adsProvider.overrideWithValue(_LateBannerAds(gate))],
      );
      await tester.tap(find.byKey(ValueKey('tab-bar.tab.$tab')));
      await pumpUntil(
        tester,
        () => find.byKey(ValueKey(screenId)).evaluate().isNotEmpty,
      );
      await settleWithIo(tester);
      await _scrollToEnd(tester, screenId);
      final before = _scroll(tester, screenId);
      expect(before.maxScrollExtent, greaterThan(0));
      expect(before.pixels, before.maxScrollExtent);
      final endBefore = before.maxScrollExtent;

      gate.complete();
      await settleWithIo(tester);
      final after = _scroll(tester, screenId);
      expect(after.maxScrollExtent, greaterThan(endBefore));
      expect(after.pixels, after.maxScrollExtent);
    });
  }
}
