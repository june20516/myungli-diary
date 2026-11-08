import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/daily.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/depth/evidence_sheet_body.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/components/today/date_header.dart';
import 'package:myungli_diary/design/components/today/tag_sentence_list.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/depth/presentation/tag_sheet.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';
import 'package:myungli_diary/features/today/presentation/today_screen.dart';

import '../../support/app_harness.dart';
import '../../support/daily_fixture.dart';
import '../../support/depth_link_finders.dart';
import '../../support/onboarding_steps.dart' show pumpUntil;

final _ko = AppLocalizationsKo();

final Finder _sheet = find.byKey(const Key(ScreenIds.tagSheet));

Finder _inSheet(Finder matching) =>
    find.descendant(of: _sheet, matching: matching);

/// member 보조 문장(`fortune.tag`)의 평문.
const String _fortuneTag = '천을귀인이 들어 도움을 받기 쉬운 날이에요.';

/// member 오늘의 질문(`guide`)의 평문.
const String _guide = '오늘 눈길이 갔던 사람이나 장면을 하나 적어 볼까요?';

/// 오늘 응답을 [daily]로 고정하는 대역.
final class _StubDaily extends DailyController {
  new(this.daily);

  final Daily daily;

  @override
  Future<DailyView> build() async => DailyView(
    date: CalendarDate(2026, 10, 13),
    daily: daily,
    stale: false,
    cacheKey: null,
  );
}

/// member 응답에 대표 태그 2순위(역마)를 더한 응답.
Daily _twoFeatured() {
  final json = memberDailyJson();
  return Daily.fromJson({
    ...json,
    'tags': {
      'featured': [
        {'key': 'cheoneul_gwiin', 'polarity': 'good'},
        {'key': 'yeokma', 'polarity': 'neutral'},
      ],
      'all': ['cheoneul_gwiin', 'yeokma', 'yongsin_day'],
    },
  });
}

/// 오늘 화면을 띄우고 사주 기운 섹션의 [rank] 대표 태그를 눌러 사주 기운 시트를 엽니다.
Future<ProviderContainer> _openTagSheet(
  WidgetTester tester, {
  int rank = 0,
  Daily? daily,
}) async {
  final container = await pumpApp(
    tester,
    scenario: 'member',
    overrides: [
      if (daily != null)
        dailyControllerProvider.overrideWith(() => _StubDaily(daily)),
    ],
  );
  await pumpUntil(tester, () => find.byType(DateHeader).evaluate().isNotEmpty);
  final featured = find.descendant(
    of: find.byKey(TodayScreen.featuredCardKey),
    matching: find.byType(HanjaTag),
  );
  await tester.ensureVisible(featured.at(rank));
  await tester.pumpAndSettle();
  await tester.tap(featured.at(rank));
  await tester.pumpAndSettle();
  expect(_sheet, findsOneWidget);
  return container;
}

void main() {
  setUpAll(ensureTimeZonesInitialized);

  group('TagSheet', () {
    testWidgets('1순위: 머리 태그와 근거 아이콘, 뜻, 보조 문장과 오늘의 질문 줄, 일기 보기 링크', (
      tester,
    ) async {
      await _openTagSheet(tester);

      final head = tester.widget<HanjaTag>(_inSheet(find.byType(HanjaTag)));
      expect(head.label, '천을귀인');
      expect(head.onTap, isNull, reason: '시트 머리 태그는 누를 수 없습니다');
      expect(head.variant, HanjaTagVariant.normal);
      expect(_inSheet(find.byType(DepthLink)), findsOneWidget);
      expect(
        _inSheet(find.text('어려울 때 도와주는 사람이 곁에 오는 기운이에요.', findRichText: true)),
        findsOneWidget,
      );

      final list = tester.widget<TagSentenceList>(
        _inSheet(find.byType(TagSentenceList)),
      );
      expect(list.title, _ko.tagSheetSentencesTitle);
      expect(
        [for (final item in list.items) item.kindLabel],
        [_ko.tagSheetSentenceKindFortune, _ko.tagSheetSentenceKindGuide],
      );
      expect(
        [
          for (final item in list.items)
            item.text.segments.map((s) => s.text).join(),
        ],
        [_fortuneTag, _guide],
      );
      expect(list.diaryLinkLabel, _ko.tagSheetDiaryCta('천을귀인'));
      expect(_inSheet(find.byKey(TagSentenceList.emptyKey)), findsNothing);
    });

    testWidgets('배치: 뜻은 머리 아래 space.12, 문장 목록은 뜻 아래 space.24', (tester) async {
      await _openTagSheet(tester);

      final head = tester.getRect(_inSheet(find.byType(HanjaTag)));
      final meaning = tester.getRect(
        _inSheet(find.byKey(const ValueKey(SlotIds.tagSheetTagMeaning))),
      );
      final list = tester.getRect(_inSheet(find.byType(TagSentenceList)));
      expect(meaning.top - head.bottom, Space.s12);
      expect(list.top - meaning.bottom, Space.s24);
      expect(find.byType(TagSheet), findsOneWidget);
    });

    testWidgets('2순위: 근거 아이콘 없이 빈 안내(IA empty)', (tester) async {
      await _openTagSheet(tester, rank: 1, daily: _twoFeatured());

      final head = tester.widget<HanjaTag>(_inSheet(find.byType(HanjaTag)));
      expect(head.label, '역마');
      expect(_inSheet(find.byType(DepthLink)), findsNothing);
      expect(_inSheet(find.byKey(TagSentenceList.emptyKey)), findsOneWidget);
      expect(_inSheet(find.text(_ko.tagSheetSentencesEmpty)), findsOneWidget);
      // 사전에 뜻이 없는 태그는 뜻 자리를 그리지 않습니다(A22 남은 규칙).
      expect(
        _inSheet(find.byKey(const ValueKey(SlotIds.tagSheetTagMeaning))),
        findsNothing,
      );
      expect(
        tester
            .widget<TagSentenceList>(_inSheet(find.byType(TagSentenceList)))
            .diaryLinkLabel,
        _ko.tagSheetDiaryCta('역마'),
      );
    });

    testWidgets('일기 보기 링크는 시트를 닫고 그 태그의 tag-diary를 엽니다', (tester) async {
      await _openTagSheet(tester);

      await tester.tap(_inSheet(find.byKey(TagSentenceList.diaryLinkKey)));
      await pumpUntil(
        tester,
        () => find
            .byKey(const ValueKey(ScreenIds.tagDiary))
            .evaluate()
            .isNotEmpty,
      );

      expect(_sheet, findsNothing);
      expect(find.byKey(const ValueKey(ScreenIds.tagDiary)), findsOneWidget);
    });

    testWidgets('근거 아이콘은 그 태그를 머리로, 보조 문장을 대상으로 근거 시트를 쌓습니다', (tester) async {
      await _openTagSheet(tester);

      await tester.tap(depthLinkTarget(of: _sheet));
      await tester.pumpAndSettle();

      final evidence = find.byKey(const Key(ScreenIds.evidenceSheet));
      expect(evidence, findsOneWidget);
      expect(_sheet, findsOneWidget, reason: '사주 기운 시트 위에 쌓입니다');
      final body = tester.widget<EvidenceSheetBody>(
        find.descendant(of: evidence, matching: find.byType(EvidenceSheetBody)),
      );
      expect(
        [for (final tag in body.targetTags) (tag as HanjaTag).label],
        ['천을귀인'],
      );
      expect(body.target?.segments.map((s) => s.text).join(), _fortuneTag);
    });
  });
}
