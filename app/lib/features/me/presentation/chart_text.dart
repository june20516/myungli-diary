import 'dart:async';

import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/branch.dart';
import 'package:myungli_diary/core/api/gen/model/chart.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/core/api/gen/model/pillar.dart';
import 'package:myungli_diary/core/api/gen/model/position.dart';
import 'package:myungli_diary/core/api/gen/model/stem.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/saju/luck_label.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/depth/application/evidence_unlock_controller.dart';
import 'package:myungli_diary/features/depth/application/explain_content.dart';
import 'package:myungli_diary/features/depth/application/personal_reading_key.dart';
import 'package:myungli_diary/features/depth/application/term_origin.dart';
import 'package:myungli_diary/features/glossary/model/ganji_reading.dart';
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';
import 'package:myungli_diary/features/me/model/ganji.dart';

/// 원국표의 기둥 한 열과 그 천간·지지 자리.
enum ChartColumn {
  /// 시주.
  hour(Position.hourStem, Position.hourBranch),

  /// 일주.
  day(Position.dayStem, Position.dayBranch),

  /// 월주.
  month(Position.monthStem, Position.monthBranch),

  /// 연주.
  year(Position.yearStem, Position.yearBranch);

  new(this.stem, this.branch);

  /// 천간 자리.
  final Position stem;

  /// 지지 자리.
  final Position branch;

  /// [chart]의 이 기둥. 시간 모름의 시주는 null입니다.
  Pillar? of(Chart chart) => switch (this) {
    ChartColumn.hour => chart.pillars.hour,
    ChartColumn.day => chart.pillars.day,
    ChartColumn.month => chart.pillars.month,
    ChartColumn.year => chart.pillars.year,
  };

  /// 열 머리(시주·일주·월주·연주).
  String header(AppLocalizations l10n) => switch (this) {
    ChartColumn.hour => l10n.sajuPillarHour,
    ChartColumn.day => l10n.sajuPillarDay,
    ChartColumn.month => l10n.sajuPillarMonth,
    ChartColumn.year => l10n.sajuPillarYear,
  };
}

/// 표 칸 용어를 눌렀을 때 부르는 함수. [personal]은 그 칸의 원국 개인 해석 자리입니다.
typedef TermTapHandler = void Function(
  String termId,
  PersonalReadingKey personal,
);

/// 사주 표 칸의 글자(A65)와 용어 토큰을 만듭니다.
///
/// 한자·오행은 간지 표, 독음·용어 이름은 용어 사전 `values`에서 읽습니다. 이름이 없으면 사전
/// 한자, 그것도 없으면 그 자리를 비웁니다(키를 그대로 보이지 않음). 용어 토큰은 이름이 있을 때만
/// 누를 수 있고, 누르면 풀이 시트를 엽니다. 그 풀이 시트의 "근거 보기"는 누른 칸의 원국 개인
/// 해석을 보이는 근거 시트입니다(A58).
final class ChartText {
  /// 화면 [context]와 용어 이름 사전 [names], 시트 여는 [sheets]로 만듭니다.
  const new(this.context, this.names, this.sheets, {this.onTermTap});

  /// 글자와 시트를 쓸 화면 맥락.
  final BuildContext context;

  /// 용어 이름 사전(아직 못 받았으면 null).
  final GlossaryNames? names;

  /// 풀이 시트를 여는 모음.
  final DepthSheets sheets;

  /// 표 칸 용어를 눌렀을 때. 없으면 근거 시트로 이어지는 풀이 시트를 엽니다.
  final TermTapHandler? onTermTap;

  /// 현재 언어의 ui 문구.
  AppLocalizations get l10n => AppLocalizations.of(context);

  /// [category]의 [value] 이름. 없으면 사전 한자, 그것도 없으면 null입니다.
  String? nameOf(String category, String value) =>
      names?.valueName(category, value) ?? names?.hanjaOf('$category.$value');

