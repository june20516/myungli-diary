import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// [ScoreRow] 변형(`score-row` `variants`).
enum ScoreRowVariant {
  /// 그날 시트 길흉판정 내역 줄. 태그를 누르면 뜻 시트입니다.
  verdict,

  /// 색 규칙 시트의 점수 항목 표 줄. 뜻 없이 태그와 점만, 태그는 누를 수 없습니다.
  rule,
}

/// 점수 항목 한 줄(`score-row`): 한자 태그, 짧은 뜻, 부호와 점.
///
/// 점수는 숫자 대신 점입니다. 점 개수는 점수 절댓값이고 최대 [maxDots]개이며, 넘으면 점 뒤에
/// `+`를 붙입니다. 더함은 `+`와 `badge.good.bg` 점, 뺌은 `−`(U+2212)와 `text.secondary` 점이고
/// 부호는 본문색이라 색만으로 전하지 않습니다. 태그 톤은 부호를 따릅니다(더함 `good`, 뺌
/// `bad`). 스크린리더는 "이름, 뜻, 더함 둘"처럼 부호와 개수를 낱말로 읽고 점은 읽지 않습니다.
/// [ScoreRow.verdict]의 태그는 그 묶음 안에서 따로 버튼입니다.
class ScoreRow extends StatelessWidget {
  /// 그날 시트 내역 줄. [onTagTap]이 null이면 태그를 누를 수 없습니다.
  const new verdict({
    required this.glyph,
    required this.name,
    required this.meaning,
    required this.score,
    this.tone,
    this.onTagTap,
    super.key,
  }) : variant = ScoreRowVariant.verdict;

