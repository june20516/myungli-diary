import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/gen/model/language.dart';
import 'package:myungli_diary/core/api/gen/model/stem.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/core/storage/saju_fingerprint.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/input/date_picker.dart';
import 'package:myungli_diary/design/components/saju/daeun_table.dart';
import 'package:myungli_diary/design/components/saju/manse_table.dart';
import 'package:myungli_diary/design/components/saju/saju_pillars.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/elements/ohaeng_cell.dart';
import 'package:myungli_diary/features/me/application/chart_providers.dart';
import 'package:myungli_diary/features/me/presentation/my_saju_screen.dart';
import 'package:myungli_diary/features/me/presentation/settings_screen.dart';
import 'package:myungli_diary/features/me/presentation/settings_sheets.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';
import 'package:myungli_diary/features/profile/presentation/profile_edit_screen.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_harness.dart';
import '../support/depth_link_finders.dart';
import '../support/onboarding_steps.dart';

// 나·설정 끝에서 끝 흐름(계획 6 Task 13). 화면별 세부는 각 화면 흐름 테스트에 있고,
// 여기서는 탭 하나에서 출발해 화면을 잇는 길만 봅니다.

final _ko = AppLocalizationsKo();

Finder _screen(String id) => find.byKey(ValueKey(id));

Finder _inScreen(String id, Finder matching) =>
    find.descendant(of: _screen(id), matching: matching);

FakeServerInterceptor _fake(ProviderContainer container) =>
    container.read(fakeServerInterceptorProvider)! as FakeServerInterceptor;

Map<String, Object?> _bodyOf(Object? data) =>
    (data is String ? jsonDecode(data) : data)! as Map<String, Object?>;

/// 생일(birth)을 바꾼 `updateProfile` 본문. 기기 시간대 동기화 요청은 거릅니다.
List<Map<String, Object?>> _birthPatches(ProviderContainer container) => [
  for (final body in _fake(container).requestBodiesOf('updateProfile'))
    if (_bodyOf(body).containsKey('birth')) _bodyOf(body),
];

/// 나 탭을 눌러 나의 사주 내용(일간 칸)이 올 때까지 기다립니다.
Future<void> _openMySaju(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('tab-bar.tab.3')));
  await pumpUntilScreen(tester, ScreenIds.mySaju);
  await pumpUntil(
    tester,
    () =>
        _inScreen(
          ScreenIds.mySaju,
          find.byType(OhaengCell),
        ).evaluate().isNotEmpty ||
        _inScreen(
          ScreenIds.mySaju,
          find.byType(ErrorState),
        ).evaluate().isNotEmpty,
  );
  await settleWithIo(tester);
}

/// 나의 사주의 톱니로 설정을 엽니다.
Future<void> _openSettingsFromMySaju(WidgetTester tester) async {
  await tester.tap(find.byKey(MySajuScreen.settingsKey));
  await pumpUntilScreen(tester, ScreenIds.settings);
  await settleWithIo(tester);
}

/// [key] 줄을 화면에 들인 뒤 누릅니다.
Future<void> _tapRow(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await settleWithIo(tester);
}

/// 생일 PATCH가 성공한 뒤의 나의 사주 응답에서 일간을 갑(甲)으로 바꿉니다.
///
/// 대역 서버의 차트 fixture는 입력과 상관없이 같으므로, 새 사주로 다시 계산된 응답을 흉내 냅니다.
/// PATCH 뒤에 들어온 차트 요청 수를 [chartRequestsAfterSave]로 셉니다.
final class _RecalculatedChart extends Interceptor {
  bool _saved = false;

  /// 생일 저장 뒤 들어온 `/v1/chart` 요청 수.
  int chartRequestsAfterSave = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_saved && options.path == '/v1/chart') {
      chartRequestsAfterSave++;
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    final options = response.requestOptions;
    final data = response.data;
    if (options.method == 'PATCH' &&
        options.path == '/v1/me/profile' &&
        _bodyOf(options.data).containsKey('birth')) {
      _saved = true;
    } else if (_saved && options.path == '/v1/chart' && data is Map) {
      final body = Map<String, Object?>.of(data.cast<String, Object?>());
      final pillars = Map<String, Object?>.of(
        (body['pillars']! as Map).cast<String, Object?>(),
      );
      pillars['day'] = {
        ...(pillars['day']! as Map).cast<String, Object?>(),
        'stem': 'gap',
      };
      body['pillars'] = pillars;
      response.data = body;
    }
    handler.next(response);
  }
}