  /// 천간 독음. 없으면 null입니다(원천은 [GanjiReading], A133).
  String? stemReading(Stem stem) => GanjiReading.stem(stem, names);

  /// 지지 독음. 없으면 null입니다(원천은 [GanjiReading], A133).
  String? branchReading(Branch branch) => GanjiReading.branch(branch, names);

  /// 오행 이름(없으면 사전 한자).
  String? elementName(FiveElement element) => nameOf('element', element.value);

  /// "庚 경"처럼 한자와 독음(있으면).
  String stemText(Stem stem) => [stemHanja(stem), ?stemReading(stem)].join(' ');

  /// 지지의 한자와 독음(있으면).
  String branchText(Branch branch) =>
      [branchHanja(branch), ?branchReading(branch)].join(' ');

  /// 표 칸 용어의 풀이 시트를 엽니다.
  void openTerm(String termId, PersonalReadingKey personal) {
    final handler = onTermTap;
    if (handler != null) {
      handler(termId, personal);
    } else {
      unawaited(_openExplain(termId, personal));
    }
  }

  Future<void> _openExplain(String termId, PersonalReadingKey personal) =>
      sheets.openExplain(
        context,
        ExplainTerm(
          termId,
          origin: TermOrigin(
            // 표 칸은 writing 슬롯이 아니라, 열릴 근거 시트의 "내 사주에서는" 슬롯을 가리킵니다.
            slotId: SlotIds.evidenceSheetPersonalBody,
            subject: const ChartEvidenceSubject(),
            personal: personal,
          ),
        ),
      );

  /// [category].[value] 용어의 `label` 토큰. 이름이 없으면 한자 글자, 그것도 없으면 null입니다.
  Widget? termLabel(
    String category,
    String value,
    PersonalReadingKey personal,
  ) {
    final name = names?.valueName(category, value);
    if (name != null) {
      return TermToken(
        label: name,
        variant: TermTokenVariant.label,
        onTap: () => openTerm('$category.$value', personal),
      );
    }
    final hanja = names?.hanjaOf('$category.$value');
    return hanja == null ? null : plainLabel(hanja);
  }

  /// 대운·세운 표의 [category].[value] 라벨(V49). 이름이 없으면 누를 수 없는 한자 글자,
  /// 그것도 없으면 null(자리만 남김)입니다.
  LuckLabel? luckLabel(
    String category,
    String value,
    PersonalReadingKey personal,
  ) {
    final name = names?.valueName(category, value);
    if (name != null) {
      return LuckLabel(
        name,
        onTap: () => openTerm('$category.$value', personal),
      );
    }
    final hanja = names?.hanjaOf('$category.$value');
    return hanja == null ? null : LuckLabel(hanja);
  }

  /// 표 값 칸(12운성·신살)의 용어. 글자는 표가 주는 값 글자를 따릅니다(`term-token` `inline`).
  /// 이름이 없으면 한자 글자, 그것도 없으면 null입니다.
  Widget? termValue(
    String category,
    String value,
    PersonalReadingKey personal,
  ) {
    final name = names?.valueName(category, value);
    if (name != null) {
      return TermToken(
        label: name,
        variant: TermTokenVariant.inline,
        onTap: () => openTerm('$category.$value', personal),
      );
    }
    final hanja = names?.hanjaOf('$category.$value');
    return hanja == null ? null : Text(hanja);
  }

  /// 누를 수 없는 라벨 글자(`term-token` `label`과 같은 크기).
  Widget plainLabel(String text) {
    final tokens = context.tokens;
    return Text(
      text,
      textAlign: TextAlign.center,
      style: tokens.typography.captionMd.copyWith(
        color: tokens.colors.textSecondary,
      ),
    );
  }

  /// 스크린리더 항목을 잇습니다.
  String join(Iterable<String?> parts) => parts.nonNulls
      .where((part) => part.isNotEmpty)
      .join(l10n.a11yListSeparator);
}
