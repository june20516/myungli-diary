import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/gen/model/daily.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/diary_summary.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/design/components/action/share_button.dart';
import 'package:myungli_diary/design/components/calendar/event_row.dart';
import 'package:myungli_diary/design/components/diary/diary_row.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/frame/section_header.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/components/sentence/reaction_button.dart';
import 'package:myungli_diary/design/components/today/date_header.dart';
import 'package:myungli_diary/design/components/today/guide_question_card.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/depth/application/explain_content.dart';
import 'package:myungli_diary/features/diary/application/diary_providers.dart';
import 'package:myungli_diary/features/schedule/application/schedule_providers.dart';
import 'package:myungli_diary/features/schedule/model/today_schedule_summary.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';
import 'package:myungli_diary/features/today/presentation/today_screen.dart';

import '../../support/app_harness.dart';
import '../../support/daily_fixture.dart';
import '../../support/onboarding_steps.dart' show pumpUntil;
import '../../support/reaction_not_found.dart';
import '../../support/test_today.dart';

final _ko = AppLocalizationsKo();
final _today = CalendarDate(2026, 10, 13);

Finder _id(String identifier) => find.bySemanticsIdentifier(identifier);

FakeServerInterceptor _fake(ProviderContainer container) =>
    container.read(fakeServerInterceptorProvider)! as FakeServerInterceptor;

final Finder _content = find.byType(DateHeader);
final Finder _loading = find.byKey(const ValueKey('screen-state.loading'));

/// 오늘 내용이나 오류 화면이 보일 때까지 기다립니다.
Future<void> _settleToday(WidgetTester tester) => pumpUntil(
  tester,
  () =>
      _content.evaluate().isNotEmpty ||
      find.byType(ErrorState).evaluate().isNotEmpty,
);

/// [build]로 값을 내는 오늘 응답 대역. 다시 시도 횟수를 셉니다.
final class _StubDaily extends DailyController {
  new(this._build);

  final Future<DailyView> Function() _build;

  @override
  Future<DailyView> build() => _build();
}

/// 캐시 값을 먼저 내보내고 server 응답이 끝나면 그 값으로 바꾸는 대역(controller와 같은 순서).
final class _CacheThenServer extends DailyController {
  new(this._cached, this._server);

  final DailyView _cached;
  final Future<DailyView> _server;

  @override
  Future<DailyView> build() {
    state = AsyncData(_cached);
    return _server;
  }
}

DailyView _view({bool stale = false}) => DailyView(
  date: _today,
  daily: Daily.fromJson(memberDailyJson()),
  stale: stale,
  cacheKey: null,
);

/// `/v1/daily/`만 [hold]가 끝날 때까지 붙잡습니다.
final class _DailyHold extends Interceptor {
  Completer<void>? hold;
  final paths = <String>[];

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.path.startsWith('/v1/daily/')) {
      paths.add(options.path);
      await hold?.future;
    }
    handler.next(options);
  }
}

/// 일기 목록(`GET /v1/diaries`)을 503으로 답합니다.
final class _FailDiaryList extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method == 'GET' && options.path == '/v1/diaries') {
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

final NotifierProvider<TestToday, CalendarDate> _testTodayProvider =
    testTodayProvider(_today);

/// member 오늘 응답을 [change]로 고친 값으로 답하는 대역 override.
Override _dailyWith(void Function(Map<String, dynamic> json) change) {
  final json = memberDailyJson();
  change(json);
  return dailyControllerProvider.overrideWith(
    () => _StubDaily(
      () async => DailyView(
        date: _today,
        daily: Daily.fromJson(json),
        stale: false,
        cacheKey: null,
      ),
    ),
  );
}

/// 사전 응답(`/v1/glossary`)에 [extra] 범주 이름을 더합니다(member 사전에 아직 없는 범주).
final class _GlossaryWith extends Interceptor {
  new(this.extra);

  final Map<String, Map<String, String>> extra;

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    final data = response.data;
    if (response.requestOptions.path == '/v1/glossary' && data is Map) {
      final body = Map<String, Object?>.of(data.cast<String, Object?>());
      body['values'] = {
        ...(body['values']! as Map).cast<String, Object?>(),
        ...extra,
      };
      response.data = body;
    }
    handler.next(response);
  }
}

/// 깊이 시트를 열면 무엇을 열었는지 남기는 대역. 시트 본문은 이름표 글자 하나입니다.
///
/// 본문 builder는 시트가 다시 그려질 때마다 불리므로 풀이 시트는 마지막 값을 보고, 사주 기운
/// 시트 순번은 바뀔 때만 남깁니다.
final class _SheetLog {
  final explained = <ExplainContent>[];
  final explainHeads = <Widget?>[];
  final tagRanks = <int>[];

  Override get override => depthSheetsProvider.overrideWithValue(
    DepthSheets(
      explainBody: (content, {head, diaryLinkTag}) {
        explained.add(content);
        explainHeads.add(head);
        return const Text('explain-body');
      },
      evidenceBody: (_, _, _) => const Text('evidence-body'),
      shareBody: () => const Text('share-body'),
      tagBody: (daily, rank) {
        if (tagRanks.lastOrNull != rank) tagRanks.add(rank);
        return Text('tag-body $rank');
      },
    ),
  );
}

/// [slotId] 자리의 `hanja-tag`.
Finder _tagIn(String slotId) => find.descendant(
  of: find.byKey(ValueKey(slotId)),
  matching: find.byType(HanjaTag),
);

/// 사주 기운 섹션 카드 안의 `hanja-tag`.
Finder _featuredTags() => find.descendant(
  of: find.byKey(TodayScreen.featuredCardKey),
  matching: find.byType(HanjaTag),
);

