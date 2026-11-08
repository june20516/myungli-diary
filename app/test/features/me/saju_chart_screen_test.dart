import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/frame/scroll_hint.dart';
import 'package:myungli_diary/design/components/frame/section_header.dart';
import 'package:myungli_diary/design/components/saju/birth_info_row.dart';
import 'package:myungli_diary/design/components/saju/daeun_table.dart';
import 'package:myungli_diary/design/components/saju/luck_pillar.dart';
import 'package:myungli_diary/design/components/saju/saju_pillars.dart';
import 'package:myungli_diary/design/components/saju/stage_strip.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/elements/lock_veil.dart';
import 'package:myungli_diary/features/depth/application/explain_content.dart';
import 'package:myungli_diary/features/depth/presentation/explain_sheet.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../../support/app_harness.dart';
import '../../support/onboarding_steps.dart';

final _ko = AppLocalizationsKo();

final Finder _chart = find.byKey(const ValueKey(ScreenIds.sajuChart));

Finder _inChart(Finder matching) =>
    find.descendant(of: _chart, matching: matching);

final Finder _explain = find.byKey(const Key(ScreenIds.explainSheet));

/// 용신 판정 근거 줄.
final Finder _yongsinBasis = _inChart(
  find.byWidgetPredicate(
    (widget) =>
        widget is SentenceBlock &&
        widget.slotId == SlotIds.sajuChartYongsinBasis,
  ),
);

