import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/gen/model/daily.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/design/components/action/share_button.dart';
import 'package:myungli_diary/design/components/calendar/event_row.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/reaction_button.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/components/today/day_reading_skeleton.dart';
import 'package:myungli_diary/design/components/today/guide_question_card.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/schedule/application/schedule_providers.dart';
import 'package:myungli_diary/features/schedule/model/today_schedule_summary.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';

import '../../support/app_harness.dart';
import '../../support/daily_fixture.dart';
import '../../support/onboarding_steps.dart' show pumpUntil;
import '../../support/reaction_not_found.dart';

final _ko = AppLocalizationsKo();
final _today = CalendarDate(2026, 10, 13);

Finder _id(String identifier) => find.bySemanticsIdentifier(identifier);

FakeServerInterceptor _fake(ProviderContainer container) =>
    container.read(fakeServerInterceptorProvider)! as FakeServerInterceptor;

final Finder _content = find.byType(DayCharacter);
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

/// 손으로 바꾸는 "오늘". 화면이 열린 채 자정을 넘기는 것을 흉내 냅니다.
final class _TestToday extends Notifier<CalendarDate> {
  @override
  CalendarDate build() => _today;

  CalendarDate get date => state;

  set date(CalendarDate value) => state = value;
}

final _testTodayProvider = NotifierProvider<_TestToday, CalendarDate>(
  _TestToday.new,
);

