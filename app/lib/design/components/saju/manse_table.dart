import 'package:flutter/material.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/saju/band_table.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 만세력 표(`manse-table`, V89): 내 일간 기준 줄 한 줄과 그 아래 [BandTable]
/// (지장간, 12운성, 신살 띠).
///
/// 기준 줄은 누를 수 없는 글자 한 줄입니다(`type.caption.lg` `text.secondary`, 간 한자만
/// `font.family.hanja`, 아래 `space.12`). 시간 모름이면 [BandTable]의 시주 열 칸이 모두 빈
/// 칸입니다. 불러오는 중은 기준 줄 뼈(폭 50%) + [BandTable] 뼈입니다. 스크린리더는 기준 줄은 글자
/// 그대로 읽고 표는 [BandTable]이 읽습니다. 글자 배율은 1.3배에서 멈춥니다(`textScaleMax`).
class ManseTable extends StatelessWidget {
  /// 만세력 표를 만듭니다. [basis]는 기준 줄 글자 전체, [basisGlyph]는 그 안의 간 한자입니다.
  const new({
    required this.basis,
    required this.basisGlyph,
    required this.table,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('manse-table', {}, {
    'loading',
    'time-unknown',
  });

  /// 기준 줄 글자를 찾는 테스트용 키.
  static const Key basisKey = ValueKey('manse-table-basis');

  /// 기준 줄과 표 사이(`basis.marginBottom`).
  static const double basisGap = Space.s12;

  /// 기준 줄 뼈 폭 비율. 계약 `manse-table.states.loading.skeleton`(50%).
  static const double skeletonWidthFactor = 0.5;

  /// 글자 크기를 멈추는 배율.
  static const double textScaleMax = 1.3;

  /// 기준 줄 글자 전체(예 "내 일간 庚(경금) 기준").
  final String basis;

  /// [basis] 안의 일간 한자(이 글자만 한자 글꼴).
  final String basisGlyph;

  /// 띠 표. 불러오는 중이면 `loading` 상태의 표를 넘깁니다.
  final BandTable table;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: textScaleMax,
      child: Semantics(
        container: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (table.loading)
              FractionallySizedBox(
                widthFactor: skeletonWidthFactor,
                alignment: AlignmentDirectional.centerStart,
                child: SkeletonBone(
                  height: SkeletonBone.lineHeight,
                  borderRadius: Radii.xs,
                  animated: table.animated,
                ),
              )
            else
              Text.rich(_basisSpan(tokens), key: basisKey),
            const SizedBox(height: basisGap),
            table,
          ],
        ),
      ),
    );
  }

  TextSpan _basisSpan(MyungliTokens tokens) {
    final style = tokens.typography.captionLg.copyWith(
      color: tokens.colors.textSecondary,
    );
    final at = basisGlyph.isEmpty ? -1 : basis.indexOf(basisGlyph);
    if (at < 0) return TextSpan(text: basis, style: style);
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: basis.substring(0, at)),
        TextSpan(
          text: basisGlyph,
          style: TextStyle(
            fontFamily: tokens.typography.hanjaPillar.fontFamily,
          ),
        ),
        TextSpan(text: basis.substring(at + basisGlyph.length)),
      ],
    );
  }
}