/// 호칭·언어 PATCH가 성공한 뒤의 나의 사주 응답에서 첫 문장(`Chart.ilganHead`)을 그 값으로 바꿉니다.
///
/// 대역 서버의 차트 fixture는 프로필과 상관없이 같으므로, server가 새 호칭·언어로 문장을 만드는
/// 것을 흉내 냅니다. PATCH 뒤에 들어온 차트 요청 수를 [chartRequestsAfterPatch]로 셉니다.
final class _ProfileEchoChart extends Interceptor {
  String? _honorific;
  String? _language;

  /// 마지막 호칭·언어 PATCH 뒤 들어온 `/v1/chart` 요청 수.
  int chartRequestsAfterPatch = 0;

  /// 지금 server가 만들 첫 문장.
  String get sentence => _language == 'en'
      ? '${_honorific ?? 'Haneul'}, you resemble unpolished iron.'
      : '${_honorific ?? '하늘'}님, 다듬기 전의 단단한 쇠를 닮았어요.';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if ((_honorific != null || _language != null) &&
        options.path == '/v1/chart') {
      chartRequestsAfterPatch++;
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    final options = response.requestOptions;
    final data = response.data;
    if (options.method == 'PATCH' && options.path == '/v1/me/profile') {
      final patch = _bodyOf(options.data);
      if (patch['honorific'] case final String honorific) {
        _honorific = honorific;
        chartRequestsAfterPatch = 0;
      }
      if (patch['language'] case final String language) {
        _language = language;
        chartRequestsAfterPatch = 0;
      }
    } else if ((_honorific != null || _language != null) &&
        options.path == '/v1/chart' &&
        data is Map) {
      final body = Map<String, Object?>.of(data.cast<String, Object?>());
      body['ilganHead'] = {
        ...(body['ilganHead']! as Map).cast<String, Object?>(),
        'text': {
          'segments': [
            {'text': sentence},
          ],
        },
      };
      response.data = body;
    }
    handler.next(response);
  }
}

/// 나의 사주 화면 안의 [text] 문장(문장 블록은 RichText로 그림).
Finder _sentenceInMySaju(String text) =>
    _inScreen(ScreenIds.mySaju, find.text(text, findRichText: true));

/// [id] 화면을 닫습니다(뒤로).
Future<void> _pop(WidgetTester tester, String id) async {
  Navigator.of(tester.element(_screen(id))).pop();
  await settleWithIo(tester);
}

