import 'package:flutter/material.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/elements/ohaeng_cell.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 지장간 하나(한자와 독음).
@immutable
final class ManseHiddenStem {
  /// [hanja](한 글자)와 [reading](독음, 없으면 한자만).
  const new({required this.hanja, this.reading});

  /// 한자.
  final String hanja;

  /// 독음.
  final String? reading;
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

  /// 12운성 이름. 없으면 빈 칸입니다.
  final String? twelveStage;

  /// 신살 이름들(칸 안 여러 줄).
  final List<String> shinsal;

  /// 값이 없는 열인지.
  bool get empty => stem == null;
}

/// 만세력 기본 표(`manse-table`): 기둥 네 열 × 지장간·12운성·신살.
///
/// 열 순서는 원국표와 같은 시·일·월·연입니다. 맨 위 줄은 기둥 이름과 천간·지지 `ohaeng.cell`
/// `mini`, 아래 줄 머리는 너비 52의 `term-token` `label`([hiddenStemsHeader] 등, 누르면 풀이)
/// 입니다. 값은 `type.body.ui` `text.primary` 가운데이고 지장간 한자는 `font.family.hanja`, 독음은
/// `type.caption.sm` `text.secondary`입니다. 줄 사이는 1px `line`입니다. 시간 모름이면 시주
/// 열이 비고(`time-unknown`), 글자 크기는 1.3배에서 멈춥니다. 스크린리더는 표 이름
/// [tableLabel]과 줄 머리를 읽습니다.
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
      child: Center(child: child),
    );

    Widget header(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s8),
      child: Align(alignment: AlignmentDirectional.centerStart, child: child),
    );

    Widget hidden(ManseColumn column) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final stem in column.hiddenStems)
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
      ],
    );

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scaler),
      child: Semantics(
        container: true,
        label: tableLabel,
        child: Table(
          columnWidths: const {0: FixedColumnWidth(rowHeaderWidth)},
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
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
                  cell(Text(column.twelveStage ?? '', style: valueStyle)),
              ],
            ),
            TableRow(
              children: [
                header(shinsalHeader),
                for (final column in columns)
                  cell(
                    Text(
                      column.shinsal.join('\n'),
                      textAlign: TextAlign.center,
                      style: valueStyle,
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