void main() {
  setUpAll(ensureTimeZonesInitialized);

  testWidgets('member: 용신의 날 배지와 이유 줄, 총운 두 문장, 행운 칩 4개, 가이드 before', (
    tester,
  ) async {
    await pumpApp(tester, scenario: 'member');
    await _settleToday(tester);

    expect(find.byKey(const ValueKey(ScreenIds.today)), findsOneWidget);
    expect(_id(ScreenIds.today), findsOneWidget);
    final character = tester.widget<DayCharacter>(_content);
    expect(character.variant, DayCharacterVariant.good);
    expect(character.label, _ko.dayKindYongsinDay);
    expect(
      character.reason?.segments.single.text,
      '내게 필요한 기운이 들어와 일이 잘 풀리기 쉬운 날이에요.',
    );
    expect(_id(SlotIds.todayCharacterLabel), findsOneWidget);
    expect(_id(SlotIds.todayCharacterReason), findsOneWidget);

    expect(_id(SlotIds.todayFortuneHead), findsOneWidget);
    expect(_id(SlotIds.todayFortuneBody), findsOneWidget);
    // 근거 보기 링크는 총운 끝과 날의 성격 이유 줄 끝(`day-character` rules)에 있습니다.
    for (final scope in [
      find.byKey(const Key(SlotIds.todayFortuneHead)),
      find.byKey(DayCharacter.reasonKey),
    ]) {
      final link = find.descendant(of: scope, matching: find.byType(DepthLink));
      expect(
        tester.widget<DepthLink>(link).variant,
        DepthLinkVariant.inlineEnd,
      );
      expect(tester.widget<DepthLink>(link).label, _ko.depthLinkEvidence);
    }

    for (final variant in [
      LuckyCardVariant.color,
      LuckyCardVariant.direction,
      LuckyCardVariant.number,
      LuckyCardVariant.time,
    ]) {
      expect(find.byKey(LuckyCardRow.chipKey(variant)), findsOneWidget);
    }
    expect(find.text('초록'), findsOneWidget);
    expect(find.text(_ko.direction8E), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('09:30–11:30'), findsOneWidget);

    final guide = tester.widget<GuideQuestionCard>(
      find.byType(GuideQuestionCard),
    );
    expect(guide.state, GuideQuestionState.before);
    expect(guide.actionLabel, _ko.todayGuideCta);
    expect(_id(SlotIds.todayGuideQuestion), findsOneWidget);
    expect(_id(SlotIds.todayGuideCta), findsOneWidget);

    expect(find.byType(ShareButton), findsOneWidget);
    expect(find.text(_ko.noticeOffline), findsNothing);
    expect(find.byKey(const ValueKey('today.time-unknown')), findsNothing);
  });

  testWidgets('행운 칩을 누르면 설명에 슬롯 id가 붙습니다', (tester) async {
    await pumpApp(tester, scenario: 'member');
    await _settleToday(tester);

    const slots = {
      LuckyCardVariant.color: SlotIds.todayLuckyColorBody,
      LuckyCardVariant.direction: SlotIds.todayLuckyDirectionBody,
      LuckyCardVariant.number: SlotIds.todayLuckyNumberBody,
      LuckyCardVariant.time: SlotIds.todayLuckyTimeBody,
    };
    for (final MapEntry(key: variant, value: slot) in slots.entries) {
      await tester.ensureVisible(find.byKey(LuckyCardRow.chipKey(variant)));
      await tester.tap(find.byKey(LuckyCardRow.chipKey(variant)));
      await tester.pumpAndSettle();
      expect(_id(slot), findsOneWidget, reason: slot);
    }
  });

  group('대표 태그 칩(D76)', () {
    final tagChip = find.byKey(LuckyCardRow.tagChipKey('cheoneul_gwiin'));

    testWidgets('tag 칩은 칩 줄 맨 앞, 행운 4종 앞에 그립니다', (tester) async {
      await pumpApp(tester, scenario: 'member');
      await _settleToday(tester);

      final row = find.byType(LuckyCardRow);
      expect(find.descendant(of: row, matching: tagChip), findsOneWidget);
      // 칩 이름은 사전 tag 이름입니다(member glossary `tag.cheoneul_gwiin`).
      expect(
        find.descendant(of: tagChip, matching: find.text('천을귀인')),
        findsOneWidget,
      );
      final chips = tester.widgetList<LuckyChip>(
        find.descendant(of: row, matching: find.byType(LuckyChip)),
      );
      expect(
        [for (final chip in chips) chip.item.variant],
        [
          LuckyCardVariant.tag,
          LuckyCardVariant.color,
          LuckyCardVariant.direction,
          LuckyCardVariant.number,
          LuckyCardVariant.time,
        ],
      );
    });

    testWidgets('태그 칩을 누르면 뜻 한 줄이 스밉니다', (tester) async {
      await pumpApp(tester, scenario: 'member');
      await _settleToday(tester);

      await tester.ensureVisible(tagChip);
      await tester.tap(tagChip);
      await tester.pumpAndSettle();
      expect(_id(SlotIds.todayLuckyTagBody), findsOneWidget);
      expect(
        find.text('어려울 때 도와주는 사람이 곁에 오는 기운이에요.', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('사전에 이름이 없는 태그는 칩 없이 사전 빈칸으로 한 번만 보고합니다', (tester) async {
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
      expect(tagChip, findsOneWidget);
      expect(
        find.byKey(LuckyCardRow.tagChipKey('not_in_glossary')),
        findsNothing,
      );

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

    testWidgets('대표 태그가 없으면 태그 칩이 없고 줄은 행운 칩 4개입니다', (tester) async {
      final json = memberDailyJson();
      (json['tags'] as Map<String, dynamic>)['featured'] = <Object>[];
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

      expect(tagChip, findsNothing);
      expect(find.byType(LuckyChip), findsNWidgets(4));
    });
  });

  testWidgets('diary-written: 가이드 카드 after와 쓴 일기 보기', (tester) async {
    await pumpApp(tester, scenario: 'diary-written');
    await _settleToday(tester);
    final guide = tester.widget<GuideQuestionCard>(
      find.byType(GuideQuestionCard),
    );
    expect(guide.state, GuideQuestionState.after);
    expect(guide.actionLabel, _ko.todayGuideCtaWritten);
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
    expect(find.byType(DayReadingSkeleton), findsOneWidget);
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
    expect(banner.message, isNotEmpty);
    expect(_content, findsOneWidget);
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
    container.read(_testTodayProvider.notifier).date = tomorrow;
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
      expect(find.byType(DayReadingSkeleton), findsOneWidget);
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
                  of: find.byType(DayCharacter),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      expect(opacity(), 1);

      final json = memberDailyJson();
      change(json);
      final expectedVariant = Daily.fromJson(json).dayKind == DayKind.yongsinDay
          ? DayCharacterVariant.good
          : DayCharacterVariant.ordinary;
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
      expect(tester.widget<DayCharacter>(_content).variant, expectedVariant);
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

        expect(find.text(_ko.errorClient), findsOneWidget);
        expect(
          tester.widget<ReactionButton>(find.byType(ReactionButton)).on,
          isFalse,
        );
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets('time_unknown notice의 문장이 비어 있으면 app 문구로 배너를 그립니다', (
      tester,
    ) async {
      final json = memberDailyJson();
      json['notices'] = [
        {
          'code': 'time_unknown',
          'text': {'segments': <Object>[]},
        },
      ];
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
      final banner = tester.widget<NoticeBanner>(
        find.byWidgetPredicate(
          (w) =>
              w is NoticeBanner && w.variant == NoticeBannerVariant.timeUnknown,
        ),
      );
      expect(banner.message, _ko.noticeTimeUnknown);
    });

    testWidgets('태그 문장이 빈 segments면 태그 카드를 그리지 않습니다', (tester) async {
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
      expect(_id(SlotIds.todayFortuneHead), findsOneWidget);
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

    testWidgets('member: "다음" 일정 한 줄이 행운 칩 줄과 가이드 카드 사이에 있습니다', (tester) async {
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

      final rowTop = tester.getTopLeft(find.byType(EventRow)).dy;
      expect(
        tester.getBottomLeft(find.byType(LuckyCardRow)).dy,
        lessThanOrEqualTo(rowTop),
      );
      // 줄과 가이드 카드 사이는 시안의 10에 맞춘 12입니다.
      expect(
        tester.getTopLeft(find.byType(GuideQuestionCard)).dy -
            tester.getBottomLeft(find.byType(EventRow)).dy,
        closeTo(Space.s12, 0.5),
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