void main() {
  setUpAll(ensureTimeZonesInitialized);

  testWidgets('나의 사주 → 근거 보기 → 사주 표(만세력·대운 → 원국) → 용어 → 풀이 → 근거', (
    tester,
  ) async {
    covers(
      const Covers(
        exits: [
          'my-saju>saju-chart',
          'saju-chart>explain-sheet',
          'explain-sheet>evidence-sheet',
        ],
        decisions: ['D60'],
      ),
    );
    await pumpApp(tester, scenario: 'evidence-unlocked');
    await _openMySaju(tester);

    // 근거 보기 → 사주 표(원국부터).
    final link = depthLinkTarget(of: _screen(ScreenIds.mySaju));
    await tester.scrollUntilVisible(
      link,
      120,
      scrollable: _inScreen(ScreenIds.mySaju, find.byType(Scrollable)).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(link);
    await pumpUntilScreen(tester, ScreenIds.sajuChart);
    await pumpUntil(
      tester,
      () => _inScreen(
        ScreenIds.sajuChart,
        find.byType(SajuPillars),
      ).evaluate().isNotEmpty,
    );
    await settleWithIo(tester);

    // 만세력·대운 탭 → 표 둘, 다시 원국 탭.
    await tester.tap(
      _inScreen(ScreenIds.sajuChart, find.text(_ko.sajuChartTabLuck)),
    );
    await tester.pumpAndSettle();
    expect(
      _inScreen(ScreenIds.sajuChart, find.byType(ManseTable)),
      findsOneWidget,
    );
    expect(
      _inScreen(ScreenIds.sajuChart, find.byType(DaeunTable)),
      findsOneWidget,
    );
    expect(
      _inScreen(ScreenIds.sajuChart, find.byType(SajuPillars)),
      findsNothing,
    );
    await tester.tap(
      _inScreen(ScreenIds.sajuChart, find.text(_ko.sajuChartTabNatal)),
    );
    await tester.pumpAndSettle();
    expect(
      _inScreen(ScreenIds.sajuChart, find.byType(SajuPillars)),
      findsOneWidget,
    );

    // 원국표의 십성 용어 → 풀이 시트 → 근거 보기 → 근거 시트의 "내 사주에서는".
    await tester.tap(
      _inScreen(
        ScreenIds.sajuChart,
        find.widgetWithText(TermToken, '비견'),
      ).first,
    );
    await settleWithIo(tester);
    final explain = find.byKey(const Key(ScreenIds.explainSheet));
    expect(explain, findsOneWidget);
    await tester.tap(depthLinkTarget(of: explain));
    await settleWithIo(tester);
    final evidence = find.byKey(const Key(ScreenIds.evidenceSheet));
    expect(evidence, findsOneWidget);
    expect(
      find.descendant(
        of: evidence,
        matching: find.text(_ko.evidenceSheetSectionPersonal),
      ),
      findsOneWidget,
    );
  });

  testWidgets('설정 → 정보 수정 → 생일 바꿔 저장 → 확인 → 나의 사주가 새 원국', (tester) async {
    covers(
      const Covers(
        exits: [
          'my-saju>settings',
          'settings>profile-edit',
          'profile-edit>onboard-birth',
        ],
        decisions: ['D36'],
      ),
    );
    final network = _RecalculatedChart();
    final container = await pumpApp(tester, scenario: 'member');
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, network);

    await _openMySaju(tester);
    expect(
      container.read(chartControllerProvider).value?.pillars.day.stem,
      Stem.gyeong,
    );
    await _openSettingsFromMySaju(tester);
    await _tapRow(tester, SettingsScreen.profileEditRowKey);
    await pumpUntilScreen(tester, ScreenIds.profileEdit);

    // 생일 줄 → 수정 모드 생일 화면에서 일을 한 칸 내려(15일 → 16일) 돌아옵니다.
    await _tapRow(tester, ProfileEditScreen.birthRowKey);
    expect(_screen(ScreenIds.onboardBirth), findsOneWidget);
    await tester.drag(
      find.byKey(BirthDatePicker.dayWheelKey),
      const Offset(0, -40),
    );
    await tester.pumpAndSettle();
    await tapNext(tester);
    await settleWithIo(tester);
    expect(_screen(ScreenIds.profileEdit), findsOneWidget);
    // 아직 저장하지 않았습니다.
    expect(_birthPatches(container), isEmpty);

    // 저장 → 확인 창 → 다시 계산.
    await tester.tap(find.byKey(ProfileEditScreen.saveKey));
    await settleWithIo(tester);
    expect(find.text(_ko.profileEditRecalcConfirmTitle), findsOneWidget);
    await tester.tap(find.text(_ko.profileEditRecalcConfirmSave));
    await pumpUntilScreen(tester, ScreenIds.mySaju);
    await pumpUntil(
      tester,
      () =>
          container.read(chartControllerProvider).value?.pillars.day.stem ==
          Stem.gap,
    );
    await settleWithIo(tester);

    final patch = _birthPatches(container).single;
    expect((patch['birth']! as Map<String, Object?>)['date'], {
      'year': 1990,
      'month': 5,
      'day': 16,
    });
    final saved = await tester.runAsync(
      () => container.read(cachedProfileProvider.future),
    );
    expect(saved!.birth.date.day, 16);
    // 새 사주 지문이라 캐시가 아니라 새로 받은 원국입니다.
    expect(network.chartRequestsAfterSave, greaterThanOrEqualTo(1));
    // 일간 표지 칸이 새 일간(갑, 甲)입니다.
    expect(
      find.descendant(
        of: find.byKey(MySajuScreen.dayStemKey),
        matching: find.text('甲'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(MySajuScreen.dayStemKey),
        matching: find.text('갑'),
      ),
      findsOneWidget,
    );
    // 정보 수정·설정은 스택에서 빠졌습니다(go).
    expect(_screen(ScreenIds.profileEdit), findsNothing);
    expect(_screen(ScreenIds.settings), findsNothing);
  });

  testWidgets('설정 → 로그아웃 → welcome, 로컬 프로필 사본이 비워집니다', (tester) async {
    covers(const Covers(exits: ['my-saju>settings', 'settings>welcome']));
    final container = await pumpApp(tester, scenario: 'member');
    await _openMySaju(tester);
    await _openSettingsFromMySaju(tester);

    await _tapRow(tester, SettingsScreen.logoutRowKey);
    expect(find.text(_ko.settingsLogoutConfirm), findsOneWidget);
    await tester.tap(find.text(_ko.settingsLogoutConfirmLogout).last);
    await pumpUntilScreen(tester, ScreenIds.welcome);
    await settleWithIo(tester);

    expect(_fake(container).callCountOf('logout'), 1);
    expect(_screen(ScreenIds.mySaju), findsNothing);
    expect(_screen(ScreenIds.settings), findsNothing);
    final copy = await tester.runAsync(
      () => container.read(cachedProfileProvider.future),
    );
    expect(copy, isNull);
  });

  testWidgets('정보 수정에서 호칭을 바꾸면 나의 사주를 다시 받아 새 호칭 문장이 보입니다(A56)', (
    tester,
  ) async {
    covers(
      const Covers(
        exits: ['my-saju>settings', 'settings>profile-edit'],
        decisions: ['D60'],
      ),
    );
    final network = _ProfileEchoChart();
    final container = await pumpApp(tester, scenario: 'member');
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, network);

    await _openMySaju(tester);
    expect(_sentenceInMySaju(network.sentence), findsOneWidget);
    await _openSettingsFromMySaju(tester);
    await _tapRow(tester, SettingsScreen.profileEditRowKey);
    await pumpUntilScreen(tester, ScreenIds.profileEdit);

    await _tapRow(tester, ProfileEditScreen.callRowKey);
    await tester.enterText(find.byType(EditableText), '달');
    await tester.pump();
    await tapNext(tester);
    await settleWithIo(tester);
    expect(_screen(ScreenIds.profileEdit), findsOneWidget);

    await _pop(tester, ScreenIds.profileEdit);
    await _pop(tester, ScreenIds.settings);
    await pumpUntil(
      tester,
      () => _sentenceInMySaju('달님, 다듬기 전의 단단한 쇠를 닮았어요.').evaluate().isNotEmpty,
    );
    // 호칭 PATCH 뒤에 차트를 다시 물었습니다(캐시의 이전 호칭 문장이 남지 않음).
    expect(network.chartRequestsAfterPatch, greaterThanOrEqualTo(1));
    expect(_sentenceInMySaju('하늘님, 다듬기 전의 단단한 쇠를 닮았어요.'), findsNothing);
  });

  testWidgets('설정에서 언어를 en으로 바꾸면 나의 사주를 다시 받아 en 문장이 보입니다(A60)', (
    tester,
  ) async {
    covers(const Covers(exits: ['my-saju>settings'], decisions: ['D28']));
    final network = _ProfileEchoChart();
    final container = await pumpApp(tester, scenario: 'member');
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, network);

    await _openMySaju(tester);
    await _openSettingsFromMySaju(tester);
    await _tapRow(tester, SettingsScreen.languageRowKey);
    await tester.tap(find.byKey(LanguageSheet.rowKey(Language.en)));
    await settleWithIo(tester);
    // 출생지를 묻지 않은 계정이라 안내 시트가 뜹니다. 닫고 돌아갑니다.
    final notice = find.byKey(
      const ValueKey(SlotIds.settingsLanguageBirthplaceNotice),
    );
    if (notice.evaluate().isNotEmpty) {
      Navigator.of(tester.element(notice)).pop();
      await settleWithIo(tester);
    }
    await _pop(tester, ScreenIds.settings);

    await pumpUntil(
      tester,
      () =>
          _sentenceInMySaju('Haneul, you resemble unpolished iron.')
              .evaluate()
              .isNotEmpty,
    );
    expect(network.chartRequestsAfterPatch, greaterThanOrEqualTo(1));
    // bearer 요청이라 언어는 Accept-Language가 아니라 프로필 언어로 server가 고릅니다.
    // 캐시는 en 키로 갈라 둡니다.
    final profile = await tester.runAsync(
      () => container.read(cachedProfileProvider.future),
    );
    expect(profile!.language, Language.en);
    final key = chartKey(
      fingerprint: sajuFingerprint(profile),
      language: 'en',
      year: container.read(todayProvider).year,
    );
    final cached = await tester.runAsync(
      () => container.read(cacheStoreProvider).read(CacheKind.chart, key),
    );
    expect(cached, contains('you resemble unpolished iron'));
  });
}
