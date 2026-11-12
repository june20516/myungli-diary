import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/daily.dart';
import 'package:myungli_diary/core/api/gen/model/glossary.dart';
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
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';
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
const String _fortuneTag = '이야기나 약속이 잘 맞아떨어지는 날이에요.';

/// member 오늘의 질문(`guide`)의 평문.
const String _guide = '오늘 마음이 잘 맞았던 대화가 있었다면 적어 볼까요?';

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

/// member 응답의 대표 태그 2순위를 화개로 바꾼 응답. 뜻이 없는 경우는 [_withoutHwagaeMeaning]
/// 사전과 함께 씁니다.
Daily _twoFeatured() {
  final json = memberDailyJson();
  return Daily.fromJson({
    ...json,
    'tags': {
      'featured': [
        {'key': 'harmony', 'polarity': 'good'},
        {'key': 'hwagae', 'polarity': 'neutral'},
      ],
      'all': ['harmony', 'hwagae', 'gongmang'],
    },
  });
}

/// member 사전에서 화개 태그의 뜻만 뺀 사전(사전 뜻은 용어마다 비어 있을 수 있음).
Future<GlossaryNames> _withoutHwagaeMeaning() async {
  final body =
      (jsonDecode(File('fixtures/member/getGlossary.json').readAsStringSync())
              as Map<String, dynamic>)['body']
          as Map<String, dynamic>;
  final glossary = Glossary.fromJson(body);
  return GlossaryNames(
    glossary.values,
    meanings: {...glossary.meanings}..remove('tag.hwagae'),
    hanja: glossary.hanja,
  );
}

/// 오늘 화면을 띄우고 사주 기운 섹션의 [rank] 대표 태그를 눌러 사주 기운 시트를 엽니다.
Future<ProviderContainer> _openTagSheet(
  WidgetTester tester, {
  int rank = 0,
  Daily? daily,
  Future<GlossaryNames> Function()? glossary,
}) async {
  final container = await pumpApp(
    tester,
    scenario: 'member',
    overrides: [
      if (daily != null)
        dailyControllerProvider.overrideWith(() => _StubDaily(daily)),
      if (glossary != null) glossaryProvider.overrideWith((ref) => glossary()),
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
      expect(head.label, '합');
      expect(head.onTap, isNull, reason: '시트 머리 태그는 누를 수 없습니다');
      expect(head.variant, HanjaTagVariant.normal);
      expect(_inSheet(find.byType(DepthLink)), findsOneWidget);
      expect(
        _inSheet(
          find.text(
            '서로 다른 기운이 맞물려 하나가 되는 것으로, 사람과 일이 잘 어울려요.',
            findRichText: true,
          ),
        ),
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
      expect(list.diaryLinkLabel, _ko.tagSheetDiaryCta('합'));
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

    testWidgets('머리 태그와 근거 아이콘은 세로 가운데가 같습니다', (tester) async {
      await _openTagSheet(tester);

      final tag = tester.getRect(_inSheet(find.byType(HanjaTag)));
      final icon = tester.getRect(
        find.descendant(
          of: _inSheet(find.byType(DepthLink)),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.center.dy, moreOrLessEquals(tag.center.dy, epsilon: 0.5));
    });

    testWidgets('순번이 대표 태그 범위 밖이면 아무것도 그리지 않습니다', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            glossaryProvider.overrideWith(
              (ref) async => const GlossaryNames({
                'tag': {'cheoneul_gwiin': '천을귀인'},
              }),
            ),
          ],
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: TagSheet(daily: Daily.fromJson(memberDailyJson()), rank: 1),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(HanjaTag), findsNothing);
      expect(find.byType(TagSentenceList), findsNothing);
    });

    testWidgets('2순위: 근거 아이콘 없이 빈 안내(IA empty)', (tester) async {
      await _openTagSheet(
        tester,
        rank: 1,
        daily: _twoFeatured(),
        glossary: _withoutHwagaeMeaning,
      );

      final head = tester.widget<HanjaTag>(_inSheet(find.byType(HanjaTag)));
      expect(head.label, '화개');
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
        _ko.tagSheetDiaryCta('화개'),
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
        ['합'],
      );
      expect(body.target?.segments.map((s) => s.text).join(), _fortuneTag);
    });
  });
}