void main() {
  setUpAll(ensureTimeZonesInitialized);

  testWidgets('member: 날짜 머리, 총운(결정 태그, 헤드라인, 보조 문장), 사주 기운, 행운, 질문 순서와 제목', (
    tester,
  ) async {
    await pumpApp(tester, scenario: 'member');
    await _settleToday(tester);

    expect(find.byKey(const ValueKey(ScreenIds.today)), findsOneWidget);
    expect(_id(ScreenIds.today), findsOneWidget);

    // 날짜 머리: 양력과 요일, 음력, 일진(사전 독음).
    final header = tester.widget<DateHeader>(_content);
    expect(header.solar, _ko.todayDateSolar('10월 13일 화요일'));
    expect(header.lunar, _ko.todayDateLunar(9, 3));
    expect(header.iljin, _ko.todayDateIljin('庚申(경신)'));

    // 섹션 제목은 위에서부터 총운, 사주 기운, 행운, 일정(있는 날), 오늘의 질문입니다.
    final titles = [
      for (final section in tester.widgetList<SectionHeader>(
        find.byType(SectionHeader),
      ))
        section.title,
    ];
    expect(titles, [
      _ko.todayFortuneTitle,
      _ko.todayFeaturedTitle,
      _ko.todayLuckyTitle,
      _ko.todayEventTitle,
      _ko.todayGuideTitle,
    ]);
    double topOf(Finder finder) => tester.getTopLeft(finder).dy;
    expect(topOf(_content), lessThan(topOf(find.byType(SectionHeader).first)));

    // 총운 결정 태그: 날의 성격 emphasis(용신 톤) 다음에 일진 십성 묶음(비겁).
    final dayKind = tester.widget<HanjaTag>(
      _tagIn(SlotIds.todayCharacterLabel),
    );
    expect(dayKind.glyph, '用');
    expect(dayKind.label, _ko.dayKindYongsinDay);
    expect(dayKind.tone, HanjaTagTone.yongsin);
    expect(dayKind.variant, HanjaTagVariant.emphasis);
    final tenGod = tester.widget<HanjaTag>(_tagIn(SlotIds.todayTenGodLabel));
    expect(tenGod.label, '비겁');
    expect(tenGod.variant, HanjaTagVariant.normal);

    // 헤드라인과 근거 아이콘(글자 없음, 이름은 총운).
    expect(_id(SlotIds.todayFortuneHead), findsOneWidget);
    final link = find.descendant(
      of: find.byKey(const Key(SlotIds.todayFortuneHead)),
      matching: find.byType(DepthLink),
    );
    expect(tester.widget<DepthLink>(link).variant, DepthLinkVariant.inlineEnd);
    expect(tester.widget<DepthLink>(link).label, isNull);
    expect(tester.widget<DepthLink>(link).subject, _ko.todayFortuneTitle);
    expect(
      topOf(_tagIn(SlotIds.todayCharacterLabel)),
      lessThan(topOf(find.byKey(const Key(SlotIds.todayFortuneHead)))),
    );

    // 선 아래 1순위 태그(합)와 보조 문장, 그 끝 근거 아이콘.
    expect(find.byKey(TodayScreen.fortuneDividerKey), findsOneWidget);
    final bodyTag = tester.widget<HanjaTag>(
      _tagIn(TodayScreen.bodyTagKeyValue),
    );
    expect(bodyTag.glyph, '合');
    expect(bodyTag.label, '합');
    expect(bodyTag.variant, HanjaTagVariant.normal);
    expect(_id(SlotIds.todayFortuneBody), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key(SlotIds.todayFortuneBody)),
        matching: find.byType(DepthLink),
      ),
      findsOneWidget,
    );

    // 사주 기운: 대표 태그 줄.
    expect(
      [
        for (final tag in tester.widgetList<HanjaTag>(_featuredTags()))
          tag.label,
      ],
      ['합', '비겁이 많은 날'],
    );
    expect(find.text(_ko.todayFeaturedEmpty), findsNothing);

    for (final variant in LuckyCardVariant.luckyValues) {
      expect(find.byKey(LuckyCardRow.chipKey(variant)), findsOneWidget);
    }
    expect(find.text('초록'), findsOneWidget);
    expect(find.text(_ko.direction8E), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('09:30~11:30'), findsOneWidget);

    // 오늘의 질문: 섹션 제목이 같은 말을 하므로 카드 머리글은 없습니다.
    final guide = tester.widget<GuideQuestionCard>(
      find.byType(GuideQuestionCard),
    );
    expect(guide.eyebrow, isNull);
    expect(guide.state, GuideQuestionState.before);
    expect(guide.actionLabel, _ko.todayGuideCta);
    expect(_id(SlotIds.todayGuideQuestion), findsOneWidget);
    expect(_id(SlotIds.todayGuideCta), findsOneWidget);

    expect(find.byType(ShareButton), findsOneWidget);
    expect(find.text(_ko.noticeOffline), findsNothing);
    expect(find.byKey(const ValueKey('today.time-unknown')), findsNothing);
  });

  group('DS1 배치(D108, D112)', () {
    testWidgets('음력이 있으면 날짜 머리에 음력 칸(윤달 틀 포함)이 있습니다', (tester) async {
      await pumpApp(
        tester,
        scenario: 'member',
        overrides: [
          _dailyWith(
            (json) =>
                json['lunar'] = {'month': 9, 'day': 3, 'isLeapMonth': true},
          ),
        ],
      );
      await _settleToday(tester);
      expect(
        tester.widget<DateHeader>(_content).lunar,
        _ko.todayDateLunarLeap(9, 3),
      );
    });

    testWidgets('십성 묶음이 있으면 결정 태그가 둘이고, 누르면 그 묶음의 뜻 시트입니다', (tester) async {
      final sheets = _SheetLog();
      await pumpApp(
        tester,
        scenario: 'member',
        network: _GlossaryWith({
          'ten_god_group': {'siksang': '식상'},
        }),
        overrides: [
          _dailyWith((json) => json['dayStemTenGodGroup'] = 'siksang'),
          sheets.override,
        ],
      );
      await _settleToday(tester);

      final group = tester.widget<HanjaTag>(_tagIn(SlotIds.todayTenGodLabel));
      expect(group.glyph, '食');
      expect(group.label, '식상');
      expect(group.tone, HanjaTagTone.term);
      expect(group.variant, HanjaTagVariant.normal);
      // 같은 줄에 날의 성격 다음으로 놓입니다.
      expect(
        tester.getTopLeft(_tagIn(SlotIds.todayCharacterLabel)).dx,
        lessThan(tester.getTopLeft(_tagIn(SlotIds.todayTenGodLabel)).dx),
      );

      await tester.tap(_tagIn(SlotIds.todayTenGodLabel));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key(ScreenIds.explainSheet)), findsOneWidget);
      expect(
        (sheets.explained.last as ExplainTerm).termId,
        'ten_god_group.siksang',
      );
      expect((sheets.explainHeads.last! as HanjaTag).label, '식상');
    });

    testWidgets('사전에 십성 묶음 이름이 없으면 그 태그를 그리지 않고 사전 빈칸으로 남깁니다', (tester) async {
      final container = await pumpApp(
        tester,
        scenario: 'member',
        network: _GlossaryWith({'ten_god_group': {}}),
      );
      await _settleToday(tester);
      expect(
        find.byKey(const ValueKey(SlotIds.todayTenGodLabel)),
        findsNothing,
      );
      final reporter =
          container.read(crashReporterProvider) as FakeCrashReporter;
      expect(
        [
          for (final gap in reporter.errors)
            if (gap.errorType == 'MissingDictionaryEntry') gap.code,
        ],
        ['ten_god_group.bigyeop'],
      );
    });

    testWidgets('날의 성격 태그를 누르면 그 뜻 시트이고 머리는 같은 태그입니다', (tester) async {
      final sheets = _SheetLog();
      await pumpApp(tester, scenario: 'member', overrides: [sheets.override]);
      await _settleToday(tester);

      await tester.tap(_tagIn(SlotIds.todayCharacterLabel));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key(ScreenIds.explainSheet)), findsOneWidget);
      expect(
        (sheets.explained.last as ExplainTerm).termId,
        'day_kind.yongsin_day',
      );
      final head = sheets.explainHeads.last! as HanjaTag;
      expect(head.label, _ko.dayKindYongsinDay);
      expect(head.variant, HanjaTagVariant.emphasis);
      expect(head.onTap, isNull);
    });

    testWidgets('대표 태그가 없는 날(D112): 헤드라인만 두고 사주 기운에 안내 한 줄', (tester) async {
      await pumpApp(
        tester,
        scenario: 'member',
        overrides: [
          _dailyWith((json) {
            (json['tags'] as Map<String, dynamic>)['featured'] = <Object>[];
            (json['fortune'] as Map<String, dynamic>).remove('tag');
          }),
        ],
      );
      await _settleToday(tester);

      expect(_id(SlotIds.todayFortuneHead), findsOneWidget);
      expect(_tagIn(SlotIds.todayCharacterLabel), findsOneWidget);
      expect(find.byKey(TodayScreen.fortuneDividerKey), findsNothing);
      expect(
        find.byKey(const ValueKey(TodayScreen.bodyTagKeyValue)),
        findsNothing,
      );
      expect(_id(SlotIds.todayFortuneBody), findsNothing);

      // 사주 기운 섹션은 제목 그대로, 카드 안에 안내 한 줄이고 태그는 없습니다.
      expect(find.text(_ko.todayFeaturedTitle), findsOneWidget);
      expect(_featuredTags(), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(TodayScreen.featuredCardKey),
          matching: find.text(_ko.todayFeaturedEmpty),
        ),
        findsOneWidget,
      );
      expect(_id(SlotIds.todayFeaturedEmpty), findsOneWidget);
    });

    testWidgets('대표 태그가 있지만 하나도 그릴 수 없으면 D112가 아니라 사주 기운 섹션째 없고 보조 문장은 남습니다', (
      tester,
    ) async {
      await pumpApp(
        tester,
        scenario: 'member',
        overrides: [
          _dailyWith(
            (json) => (json['tags'] as Map<String, dynamic>)['featured'] = [
              {'key': 'not_in_table', 'polarity': 'neutral'},
            ],
          ),
        ],
      );
      await _settleToday(tester);

      expect(find.text(_ko.todayFeaturedEmpty), findsNothing);
      expect(find.text(_ko.todayFeaturedTitle), findsNothing);
      expect(find.byKey(TodayScreen.featuredCardKey), findsNothing);
      // 보조 문장과 선은 남고 그 위 태그 자리만 빕니다.
      expect(_id(SlotIds.todayFortuneBody), findsOneWidget);
      expect(find.byKey(TodayScreen.fortuneDividerKey), findsOneWidget);
      expect(
        find.byKey(const ValueKey(TodayScreen.bodyTagKeyValue)),
        findsNothing,
      );
      final link = find.descendant(
        of: find.byKey(const Key(SlotIds.todayFortuneBody)),
        matching: find.byType(DepthLink),
      );
      expect(tester.widget<DepthLink>(link).subject, _ko.todayFortuneTitle);
    });

    testWidgets('대표 태그가 둘이면 사주 기운에 둘, 보조 문장 위는 1순위입니다', (tester) async {
      await pumpApp(
        tester,
        scenario: 'member',
        overrides: [
          _dailyWith(
            (json) => (json['tags'] as Map<String, dynamic>)['featured'] = [
              {'key': 'cheoneul_gwiin', 'polarity': 'good'},
              {'key': 'harmony', 'polarity': 'good'},
              {'key': 'hwagae', 'polarity': 'neutral'},
            ],
          ),
        ],
      );
      await _settleToday(tester);
      expect(
        [
          for (final tag in tester.widgetList<HanjaTag>(_featuredTags()))
            tag.glyph,
        ],
        ['天', '合'],
      );
      expect(
        tester.widget<HanjaTag>(_tagIn(TodayScreen.bodyTagKeyValue)).glyph,
        '天',
      );
      // 바로 앞 "하나도 그릴 수 없는 날" 사례가 findsNothing으로 확인하는 같은 키가 대표 태그가 있는
      // 날에는 실제로 그려집니다. 키 이름이 바뀌어 그 사례가 공허하게 통과하는 것을 막습니다.
      expect(find.byKey(TodayScreen.featuredCardKey), findsOneWidget);
      expect(find.text(_ko.todayFeaturedTitle), findsOneWidget);
      expect(
        find.byKey(const ValueKey(TodayScreen.bodyTagKeyValue)),
        findsOneWidget,
      );
    });

    testWidgets('사주 기운 태그를 누르면 사주 기운 시트이고 열린 동안 selected입니다', (tester) async {
      final sheets = _SheetLog();
      await pumpApp(
        tester,
        scenario: 'member',
        overrides: [
          _dailyWith(
            (json) => (json['tags'] as Map<String, dynamic>)['featured'] = [
              {'key': 'cheoneul_gwiin', 'polarity': 'good'},
              {'key': 'harmony', 'polarity': 'good'},
            ],
          ),
          sheets.override,
        ],
      );
      await _settleToday(tester);

      final second = _featuredTags().at(1);
      await tester.ensureVisible(second);
      await tester.pumpAndSettle();
      await tester.tap(second);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key(ScreenIds.tagSheet)), findsOneWidget);
      expect(sheets.tagRanks, [1]);
      List<HanjaTagVariant> featuredVariants() => [
        for (final tag in tester.widgetList<HanjaTag>(_featuredTags()))
          tag.variant,
      ];
      expect(featuredVariants(), [
        HanjaTagVariant.normal,
        HanjaTagVariant.selected,
      ]);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key(ScreenIds.tagSheet)), findsNothing);
      expect(featuredVariants(), [
        HanjaTagVariant.normal,
        HanjaTagVariant.normal,
      ]);

      // 보조 문장 위 태그는 1순위 시트를 엽니다.
      final bodyTag = _tagIn(TodayScreen.bodyTagKeyValue);
      await tester.ensureVisible(bodyTag);
      await tester.pumpAndSettle();
      await tester.tap(bodyTag);
      await tester.pumpAndSettle();
      expect(sheets.tagRanks, [1, 0]);
      expect(
        tester.widget<HanjaTag>(_tagIn(TodayScreen.bodyTagKeyValue)).variant,
        HanjaTagVariant.selected,
      );
    });

    testWidgets('행운 칩은 행운 섹션 카드 안에 있고 누르면 그 칩 설명 시트입니다', (tester) async {
      final sheets = _SheetLog();
      await pumpApp(tester, scenario: 'member', overrides: [sheets.override]);
      await _settleToday(tester);

      final number = find.byKey(LuckyCardRow.chipKey(LuckyCardVariant.number));
      await tester.ensureVisible(number);
      await tester.pumpAndSettle();
      await tester.tap(number);
      await tester.pumpAndSettle();
      final lucky = sheets.explained.last as ExplainLucky;
      expect(lucky.title, _ko.todayLuckyNumberName);
      final daily = Daily.fromJson(memberDailyJson());
      expect(lucky.body.toJson(), daily.cards.number.text.text.toJson());
    });
  });

  testWidgets('행운 칩을 누르면 설명이 칩 아래가 아니라 풀이 시트로 열립니다', (tester) async {
    await pumpApp(tester, scenario: 'member');
    await _settleToday(tester);

    await tester.ensureVisible(
      find.byKey(LuckyCardRow.chipKey(LuckyCardVariant.color)),
    );
    await tester.tap(find.byKey(LuckyCardRow.chipKey(LuckyCardVariant.color)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key(ScreenIds.explainSheet)), findsOneWidget);
    // 시트 제목은 항목 이름이고 본문은 행운 색 설명입니다.
    expect(find.text(_ko.todayLuckyColorName), findsWidgets);
    expect(find.text('오늘은 초록이 잘 맞아요.', findRichText: true), findsOneWidget);
  });

  group('대표 태그 사전 빈칸(D76)', () {
    testWidgets('사전에 이름이 없는 태그는 사전 빈칸으로 한 번만 보고합니다', (tester) async {
      final json = memberDailyJson();
      (json['tags'] as Map<String, dynamic>)['featured'] = [
        {'key': 'not_in_glossary', 'polarity': 'neutral'},
        {'key': 'cheoneul_gwiin', 'polarity': 'good'},
      ];
      final container = await pumpApp(
        tester,
        scenario: 'member',
        overrides: [
          dailyControllerProvider.overrideWith(
            () => _StubDaily(
              () async => DailyView(
                date: _today,
                daily: Daily.fromJson(json),
                stale: false,
                cacheKey: null,
              ),
            ),
          ),
        ],
      );
      await _settleToday(tester);
      // 다시 그려도(다른 탭에 다녀옴) 같은 빈칸은 한 번만 남습니다.
      await tester.tap(find.byKey(const ValueKey('tab-bar.tab.1')));
      await settleWithIo(tester);
      await tester.tap(find.byKey(const ValueKey('tab-bar.tab.0')));
      await _settleToday(tester);

      final reporter =
          container.read(crashReporterProvider) as FakeCrashReporter;
      final gaps = reporter.errors.where(
        (summary) => summary.errorType == 'MissingDictionaryEntry',
      );
      expect([for (final gap in gaps) gap.code], ['tag.not_in_glossary']);
    });
  });

  group('오늘 일기 입구와 줄(D83)', () {
    GuideQuestionCard guideOf(WidgetTester tester) =>
        tester.widget<GuideQuestionCard>(find.byType(GuideQuestionCard));

    testWidgets('0편: 일기 쓰기, 일기 줄 없음', (tester) async {
      await pumpApp(tester, scenario: 'member');
      await _settleToday(tester);
      final guide = guideOf(tester);
      expect(guide.state, GuideQuestionState.before);
      expect(guide.actionLabel, _ko.todayGuideCta);
      expect(guide.onAction, isNotNull);
      expect(find.byType(DiaryEntryLine), findsNothing);
      expect(find.byKey(DiaryEntries.cardKey), findsNothing);
    });

    testWidgets('2편: 새 일기 쓰기와 작성 순 줄 2개, 첫 줄은 그 일기 보기', (tester) async {
      final container = await pumpApp(
        tester,
        scenario: 'member',
        overrides: [
          diariesOnProvider.overrideWith(
            (ref, date) async => [
              for (final i in [1, 2])
                DiarySummary(
                  id: 'today-$i',
                  date: date.toIso(),
                  createdAt: DateTime.utc(2026, 10, 13, 9, i),
                  excerpt: '오늘 $i번째 일기',
                  featuredTags: const [],
                ),
            ],
          ),
        ],
      );
      await _settleToday(tester);
      final guide = guideOf(tester);
      expect(guide.state, GuideQuestionState.after);
      expect(guide.actionLabel, _ko.todayGuideCtaWritten);
      final lines = tester
          .widgetList<DiaryEntryLine>(find.byType(DiaryEntryLine))
          .toList();
      expect(
        [for (final line in lines) line.excerpt],
        ['오늘 1번째 일기', '오늘 2번째 일기'],
      );
      // 줄은 가이드 질문 카드 아래, 오늘 바탕 카드 안입니다.
      expect(
        tester.getTopLeft(find.byKey(DiaryEntries.cardKey)).dy,
        greaterThan(tester.getBottomLeft(find.byType(GuideQuestionCard)).dy),
      );
      expect(
        find.descendant(
          of: find.byKey(DiaryEntries.cardKey),
          matching: find.byType(DiaryEntryLine),
        ),
        findsNWidgets(2),
      );
      // 날짜 열·대표 태그 없이 줄만 있습니다.
      expect(find.byType(DiaryRow), findsNothing);

      await tester.ensureVisible(find.byType(DiaryEntryLine).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DiaryEntryLine).first);
      await pumpUntil(
        tester,
        () => find
            .byKey(const ValueKey(ScreenIds.diaryView))
            .evaluate()
            .isNotEmpty,
      );
      expect(
        container.read(routerProvider).state.uri.toString(),
        '/diary-view?id=today-1',
      );
      await settleWithIo(tester);
    });

    testWidgets('diary-day-full: 다 채웠다는 문구, 버튼이 꺼져 눌러도 그대로', (tester) async {
      final container = await pumpApp(tester, scenario: 'diary-day-full');
      await _settleToday(tester);
      final guide = guideOf(tester);
      expect(guide.state, GuideQuestionState.full);
      expect(guide.actionLabel, _ko.todayGuideCtaFull);
      expect(find.byType(DiaryEntryLine), findsNWidgets(10));

      await tester.ensureVisible(find.byKey(GuideQuestionCard.buttonKey));
      await tester.pumpAndSettle();
      // brief가 "누르면 아무 이동 없음"까지 요구해 실제로 눌러 봅니다. 꺼진 버튼은 누름을 받지
      // 않을 수 있어 hit 경고를 끄고, 결과는 아래 경로로 단언합니다.
      await tester.tap(
        find.byKey(GuideQuestionCard.buttonKey),
        warnIfMissed: false,
      );
      await settleWithIo(tester);
      expect(
        container.read(routerProvider).state.uri.toString(),
        pathOf(ScreenIds.today),
      );
    });

    testWidgets('일기 줄에는 대표 태그이 없고, 누르면 그 일기 보기입니다', (tester) async {
      final container = await pumpApp(tester, scenario: 'diary-written');
      await _settleToday(tester);
      final line = find.descendant(
        of: find.byKey(DiaryEntries.cardKey),
        matching: find.byType(DiaryEntryLine),
      );
      await pumpUntil(tester, () => line.evaluate().isNotEmpty);
      expect(
        find.descendant(
          of: find.byKey(DiaryEntries.cardKey),
          matching: find.byType(HanjaTag),
        ),
        findsNothing,
      );

      await tester.ensureVisible(line);
      await tester.pumpAndSettle();
      await tester.tap(line);
      await settleWithIo(tester);
      expect(find.byKey(const ValueKey(ScreenIds.tagDiary)), findsNothing);
      expect(
        container.read(routerProvider).state.uri.toString(),
        '/diary-view?id=7b1c2a54-3d0e-4f6a-9b21-5e8f40c1a005',
      );
    });

    testWidgets('목록을 받지 못하면 0편으로: 일기 쓰기, 줄 없음', (tester) async {
      await pumpApp(
        tester,
        scenario: 'diary-written',
        network: _FailDiaryList(),
      );
      await _settleToday(tester);
      final guide = guideOf(tester);
      expect(guide.state, GuideQuestionState.before);
      expect(guide.actionLabel, _ko.todayGuideCta);
      expect(find.byType(DiaryEntryLine), findsNothing);
    });
  });

  testWidgets('loading: 응답 전에는 카드 자리 skeleton입니다', (tester) async {
    final never = Completer<DailyView>();
    await pumpApp(
      tester,
      scenario: 'member',
      // 응답을 끝까지 붙잡아 skeleton이 계속 숨 쉽니다.
      allowOngoing: true,
      overrides: [
        dailyControllerProvider.overrideWith(
          () => _StubDaily(() => never.future),
        ),
      ],
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(_loading, findsOneWidget);
    expect(find.byKey(TodayScreen.skeletonKey), findsOneWidget);
    expect(_content, findsNothing);
    // 내용이 없을 때는 공유할 것이 없어 공유 버튼도 없습니다.
    expect(find.byType(ShareButton), findsNothing);
  });

  testWidgets('daily-error: 오류 화면과 다시 시도 → 다시 받기', (tester) async {
    final container = await pumpApp(tester, scenario: 'daily-error');
    await _settleToday(tester);
    final error = tester.widget<ErrorState>(find.byType(ErrorState));
    expect(error.variant, ErrorStateVariant.generic);
    expect(_content, findsNothing);
    final before = _fake(container).callCountOf('getDaily');

    await tester.tap(find.text(_ko.actionRetry));
    await tester.pump();
    await _settleToday(tester);
    expect(_fake(container).callCountOf('getDaily'), before + 1);
    expect(find.byType(ErrorState), findsOneWidget);
  });

  testWidgets('offline(캐시 없음): 오프라인 오류 화면입니다', (tester) async {
    await pumpApp(
      tester,
      scenario: 'member',
      overrides: [
        dailyControllerProvider.overrideWith(
          () => _StubDaily(() async => throw const OfflineError()),
        ),
      ],
    );
    await _settleToday(tester);
    final error = tester.widget<ErrorState>(find.byType(ErrorState));
    expect(error.variant, ErrorStateVariant.offline);
    expect(_content, findsNothing);
  });

  testWidgets('offline(캐시 있음): 내용과 오프라인 배너입니다', (tester) async {
    await pumpApp(
      tester,
      scenario: 'member',
      overrides: [
        dailyControllerProvider.overrideWith(
          () => _StubDaily(() async => _view(stale: true)),
        ),
      ],
    );
    await _settleToday(tester);
    expect(_content, findsOneWidget);
    final banner = tester.widget<NoticeBanner>(
      find.byWidgetPredicate(
        (w) => w is NoticeBanner && w.variant == NoticeBannerVariant.offline,
      ),
    );
    expect(banner.variant, NoticeBannerVariant.offline);
    expect(banner.present, isTrue);
    expect(find.text(_ko.noticeOffline), findsOneWidget);
  });

  testWidgets('member-time-unknown: 시간 모름 배너', (tester) async {
    await pumpApp(tester, scenario: 'member-time-unknown');
    await _settleToday(tester);
    final banner = tester.widget<NoticeBanner>(
      find.byWidgetPredicate(
        (w) =>
            w is NoticeBanner && w.variant == NoticeBannerVariant.timeUnknown,
      ),
    );
    // 문구는 사주 표와 같은 키입니다(IA today time-unknown, DS1).
    expect(banner.message, _ko.sajuChartTimeUnknownNotice);
    expect(_content, findsOneWidget);
    // 날짜 머리 아래, 첫 섹션 위에 놓입니다.
    final bannerTop = tester.getTopLeft(find.byWidget(banner)).dy;
    expect(tester.getBottomLeft(_content).dy, lessThan(bannerTop));
    expect(
      bannerTop,
      lessThan(tester.getTopLeft(find.byType(SectionHeader).first).dy),
    );
  });

  testWidgets('화면을 연 채 자정을 넘기면 어제 풀이를 감추고 새 날짜 응답을 보입니다', (tester) async {
    final container = await pumpApp(
      tester,
      scenario: 'member',
      overrides: [
        todayProvider.overrideWith((ref) => ref.watch(_testTodayProvider)),
      ],
    );
    await _settleToday(tester);
    expect(container.read(dailyControllerProvider).value?.date, _today);

    final hold = _DailyHold()..hold = Completer<void>();
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, hold);

    final tomorrow = CalendarDate(2026, 10, 14);
    container.read(_testTodayProvider.notifier).moveTo(tomorrow);
    await pumpUntil(tester, () => hold.paths.isNotEmpty, allowOngoing: true);
    await tester.pump(const Duration(milliseconds: 400));
    // 다시 받는 동안 controller에는 어제 값이 남아 있지만 화면은 "오늘"로 보이지 않습니다.
    expect(container.read(dailyControllerProvider).value?.date, _today);
    expect(_loading, findsOneWidget);
    expect(_content, findsNothing);

    hold.hold!.complete();
    await _settleToday(tester);
    expect(hold.paths, ['/v1/daily/2026-10-14']);
    expect(container.read(dailyControllerProvider).value?.date, tomorrow);
    expect(_content, findsOneWidget);
  });

  for (final scale in [2.0, 3.0]) {
    testWidgets('글자 $scale배·320폭에서도 넘치지 않습니다', (tester) async {
      tester.view
        ..physicalSize = const Size(320, 568)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final never = Completer<DailyView>();
      final container = await pumpApp(
        tester,
        scenario: 'member',
        allowOngoing: true,
        overrides: [
          dailyControllerProvider.overrideWith(
            () => _StubDaily(() => never.future),
          ),
        ],
      );
      // 불러오는 중 skeleton도 넘치지 않습니다.
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(TodayScreen.skeletonKey), findsOneWidget);
      expect(tester.takeException(), isNull);

      never.complete(_view());
      await _settleToday(tester);
      expect(tester.takeException(), isNull);
      expect(_content, findsOneWidget);
      expect(container.read(dailyControllerProvider).hasValue, isTrue);
    });
  }

  // 화면 값(TodayDisplay)의 동등성이 다시 스밀지 정합니다. 반응 가능 여부처럼 화면 값에 새로
  // 담긴 필드도 따로 고치지 않고 따라옵니다.
  for (final (name, change, changed)
      in <(String, void Function(Map<String, dynamic> json), bool)>[
        (
          '보이는 내용이 같은 server 응답이면 내용이 움직이지 않습니다',
          // 보이지 않는 필드만 바뀐 응답(근거 잠금 해제)은 같은 내용으로 봅니다.
          (json) => json['evidenceAccess'] = 'unlocked',
          false,
        ),
        (
          '캐시와 다른 server 응답(날의 성격)으로 바뀌면 내용이 스밉니다',
          (json) => json['dayKind'] = 'ordinary_day',
          true,
        ),
        (
          '총운 첫 문장의 반응 가능 여부가 바뀌어도 내용이 스밉니다',
          (json) =>
              ((json['fortune'] as Map<String, dynamic>)['head']
                      as Map<String, dynamic>)['reactable'] =
                  false,
          true,
        ),
      ]) {
    testWidgets(name, (tester) async {
      final server = Completer<DailyView>();
      final container = await pumpApp(
        tester,
        scenario: 'member',
        overrides: [
          dailyControllerProvider.overrideWith(
            () => _CacheThenServer(_view(), server.future),
          ),
        ],
      );
      await _settleToday(tester);
      double opacity() => tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: _tagIn(SlotIds.todayCharacterLabel),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      expect(opacity(), 1);

      final json = memberDailyJson();
      change(json);
      final expectedTone = Daily.fromJson(json).dayKind == DayKind.yongsinDay
          ? HanjaTagTone.yongsin
          : HanjaTagTone.ordinary;
      server.complete(
        DailyView(
          date: _today,
          daily: Daily.fromJson(json),
          stale: false,
          cacheKey: null,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(
        opacity(),
        changed ? lessThan(1) : 1,
        reason: changed ? '다른 내용은 스밉니다' : '같은 내용은 그대로입니다',
      );
      await tester.pumpAndSettle();
      expect(opacity(), 1);
      expect(
        tester.widget<HanjaTag>(_tagIn(SlotIds.todayCharacterLabel)).tone,
        expectedTone,
      );
      expect(container.read(dailyControllerProvider).isLoading, isFalse);
    });
  }

  for (final reduceMotion in [false, true]) {
    testWidgets(
      reduceMotion
          ? '동작 줄이기면 공유 버튼이 흐림 없이 투명도로만 나타납니다'
          : '내용이 도착하면 앱 바 공유 버튼이 appear.seep으로 나타납니다',
      (tester) async {
        if (reduceMotion) {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
        }
        final server = Completer<DailyView>();
        await pumpApp(
          tester,
          scenario: 'member',
          allowOngoing: true,
          overrides: [
            dailyControllerProvider.overrideWith(
              () => _StubDaily(() => server.future),
            ),
          ],
        );
        expect(find.byType(ShareButton), findsNothing);

        server.complete(_view());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        final share = find.byType(ShareButton);
        expect(share, findsOneWidget);
        double opacity() => tester
            .widget<Opacity>(
              find.ancestor(of: share, matching: find.byType(Opacity)).first,
            )
            .opacity;
        expect(opacity(), lessThan(1));
        final blurred = find.ancestor(
          of: share,
          matching: find.byWidgetPredicate(
            (w) => w is ImageFiltered && w.enabled,
          ),
        );
        expect(blurred, reduceMotion ? findsNothing : findsOneWidget);

        await tester.pumpAndSettle();
        expect(opacity(), 1);
      },
    );
  }

  group('총운 반응', () {
    List<String> recordHaptics(WidgetTester tester) {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            calls.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      return calls;
    }

    ReactionButton button(WidgetTester tester) =>
        tester.widget<ReactionButton>(find.byType(ReactionButton));

    testWidgets('reactable인 총운 첫 문장에만 버튼이 있고 라벨은 좋아요입니다', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(tester, scenario: 'member');
      await _settleToday(tester);

      expect(find.byType(ReactionButton), findsOneWidget);
      expect(button(tester).on, isFalse);
      expect(button(tester).semanticsLabel, _ko.todayReactionLabel);
      final node = tester.getSemantics(_id(SlotIds.todayReactionLabel));
      expect(node.label, _ko.todayReactionLabel);
      expect(node.flagsCollection.isToggled, Tristate.isFalse);
      expect(
        find.byKey(const ValueKey(SlotIds.todayReactionLabel)),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('누르면 바로 켜지고 라벨이 바뀌며 PUT이 한 번 갑니다', (tester) async {
      final semantics = tester.ensureSemantics();
      final haptics = recordHaptics(tester);
      final container = await pumpApp(tester, scenario: 'member');
      await _settleToday(tester);

      await tester.tap(find.byKey(ReactionButton.targetKey));
      await tester.pump();
      // 응답 전에 이미 켜져 있습니다.
      expect(button(tester).on, isTrue);
      expect(button(tester).semanticsLabel, _ko.todayReactionLabelSelected);
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      await pumpUntil(
        tester,
        () => _fake(container).callCountOf('putReaction') == 1,
      );

      final node = tester.getSemantics(_id(SlotIds.todayReactionLabel));
      expect(node.label, _ko.todayReactionLabelSelected);
      expect(node.flagsCollection.isToggled, Tristate.isTrue);
      expect(button(tester).on, isTrue);
      semantics.dispose();
    });

    testWidgets('실패하면 되돌리고 toast를 보이며 햅틱을 다시 내지 않습니다', (tester) async {
      final semantics = tester.ensureSemantics();
      final haptics = recordHaptics(tester);
      final container = await pumpApp(tester, scenario: 'reaction-failed');
      await _settleToday(tester);

      await tester.tap(find.byKey(ReactionButton.targetKey));
      await tester.pump();
      expect(button(tester).on, isTrue);
      await pumpUntil(
        tester,
        () => find.byType(ToastPill).evaluate().isNotEmpty,
      );

      expect(find.byType(ToastPill), findsOneWidget);
      expect(find.text(_ko.errorServiceUnavailable), findsOneWidget);
      expect(_fake(container).callCountOf('putReaction'), 1);
      expect(button(tester).on, isFalse);
      expect(button(tester).semanticsLabel, _ko.todayReactionLabel);
      expect(
        tester
            .getSemantics(_id(SlotIds.todayReactionLabel))
            .flagsCollection
            .isToggled,
        Tristate.isFalse,
      );
      // 켤 때 낸 햅틱 하나뿐입니다. 되돌릴 때는 내지 않습니다.
      expect(haptics, ['HapticFeedbackType.lightImpact']);
      // toast가 사라지는 시간을 흘려 보냅니다.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
      semantics.dispose();
    });
  });

  group('#234 draft.5', () {
    testWidgets(
      'putReaction 404 reaction.not_found면 켠 반응이 되돌아가고 오류 toast가 뜹니다',
      (tester) async {
        final container = await pumpApp(tester, scenario: 'member');
        await _settleToday(tester);
        final interceptors = container.read(dioProvider).interceptors;
        interceptors.insert(
          interceptors.length - 1,
          ReactionNotFoundInterceptor(),
        );

        await tester.tap(find.byKey(ReactionButton.targetKey));
        await tester.pump();
        await pumpUntil(
          tester,
          () => find.byType(ToastPill).evaluate().isNotEmpty,
        );

        expect(find.text(_ko.errorReactionNotFound), findsOneWidget);
        expect(
          tester.widget<ReactionButton>(find.byType(ReactionButton)).on,
          isFalse,
        );
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets('time_unknown notice의 문장이 비어 있어도 ARB 안내 배너를 그립니다', (
      tester,
    ) async {
      await pumpApp(
        tester,
        scenario: 'member',
        overrides: [
          _dailyWith(
            (json) => json['notices'] = [
              {
                'code': 'time_unknown',
                'text': {'segments': <Object>[]},
              },
            ],
          ),
        ],
      );
      await _settleToday(tester);
      expect(
        tester
            .widget<NoticeBanner>(
              find.byWidgetPredicate(
                (w) =>
                    w is NoticeBanner &&
                    w.variant == NoticeBannerVariant.timeUnknown,
              ),
            )
            .message,
        _ko.sajuChartTimeUnknownNotice,
      );
    });

    testWidgets('보조 문장이 빈 segments면 선, 1순위 태그, 보조 문장을 그리지 않습니다', (
      tester,
    ) async {
      final json = memberDailyJson();
      final fortune = json['fortune']! as Map<String, dynamic>;
      final tag = fortune['tag']! as Map<String, dynamic>;
      tag['text'] = {
        'segments': [
          {'text': ' '},
        ],
      };
      await pumpApp(
        tester,
        scenario: 'member',
        overrides: [
          dailyControllerProvider.overrideWith(
            () => _StubDaily(
              () async => DailyView(
                date: _today,
                daily: Daily.fromJson(json),
                stale: false,
                cacheKey: null,
              ),
            ),
          ),
        ],
      );
      await _settleToday(tester);

      expect(_id(SlotIds.todayFortuneBody), findsNothing);
      expect(find.byKey(TodayScreen.fortuneDividerKey), findsNothing);
      expect(
        find.byKey(const ValueKey(TodayScreen.bodyTagKeyValue)),
        findsNothing,
      );
      expect(_id(SlotIds.todayFortuneHead), findsOneWidget);
      // 사주 기운 섹션의 대표 태그(합, 비겁이 많은 날)는 그대로입니다.
      expect(_featuredTags(), findsNWidgets(2));
    });

    testWidgets('총운 문장이 빈 segments면 문장 자리를 그리지 않습니다', (tester) async {
      final json = memberDailyJson();
      final fortune = json['fortune']! as Map<String, dynamic>;
      final head = fortune['head']! as Map<String, dynamic>;
      head['text'] = {'segments': <Object>[]};
      await pumpApp(
        tester,
        scenario: 'member',
        overrides: [
          dailyControllerProvider.overrideWith(
            () => _StubDaily(
              () async => DailyView(
                date: _today,
                daily: Daily.fromJson(json),
                stale: false,
                cacheKey: null,
              ),
            ),
          ),
        ],
      );
      await _settleToday(tester);

      expect(_id(SlotIds.todayFortuneHead), findsNothing);
      expect(find.byType(ReactionButton), findsNothing);
      expect(_id(SlotIds.todayFortuneBody), findsOneWidget);
    });
  });

  group('오늘 일정 한 줄(A35)', () {
    Finder summaryRow() => _id(SlotIds.todayEventSummary);

    EventRow row(WidgetTester tester) =>
        tester.widget<EventRow>(find.byType(EventRow));

    /// 오늘 내용과 일정 줄이 보일 때까지 기다립니다.
    Future<void> settleSummary(WidgetTester tester) async {
      await _settleToday(tester);
      await pumpUntil(tester, () => summaryRow().evaluate().isNotEmpty);
    }

    testWidgets('member: 일정 섹션(제목과 "다음" 일정 한 줄)이 행운과 오늘의 질문 사이에 있습니다(A114)', (
      tester,
    ) async {
      await pumpApp(tester, scenario: 'member');
      await settleSummary(tester);

      // fake 시계는 정오입니다: 09:07은 지났고 19:00 요가 수업이 다음, 나머지 2개.
      expect(summaryRow(), findsOneWidget);
      expect(row(tester).variant, EventRowVariant.summary);
      expect(row(tester).status, EventRowStatus.next);
      expect(row(tester).time, '19:00');
      expect(row(tester).title, '요가 수업');
      expect(row(tester).moreCount, 2);
      expect(row(tester).identifier, SlotIds.todayEventSummary);
      expect(row(tester).onTap, isNotNull);

      final title = find.text(_ko.todayEventTitle);
      expect(title, findsOneWidget);
      expect(_id(SlotIds.todayEventTitle), findsOneWidget);
      final rowTop = tester.getTopLeft(find.byType(EventRow)).dy;
      expect(
        tester.getBottomLeft(find.byType(LuckyCardRow)).dy,
        lessThan(tester.getTopLeft(title).dy),
      );
      expect(tester.getBottomLeft(title).dy, lessThanOrEqualTo(rowTop));
      expect(
        tester.getBottomLeft(find.byType(EventRow)).dy,
        lessThan(tester.getTopLeft(find.text(_ko.todayGuideTitle)).dy),
      );
    });

    testWidgets('화면을 열 때 이미 받아 둔 요약은 첫 프레임부터 스미지 않고 다 보입니다', (tester) async {
      final daily = Completer<DailyView>();
      final container = await pumpApp(
        tester,
        scenario: 'member',
        allowOngoing: true,
        overrides: [
          dailyControllerProvider.overrideWith(
            () => _StubDaily(() => daily.future),
          ),
        ],
      );
      // 오늘 내용을 붙잡아 둔 사이에 일정 요약을 먼저 받아 둡니다.
      final held = container.listen(todayScheduleSummaryProvider, (_, _) {});
      addTearDown(held.close);
      await pumpUntil(
        tester,
        () => container.read(todayScheduleSummaryProvider) != null,
        allowOngoing: true,
      );

      daily.complete(_view());
      final presence = find.byKey(const ValueKey(SlotIds.todayEventSummary));
      for (var i = 0; i < 20 && presence.evaluate().isEmpty; i++) {
        await tester.pump();
      }
      expect(presence, findsOneWidget);
      // 줄이 처음 그려진 프레임에 seep 투명도가 이미 끝(1)입니다.
      final opacity = tester.widget<Opacity>(
        find.descendant(of: presence, matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, 1);
    });

    testWidgets('일정을 불러오지 못하면(503) 줄이 없고 today와 toast는 그대로입니다', (tester) async {
      final daily = Completer<DailyView>();
      final container = await pumpApp(
        tester,
        scenario: 'member',
        allowOngoing: true,
        overrides: [
          dailyControllerProvider.overrideWith(
            () => _StubDaily(() => daily.future),
          ),
        ],
      );
      // 줄은 오늘 내용 안에 있으므로 내용이 오기 전에 끼우면 첫 일정 요청부터 실패합니다.
      final unavailable = _SchedulesUnavailable();
      final interceptors = container.read(dioProvider).interceptors;
      interceptors.insert(interceptors.length - 1, unavailable);

      daily.complete(_view());
      await _settleToday(tester);
      await pumpUntil(tester, () => unavailable.calls > 0);
      await tester.pump(const Duration(milliseconds: 400));

      expect(summaryRow(), findsNothing);
      expect(find.byType(EventRow), findsNothing);
      expect(find.byType(ErrorState), findsNothing);
      expect(find.byType(ToastPill), findsNothing);
      expect(_content, findsOneWidget);
      expect(find.byType(LuckyCardRow), findsOneWidget);
      expect(find.byType(GuideQuestionCard), findsOneWidget);
    });

    testWidgets('분이 지나면 "다음"이 바뀝니다', (tester) async {
      final minutes = StreamController<DateTime>.broadcast();
      addTearDown(minutes.close);
      await pumpApp(
        tester,
        scenario: 'member',
        overrides: [nowMinuteProvider.overrideWith((ref) => minutes.stream)],
      );
      minutes.add(DateTime.utc(2026, 10, 13, 9, 7));
      await settleSummary(tester);
      // 같은 분의 일정은 아직 "다음"입니다.
      expect(row(tester).status, EventRowStatus.next);
      expect(row(tester).title, '팀 주간 회의');
      expect(row(tester).time, '09:07');

      minutes.add(DateTime.utc(2026, 10, 13, 9, 8));
      await pumpUntil(tester, () => row(tester).title != '팀 주간 회의');
      expect(row(tester).status, EventRowStatus.next);
      expect(row(tester).title, '요가 수업');
      expect(row(tester).time, '19:00');

      // 시각 일정이 모두 지나면 하루 종일 일정이 "진행 중"입니다.
      minutes.add(DateTime.utc(2026, 10, 13, 19, 1));
      await pumpUntil(tester, () => row(tester).title != '요가 수업');
      expect(row(tester).status, EventRowStatus.inProgress);
      expect(row(tester).time, isNull);
      expect(row(tester).title, '엄마 생신');
    });

    testWidgets('모두 지난 요약은 개수 문장 한 줄입니다', (tester) async {
      await pumpApp(
        tester,
        scenario: 'member',
        overrides: [
          todayScheduleSummaryProvider.overrideWith(
            (ref) => const TodayScheduleAllPast(count: 3),
          ),
        ],
      );
      await settleSummary(tester);
      expect(row(tester).allPastSentence, _ko.todayEventSummaryAllPast(3));
      expect(row(tester).status, isNull);
      expect(row(tester).identifier, SlotIds.todayEventSummary);
    });

    testWidgets('요약이 null이면 줄이 없고 나머지 today는 그대로입니다', (tester) async {
      await pumpApp(
        tester,
        scenario: 'member',
        overrides: [todayScheduleSummaryProvider.overrideWith((ref) => null)],
      );
      await _settleToday(tester);
      expect(summaryRow(), findsNothing);
      expect(find.byType(EventRow), findsNothing);
      // 일정이 없는 날은 섹션째 없습니다(A114).
      expect(find.text(_ko.todayEventTitle), findsNothing);
      expect(_content, findsOneWidget);
      expect(find.byType(LuckyCardRow), findsOneWidget);
      expect(find.byType(GuideQuestionCard), findsOneWidget);
    });
  });
}

/// `/v1/schedules`에 503으로 답합니다.
final class _SchedulesUnavailable extends Interceptor {
  int calls = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!options.path.startsWith('/v1/schedules')) {
      handler.next(options);
      return;
    }
    calls++;
    handler.reject(
      DioException.badResponse(
        statusCode: 503,
        requestOptions: options,
        response: Response<Object?>(requestOptions: options, statusCode: 503),
      ),
      true,
    );
  }
}
