import 'package:flutter/material.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/elements/ohaeng_cell.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 지장간 하나(한자와 독음, 있으면 십성 용어 라벨).
@immutable
final class ManseHiddenStem {
  /// [hanja](한 글자)와 [reading](독음, 없으면 한자만), [label](지장간 십성 `term-token`).
  const new({required this.hanja, this.reading, this.label});

  /// 한자.
  final String hanja;

  /// 독음.
  final String? reading;

  /// 지장간 십성 용어(`term-token` `label`, 누르면 풀이). 한자·독음 줄 2px 아래에 둡니다.
  /// 없으면 한자·독음 한 줄만입니다.
  final Widget? label;
}

/// 만세력 표의 기둥 한 열.
@immutable
final class ManseColumn {
  /// 열을 만듭니다. [stem]이 null이면 그 열은 빈 칸입니다(시간 모름의 시주).
  const new({
    required this.header,
    this.stem,
    this.branch,
    this.hiddenStems = const [],
    this.twelveStage,
    this.shinsal = const [],
  });

  /// 열 머리(시주·일주·월주·연주).
  final String header;

  /// 천간 `mini` 칸.
  final OhaengCell? stem;

  /// 지지 `mini` 칸.
  final OhaengCell? branch;

  /// 지장간(여기·중기·정기 순).
  final List<ManseHiddenStem> hiddenStems;

  /// 12운성(용어 토큰 또는 글자). 없으면 빈 칸입니다. 값 글자 스타일은 표가 줍니다.
  final Widget? twelveStage;

  /// 신살들(칸 안 여러 줄, 용어 토큰 또는 글자).
  final List<Widget> shinsal;

  /// 값이 없는 열인지.
  bool get empty => stem == null;
}

/// 만세력 기본 표(`manse-table`): 기둥 네 열 × 지장간·12운성·신살.
///
/// 열 순서는 원국표와 같은 시·일·월·연입니다. 맨 위 줄은 기둥 이름과 천간·지지 `ohaeng.cell`
/// `mini`, 아래 줄 머리는 너비 52의 `term-token` `label`([hiddenStemsHeader] 등, 누르면 풀이)
/// 입니다. 값은 `type.body.ui` `text.primary` 가운데입니다(값 칸 위젯에 [DefaultTextStyle]로
/// 주고, 용어 토큰 `inline`은 이 글자를 씀). 지장간 하나는 늘 두 줄 묶음입니다(V49):
/// 위 줄 한자(`font.family.hanja`)와 독음(`type.caption.sm` `text.secondary`), 2px 아래
/// 십성 라벨. 묶음은 계약 순서로 `space.4` 간격을 두고 쌓고, 신살도 하나씩 `space.4`
/// 간격으로 쌓습니다.
/// 같은 줄 칸(줄 머리 포함)은 위로 맞추고 가장 높은 칸만큼 줄이 늘어납니다. 줄 사이는
/// 1px `line`입니다. 시간 모름이면 시주 열이 비고(`time-unknown`), 글자 크기는 1.3배에서
/// 멈춥니다. 스크린리더는 표 이름 [tableLabel]과 줄 머리를 읽고, 지장간은 한자와 독음, 십성
/// 순서로 읽습니다.
class ManseTable extends StatelessWidget {
  /// 만세력 표를 만듭니다.
  const new({
    required this.hour,
    required this.day,
    required this.month,
    required this.year,
    required this.hiddenStemsHeader,
    required this.twelveStageHeader,
    required this.shinsalHeader,
    required this.tableLabel,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('manse-table', {}, {
    'time-unknown',
  });

  /// 줄 머리 너비(`rowHeaderWidth`).
  static const double rowHeaderWidth = 52;

  /// 시주.
  final ManseColumn hour;

  /// 일주.
  final ManseColumn day;

  /// 월주.
  final ManseColumn month;

  /// 연주.
  final ManseColumn year;

  /// 지장간 줄 머리.
  final Widget hiddenStemsHeader;

  /// 12운성 줄 머리.
  final Widget twelveStageHeader;

  /// 신살 줄 머리.
  final Widget shinsalHeader;

  /// 표 이름(스크린리더).
  final String tableLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final columns = [hour, day, month, year];
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: OhaengCell.textScaleMax);
    final valueStyle = tokens.typography.bodyUi.copyWith(
      color: colors.textPrimary,
    );
    final hanjaFamily = tokens.typography.hanjaPillar.fontFamily;

    Widget cell(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s8, horizontal: 2),
      child: Align(
        alignment: Alignment.topCenter,
        child: DefaultTextStyle(
          style: valueStyle,
          textAlign: TextAlign.center,
          child: child,
        ),
      ),
    );

    Widget header(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s8),
      child: Align(alignment: AlignmentDirectional.topStart, child: child),
    );

    Widget hidden(ManseColumn column) => Column(
      mainAxisSize: MainAxisSize.min,
      spacing: Space.s4,
      children: [
        for (final stem in column.hiddenStems)
          Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: stem.hanja,
                      style: valueStyle.copyWith(fontFamily: hanjaFamily),
                    ),
                    if (stem.reading != null)
                      TextSpan(
                        text: ' ${stem.reading}',
                        style: tokens.typography.captionSm.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              ?stem.label,
            ],
          ),
      ],
    );

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scaler),
      child: Semantics(
        container: true,
        label: tableLabel,
        child: Table(
          columnWidths: const {0: FixedColumnWidth(rowHeaderWidth)},
          border: TableBorder(horizontalInside: BorderSide(color: colors.line)),
          children: [
            TableRow(
              children: [
                const SizedBox.shrink(),
                for (final column in columns)
                  cell(
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          column.header,
                          style: tokens.typography.captionMd.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: Space.s4),
                        column.stem ??
                            const OhaengCell.empty(size: OhaengCellSize.mini),
                        const SizedBox(height: 2),
                        column.branch ??
                            const OhaengCell.empty(size: OhaengCellSize.mini),
                      ],
                    ),
                  ),
              ],
            ),
            TableRow(
              children: [
                header(hiddenStemsHeader),
                for (final column in columns) cell(hidden(column)),
              ],
            ),
            TableRow(
              children: [
                header(twelveStageHeader),
                for (final column in columns)
                  cell(column.twelveStage ?? const SizedBox.shrink()),
              ],
            ),
            TableRow(
              children: [
                header(shinsalHeader),
                for (final column in columns)
                  cell(
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: Space.s4,
                      children: column.shinsal,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
