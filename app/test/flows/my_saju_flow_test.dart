import 'dart:async';

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
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/design/elements/ohaeng_cell.dart';
import 'package:myungli_diary/features/me/presentation/my_saju_screen.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_bar_title.dart';
import '../support/app_harness.dart';
import '../support/onboarding_steps.dart';

final _ko = AppLocalizationsKo();

/// `/v1/chart`를 [hold]면 [gate]까지 붙잡고, [fail]이면 503으로 답합니다.
final class _ChartNetwork extends Interceptor {
  bool hold = false;
  bool fail = false;
  final gate = Completer<void>();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.path != '/v1/chart') {
      handler.next(options);
      return;
    }
    if (hold) await gate.future;
    if (fail) {
      handler.reject(
        DioException.badResponse(
          statusCode: 503,
          requestOptions: options,
          response: Response<Object?>(
            requestOptions: options,
            statusCode: 503,
            data: {
              'type': 'about:blank',
              'title': 'Unavailable',
              'status': 503,
              'code': 'service.unavailable',
              'traceId': 'test',
            },
            headers: Headers.fromMap({
              Headers.contentTypeHeader: ['application/problem+json'],
            }),
          ),
        ),
        true,
      );
      return;
    }
    handler.next(options);
  }
}

/// [scenario]로 앱을 띄우고 나 탭을 엽니다.
Future<ProviderContainer> _openMe(
  WidgetTester tester, {
  String scenario = 'member',
  _ChartNetwork? network,
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

void main() {
  testWidgets('제목, 일간 칸과 이름, 용신 줄과 행운 색', (tester) async {
    covers(const Covers(decisions: ['D16']));
    await _openMe(tester);
    await expectAppBarTitle(tester, SlotIds.mySajuBarTitle, _ko.mySajuBarTitle);
    final cell = tester.widget<OhaengCell>(find.byType(OhaengCell));
    expect(cell.hanja, '庚');
    expect(find.text('경'), findsWidgets);
    expect(find.text('나와 잘 맞는 기운'), findsOneWidget);
    expect(find.text('수'), findsOneWidget);
    final chip = tester.widget<LuckyChip>(find.byType(LuckyChip));
    expect(chip.item.value, '남색');
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
    await tester.ensureVisible(link);
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
    final network = _ChartNetwork()..hold = true;
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
    final network = _ChartNetwork()..fail = true;
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