  /// 색 규칙 시트 표 줄. 뜻이 없고 태그는 누를 수 없으며 위아래 `space.8`입니다.
  const new rule({
    required this.glyph,
    required this.name,
    required this.score,
    super.key,
  }) : variant = ScoreRowVariant.rule,
       meaning = null,
       tone = null,
       onTagTap = null;

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'score-row',
    {'verdict', 'rule'},
    {'loading', 'pressed'},
  );

  /// 줄 최소 높이(`parts.row.minHeight`, `verdict`만).
  static const double minHeight = 48;

  /// 점 지름. 계약 `score-row.parts.dots.size`.
  static const double dotSize = 8;

  /// 점 사이와 부호 뒤 간격. 계약 `dots.gap`·`dots.marginStart`는 `space.4`
  /// (spec의 3은 토큰이 아님, V56).
  static const double dotGap = Space.s4;

  /// `verdict`에서 태그가 가질 수 있는 최대 폭(태그와 뜻 자리의 비율).
  static const double tagMaxWidthFactor = 0.5;

  /// 뜻 칸(앞 여백 포함)을 찾는 테스트용 키.
  static const Key meaningCellKey = ValueKey('score-row-meaning-cell');

  /// 점 최대 개수(`dots.max`).
  static const int maxDots = 3;

  /// 로딩 뼈의 점 자리 폭(점 [maxDots]개와 사이).
  static const double skeletonDotsWidth = 3 * dotSize + 2 * dotGap;

  /// 점 묶음을 찾는 테스트용 키. 점은 이 안의 [DecoratedBox]입니다.
  static const Key dotsKey = ValueKey('score-row-dots');

  /// 넘침 표시 `+` 글자를 찾는 테스트용 키.
  static const Key overflowKey = ValueKey('score-row-overflow');

  /// 부호 글자를 찾는 테스트용 키.
  static const Key signKey = ValueKey('score-row-sign');

  /// 뜻 글자를 찾는 테스트용 키.
  static const Key meaningKey = ValueKey('score-row-meaning');

  /// 더함 부호(U+002B).
  static const String plusSign = '+';

  /// 뺌 부호(U+2212).
  static const String minusSign = '−';

  /// 변형.
  final ScoreRowVariant variant;

  /// 태그 원 안 한자.
  final String glyph;

  /// 항목 이름(태그 글자).
  final String name;

  /// 짧은 뜻. `rule`은 null입니다.
  final String? meaning;

  /// 점수. 0보다 크면 더함, 작으면 뺌입니다.
  final int score;

  /// 태그 톤. null이면 부호를 따릅니다.
  final HanjaTagTone? tone;

  /// 태그를 눌렀을 때(`verdict`만).
  final VoidCallback? onTagTap;

  /// 점수 [score]의 점 개수(`min(|score|, 3)`).
  static int dotCountOf(int score) => math.min(score.abs(), maxDots);

  /// 점수 [score]의 점이 [maxDots]를 넘어 `+`를 붙이는지.
  static bool overflowsOf(int score) => score.abs() > maxDots;

  /// 로딩 자리(`states.loading.skeleton`): 알약 뼈 + 글줄 + 점 자리. `verdict` 줄 높이입니다.
  static Widget skeleton({int index = 0, bool animated = true}) =>
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.s12),
          child: Row(
            children: [
              HanjaTag.skeleton(index: index, animated: animated),
              const SizedBox(width: Space.s12),
              Expanded(
                child: SkeletonBone(
                  height: SkeletonBone.lineHeight,
                  borderRadius: Radii.sm,
                  index: index + 1,
                  animated: animated,
                ),
              ),
              const SizedBox(width: Space.s12),
              SkeletonBone(
                width: skeletonDotsWidth,
                height: dotSize,
                borderRadius: Radii.full,
                index: index + 2,
                animated: animated,
              ),
            ],
          ),
        ),
      );

  bool get _plus => score > 0;

  String _semanticLabel(AppLocalizations l10n) {
    // 계약 a11y.label("더함 둘")대로 읽는 개수는 보이는 점 개수와 같습니다.
    final count = dotCountOf(score);
    final change = _plus
        ? l10n.daySheetVerdictItemPlus(count)
        : l10n.daySheetVerdictItemMinus(count);
    final meaning = this.meaning;
    return [
      name,
      if (meaning != null && meaning.isNotEmpty) meaning,
      change,
    ].join(l10n.a11yListSeparator);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final colors = tokens.colors;
    final type = tokens.typography;
    final isVerdict = variant == ScoreRowVariant.verdict;
    final meaning = this.meaning;
    final tag = HanjaTag(
      glyph: glyph,
      label: name,
      tone: tone ?? (_plus ? HanjaTagTone.good : HanjaTagTone.bad),
      onTap: onTagTap,
    );
    final dotColor = _plus ? colors.badgeGoodBg : colors.textSecondary;
    final signStyle = type.labelLg.copyWith(
      color: colors.textPrimary,
      fontWeight: FontWeight.w700,
    );
    final trailing = ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: dotGap,
        children: [
          Text(_plus ? plusSign : minusSign, key: signKey, style: signStyle),
          Row(
            key: dotsKey,
            mainAxisSize: MainAxisSize.min,
            spacing: dotGap,
            children: [
              for (var i = 0; i < dotCountOf(score); i++)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(width: dotSize, height: dotSize),
                ),
            ],
          ),
          if (overflowsOf(score))
            Text(plusSign, key: overflowKey, style: signStyle),
        ],
      ),
    );
    final row = Row(
      children: [
        if (isVerdict) ...[
          // 태그는 따로 버튼이라 묶음 라벨 밖에 둡니다. 태그는 제 폭을 쓰되 남은 폭의 절반까지만
          // 커지고(넘으면 이름 한 줄 말줄임, hanja-tag 이름 maxLines 1), 뜻이 나머지를 모두 씁니다.
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * tagMaxWidthFactor,
                    ),
                    child: tag,
                  ),
                  Expanded(
                    child: Padding(
                      key: meaningCellKey,
                      padding: const EdgeInsetsDirectional.only(
                        start: Space.s12,
                      ),
                      child: ExcludeSemantics(
                        child: Text(
                          meaning ?? '',
                          key: meaningKey,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: type.captionLg.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          // 누를 수 없는 표시라 묶음 라벨이 이름을 읽고 태그 글자는 읽지 않습니다.
          Expanded(
            child: Row(
              children: [Flexible(child: ExcludeSemantics(child: tag))],
            ),
          ),
        ],
        // 태그(또는 뜻)와 부호 사이 `sign.marginStart`(space.12)를 늘 남깁니다.
        const SizedBox(width: Space.s12),
        trailing,
      ],
    );
    return Semantics(
      container: true,
      label: _semanticLabel(l10n),
      child: isVerdict
          ? ConstrainedBox(
              constraints: const BoxConstraints(minHeight: minHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.s12),
                child: row,
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.s8),
              child: row,
            ),
    );
  }
}