/// member 사전에 일간 용어(`role.day_master`, W61)와 12운성 이름을 더한 사전.
Future<GlossaryNames> _glossary() async {
  final json = jsonDecode(
    File('fixtures/member/getGlossary.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final body = json['body'] as Map<String, dynamic>;
  final values = {
    for (final entry in (body['values'] as Map<String, dynamic>).entries)
      entry.key: Map<String, String>.from(entry.value as Map),
  };
  values['role'] = {...?values['role'], 'day_master': '일간'};
  values['twelve_stage'] = const {
    'jangsaeng': '장생',
    'mokyok': '목욕',
    'gwandae': '관대',
    'yang': '양',
  };
  return GlossaryNames(values);
}

/// 받은 나의 사주의 용신에 판정 근거 앞부분(`basisPreview`)을 더합니다.
final class _AddBasisPreview extends Interceptor {
  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    final data = response.data;
    if (response.requestOptions.path == '/v1/chart' && data is Map) {
      final body = Map<String, Object?>.of(data.cast<String, Object?>());
      body['yongsin'] = {
        ...(body['yongsin']! as Map).cast<String, Object?>(),
        'basisPreview': {
          'segments': [
            {'text': '여름에 태어난 경금은'},
          ],
        },
      };
      response.data = body;
    }
    handler.next(response);
  }
}

/// [scenario]로 앱을 띄우고 사주 표를 엽니다. [luck]이면 만세력과 대운 탭부터입니다.
Future<void> _openChart(
  WidgetTester tester, {
  bool luck = false,
  String scenario = 'member',
  Interceptor? network,
}) async {
  final container = await pumpApp(
    tester,
    scenario: scenario,
    network: network,
    overrides: [glossaryProvider.overrideWith((ref) => _glossary())],
  );
  unawaited(
    container
        .read(routerProvider)
        .push<void>(luck ? sajuChartLuckPath() : pathOf(ScreenIds.sajuChart)),
  );
  await pumpUntilScreen(tester, ScreenIds.sajuChart);
  await pumpUntil(
    tester,
    () =>
        _inChart(find.byType(luck ? DaeunTable : SajuPillars))
            .evaluate()
            .isNotEmpty,
  );
  await settleWithIo(tester);
}

/// [cell]이 [row] 줄의 보이는 폭 안에 다 들어오는지.
bool _insideViewport(WidgetTester tester, Finder cell, Finder row) {
  final viewport = tester.getRect(row);
  final rect = tester.getRect(cell);
  return rect.left >= viewport.left - 0.5 && rect.right <= viewport.right + 0.5;
}

void main() {
  setUpAll(ensureTimeZonesInitialized);

  testWidgets('F-019: 원국 일간 칩은 천간이 아니라 용어 role.day_master를 엽니다', (
    tester,
  ) async {
    await _openChart(tester);
    final chip = _inChart(
      find.widgetWithText(TermToken, _ko.sajuPillarDayMaster),
    );
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await settleWithIo(tester);

    expect(_explain, findsOneWidget);
    final content = tester
        .widget<ExplainSheet>(find.byType(ExplainSheet))
        .content;
    expect(content, isA<ExplainTerm>());
    expect((content as ExplainTerm).termId, 'role.day_master');
  });

  testWidgets('머리: 호칭 제목과 출생 정보 줄(프로필), 원국 탭 섹션 머리 셋', (tester) async {
    await _openChart(tester);
    expect(_inChart(find.text(_ko.sajuChartHeadTitle('하늘'))), findsOneWidget);
    final row = tester.widget<BirthInfoRow>(
      _inChart(find.byType(BirthInfoRow)),
    );
    expect(row.calendarTag, _ko.calendarSolar);
    expect(row.gender, _ko.genderFemale);
    expect(row.hourGlyph, '未');
    expect(row.hourName, _ko.birthInfoHour(_ko.branchMi));
    expect(row.timeUnknown, isFalse);

    final titles = tester
        .widgetList<SectionHeader>(_inChart(find.byType(SectionHeader)))
        .map((header) => (header.title, header.description))
        .toList();
    expect(titles, [
      (_ko.sajuChartPillarsTitle, _ko.sajuChartPillarsDesc),
      (_ko.sajuChartOhaengTitle, _ko.sajuChartOhaengDesc),
      (_ko.sajuChartYongsinTitle, null),
    ]);
    // 신강 알약은 그리지 않습니다(D113 ⑦).
    expect(_inChart(find.textContaining('신강')), findsNothing);
  });

  testWidgets('원국이 시간 모름이면 출생 정보 줄은 시간 모름 알약', (tester) async {
    await _openChart(tester, scenario: 'member-time-unknown');
    final row = tester.widget<BirthInfoRow>(
      _inChart(find.byType(BirthInfoRow)),
    );
    expect(row.timeUnknown, isTrue);
    expect(row.hourGlyph, isNull);
  });

  testWidgets('잠긴 용신 판정 근거: 두 줄, 자물쇠와 열기(꺾쇠 없음), 앞부분 없으면 자리값만', (tester) async {
    await _openChart(tester);
    await tester.ensureVisible(_yongsinBasis);
    await tester.pumpAndSettle();
    final veil = tester.widget<LockVeil>(
      find.descendant(of: _yongsinBasis, matching: find.byType(LockVeil)),
    );
    expect(veil.lines, 2);
    expect(veil.lead, isNull);
    expect(
      find.descendant(
        of: _yongsinBasis,
        matching: find.byIcon(PhosphorIconsRegular.lockSimple),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _yongsinBasis,
        matching: find.byIcon(PhosphorIconsLight.caretRight),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: _yongsinBasis,
        matching: find.byIcon(PhosphorIconsRegular.caretRight),
      ),
      findsNothing,
    );
  });

  testWidgets('잠긴 용신 판정 근거: basisPreview가 오면 앞부분으로 또렷하게', (tester) async {
    await _openChart(tester, network: _AddBasisPreview());
    final veil = tester.widget<LockVeil>(
      find.descendant(of: _yongsinBasis, matching: find.byType(LockVeil)),
    );
    expect(veil.lead?.segments.single.text, '여름에 태어난 경금은');
  });

  testWidgets('대운과 세운: 섹션 머리, luck-pillar 줄 둘, 처음에 지금과 올해 칸이 보임', (
    tester,
  ) async {
    await _openChart(tester, luck: true);
    final titles = tester
        .widgetList<SectionHeader>(_inChart(find.byType(SectionHeader)))
        .map((header) => header.title)
        .toList();
    expect(titles, [_ko.sajuChartDaeunTitle, _ko.sajuChartSeunTitle]);
    expect(_inChart(find.byType(ScrollHint)), findsNWidgets(2));

    final daeunRow = _inChart(find.byKey(DaeunTable.daeunScrollKey));
    final seunRow = _inChart(find.byKey(DaeunTable.seunScrollKey));
    await tester.ensureVisible(seunRow);
    await tester.pumpAndSettle();

    // 1990년생 2026년: 지금 대운은 넷째(34세), 올해 세운은 2026년입니다.
    final current = find.byKey(DaeunTable.daeunKey(3));
    expect(_insideViewport(tester, current, daeunRow), isTrue);
    expect(tester.widget<LuckPillar>(current).current, isTrue);
    final thisYear = find.byKey(DaeunTable.seunKey(2026));
    expect(_insideViewport(tester, thisYear, seunRow), isTrue);

    // 세운 기둥은 12운성과 시작 연도가 없습니다.
    final seun = tester.widget<LuckPillar>(thisYear);
    expect(seun.current, isTrue);
    expect(seun.twelveStage, isNull);
    expect(seun.startYear, isNull);
    expect(seun.branchTenGod, isNull);
  });

  testWidgets('띠 머리 "12운성" → 설명 시트 본문 아래 stage-strip', (tester) async {
    await _openChart(tester, luck: true);
    final chip = _inChart(
      find.widgetWithText(TermToken, _ko.manseRowTwelveStages),
    );
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await settleWithIo(tester);

    final content = tester
        .widget<ExplainSheet>(find.byType(ExplainSheet))
        .content;
    expect(content, isA<ExplainUiText>());
    expect((content as ExplainUiText).title, _ko.manseRowTwelveStages);
    expect(content.body, _ko.sajuChartUnseongDesc);
    expect(
      find.descendant(of: _explain, matching: find.byType(StageStrip)),
      findsOneWidget,
    );
  });

  testWidgets('띠 머리 "지장간" → 설명 시트(stage-strip 없음)', (tester) async {
    await _openChart(tester, luck: true);
    final chip = _inChart(
      find.widgetWithText(TermToken, _ko.manseRowHiddenStems),
    );
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await settleWithIo(tester);

    final content =
        tester.widget<ExplainSheet>(find.byType(ExplainSheet)).content
            as ExplainUiText;
    expect(content.body, _ko.sajuChartJijangganDesc);
    expect(content.attachment, isNull);
  });
}
