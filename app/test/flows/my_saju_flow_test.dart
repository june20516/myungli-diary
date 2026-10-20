import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/design/elements/ohaeng_cell.dart';
import 'package:myungli_diary/features/me/presentation/my_saju_screen.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_bar_title.dart';
import '../support/app_harness.dart';
import '../support/chart_network.dart';
import '../support/onboarding_steps.dart';

final _ko = AppLocalizationsKo();

/// [scenario]로 앱을 띄우고 나 탭을 엽니다.
Future<ProviderContainer> _openMe(
  WidgetTester tester, {
  String scenario = 'member',
  Interceptor? network,
  bool settle = true,
}) async {
  final container = await pumpApp(tester, scenario: scenario);
  if (network != null) {
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, network);
  }
  await tester.tap(find.byKey(const ValueKey('tab-bar.tab.3')));
  await pumpUntilScreen(tester, ScreenIds.mySaju);
  if (settle) {
    await pumpUntil(
      tester,
      () =>
          find.byType(OhaengCell).evaluate().isNotEmpty ||
          find.byType(ErrorState).evaluate().isNotEmpty,
    );
    await settleWithIo(tester);
  }
  return container;
}

/// 받은 나의 사주에서 문장 필드(draft.10, 선택)를 뺍니다.
final class _DropSentences extends Interceptor {
  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    final data = response.data;
    if (response.requestOptions.path == '/v1/chart' && data is Map) {
      response.data = Map<String, Object?>.of(data.cast<String, Object?>())
        ..remove('ilganHead')
        ..remove('ilganBody')
        ..remove('yongsinSummary');
    }
    handler.next(response);
  }
}

/// [slotId] 문장 덩어리.
Finder _block(String slotId) => find.byWidgetPredicate(
  (widget) => widget is SentenceBlock && widget.slotId == slotId,
);

void main() {
  testWidgets('제목, 일간 칸과 이름, 용신 줄과 행운 색', (tester) async {
    covers(const Covers(decisions: ['D16']));
    await _openMe(tester);
    await expectAppBarTitle(tester, SlotIds.mySajuBarTitle, _ko.mySajuBarTitle);
    final cell = tester.widget<OhaengCell>(find.byType(OhaengCell));
    expect(cell.hanja, '庚');
    expect(find.text('경'), findsWidgets);
    expect(find.text('나와 잘 맞는 기운'), findsOneWidget);
    // 용신 줄의 오행 용어와 용신 설명 문장 안 용어, 두 곳입니다.
    expect(find.text('수'), findsNWidgets(2));
    final chip = tester.widget<LuckyChip>(find.byType(LuckyChip));
    expect(chip.item.value, '남색');
  });

  testWidgets('문장 필드가 있으면 A55 순서(일간 → 일간 소개 → 용신 → 용신 설명 → 근거 보기)로 그립니다', (
    tester,
  ) async {
    await _openMe(tester);
    double top(Finder finder) => tester.getTopLeft(finder).dy;
    final cell = find.byType(OhaengCell);
    final head = _block(SlotIds.mySajuIlganHead);
    final body = _block(SlotIds.mySajuIlganBody);
    final lucky = find.byType(LuckyChip);
    final summary = _block(SlotIds.mySajuYongsinBody);
    final link = find.byType(DepthLink);
    for (final finder in [head, body, summary]) {
      expect(finder, findsOneWidget);
      expect(
        tester.widget<SentenceBlock>(finder).variant,
        SentenceBlockVariant.card,
      );
    }
    expect(
      find.textContaining('하늘님, 다듬기 전의', findRichText: true),
      findsOneWidget,
    );
    final order = [cell, head, body, lucky, summary, link].map(top).toList();
    expect(order, orderedEquals([...order]..sort()));
  });

  testWidgets('문장 필드가 없으면(선택) 그 자리를 그리지 않습니다', (tester) async {
    await _openMe(tester, network: _DropSentences());
    expect(_block(SlotIds.mySajuIlganHead), findsNothing);
    expect(_block(SlotIds.mySajuIlganBody), findsNothing);
    expect(_block(SlotIds.mySajuYongsinBody), findsNothing);
    expect(find.byType(LuckyChip), findsOneWidget);
  });

  testWidgets('일간 이름 용어 → 풀이 시트', (tester) async {
    covers(const Covers(exits: ['my-saju>explain-sheet']));
    await _openMe(tester);
    await tester.tap(find.text('경').last);
    await settleWithIo(tester);
    expect(find.byKey(const Key(ScreenIds.explainSheet)), findsOneWidget);
  });

  testWidgets('근거 보기 → 사주 표', (tester) async {
    covers(const Covers(exits: ['my-saju>saju-chart']));
    await _openMe(tester);
    final link = find.descendant(
      of: find.byType(DepthLink),
      matching: find.byType(PressInkTarget),
    );
    await tester.scrollUntilVisible(
      link,
      120,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey(ScreenIds.mySaju)),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(link);
    await pumpUntilScreen(tester, ScreenIds.sajuChart);
    expect(find.byKey(const ValueKey(ScreenIds.sajuChart)), findsOneWidget);
  });

  testWidgets('톱니 → 설정', (tester) async {
    covers(const Covers(exits: ['my-saju>settings']));
    await _openMe(tester);
    await tester.tap(find.byKey(MySajuScreen.settingsKey));
    await pumpUntilScreen(tester, ScreenIds.settings);
    expect(find.byKey(const ValueKey(ScreenIds.settings)), findsOneWidget);
  });

  testWidgets('time-unknown: 3주로 계산했다는 배너', (tester) async {
    covers(const Covers(states: ['my-saju:time-unknown']));
    await _openMe(tester, scenario: 'member-time-unknown');
    final banner = tester.widget<NoticeBanner>(find.byType(NoticeBanner).last);
    expect(banner.variant, NoticeBannerVariant.timeUnknown);
  });

  testWidgets('loading: 받는 동안 skeleton, 오면 내용', (tester) async {
    covers(const Covers(states: ['my-saju:loading']));
    final network = ChartNetwork()..hold = true;
    await _openMe(tester, network: network, settle: false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey(ScreenIds.mySaju)),
        matching: find.byKey(const ValueKey('screen-state.loading')),
      ),
      findsOneWidget,
    );
    network.gate.complete();
    await pumpUntil(
      tester,
      () => find.byType(OhaengCell).evaluate().isNotEmpty,
    );
    await settleWithIo(tester);
  });

  testWidgets('error: 받지 못하면 오류와 다시 시도', (tester) async {
    covers(const Covers(states: ['my-saju:error']));
    final network = ChartNetwork()..fail = true;
    await _openMe(tester, network: network);
    expect(find.byType(ErrorState), findsOneWidget);
    network.fail = false;
    await tester.tap(find.text(_ko.actionRetry));
    await pumpUntil(
      tester,
      () => find.byType(OhaengCell).evaluate().isNotEmpty,
    );
    await settleWithIo(tester);
    expect(find.byType(OhaengCell), findsOneWidget);
  });
}
