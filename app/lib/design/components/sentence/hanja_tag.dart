import 'package:flutter/material.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/components/sentence/vertical_hit_slop.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// `hanja-tag` 톤. 알약 바탕과 이름 글자색을 정합니다.
enum HanjaTagTone {
  /// 사주 용어(십성 묶음, 합충형, 신살)의 기본 초록(`term.*`).
  term,

  /// 귀인의 날(`tag.good.*`, `emphasis`는 `badge.gwiin.*`).
  gwiin,

  /// 용신의 날(`tag.good.*`, `emphasis`는 `badge.good.*` 진한 채움).
  yongsin,

  /// 기신의 날(`tag.bad.*`, `emphasis`는 `badge.gisin.*`).
  gisin,

  /// 평범한 날(바탕 없음, 1px 테두리).
  ordinary,

  /// 길흉 톤 좋음(`tag.good.*`). `fortune-verdict`와 `score-row` 안에서만 씁니다.
  good,

  /// 길흉 톤 나쁨(`tag.bad.*`). `fortune-verdict`와 `score-row` 안에서만 씁니다.
  bad,
}

/// `hanja-tag` 변형. 계약 변형 id `default`는 Dart 예약어라 [normal]로 씁니다.
enum HanjaTagVariant {
  /// 기본(`default`).
  normal,

  /// 날의 성격 강조(`emphasis`). 날의 성격 톤에만 씁니다.
  emphasis,

  /// 고른 태그(`selected`). 둘레 1.5px `action.primary`.
  selected,

  /// 간지 한 글자(`ganji`). 오행 색을 씁니다.
  ganji,
}

/// 한자 아이콘 태그(`hanja-tag`): 원 안 한자 한 글자와 이름 알약.
///
/// 사주 용어는 어디서나 이 모양입니다(D108 ②, V70). [onTap]이 있으면 누르는 자리
/// (`press.ink`, 눌림 영역은 위아래로 44까지)이고, 없으면 누를 수 없는 표시입니다
/// (근거 시트·사주 기운 시트 머리, 색 규칙 시트 점수 항목, 시진 태그). 한자 원은
/// 장식이라 스크린리더는 [label]만 읽습니다. 길흉은 이름 낱말로 전하고 색만으로 전하지
/// 않습니다.
class HanjaTag extends StatelessWidget {
  /// 태그를 만듭니다.
  const new({
    required this.glyph,
    required this.label,
    this.tone = HanjaTagTone.term,
    this.variant = HanjaTagVariant.normal,
    this.onTap,
    super.key,
  }) : assert(
         variant != HanjaTagVariant.emphasis ||
             (tone != HanjaTagTone.term &&
                 tone != HanjaTagTone.good &&
                 tone != HanjaTagTone.bad),
         'emphasis는 날의 성격 톤(gwiin, yongsin, gisin, ordinary)에만 씁니다',
       );

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'hanja-tag',
    {'default', 'emphasis', 'selected', 'ganji'},
    {'loading', 'pressed'},
  );

  /// 알약 면을 찾는 테스트용 키.
  static const Key surfaceKey = ValueKey('hanja-tag-surface');

  /// 한자 원을 찾는 테스트용 키.
  static const Key glyphKey = ValueKey('hanja-tag-glyph');

  /// 알약 높이(기본 글자 크기에서의 높이). 계약 `sentence.json` `hanja-tag.parts.pill.height`.
  /// 기기 글자가 커지면 이름 글자와 함께 커집니다.
  static const double height = 30;

  /// 한자 원 지름. 계약 `hanja-tag.parts.glyph.size`.
  static const double glyphSize = 22;

  /// 한자 크기. 계약 `hanja-tag.parts.glyph.fontSize`.
  static const double glyphFontSize = 12;

  /// 알약 왼쪽 안쪽 여백. 계약 `hanja-tag.parts.pill.paddingStart`(`space.4`).
  static const double paddingStart = Space.s4;

  /// 알약 오른쪽 안쪽 여백. 계약 `hanja-tag.parts.pill.paddingEnd`(`space.12`).
  static const double paddingEnd = Space.s12;

  /// 한자 원과 이름 사이. 계약 `hanja-tag.parts.pill.gap`(`space.4`).
  static const double gap = Space.s4;

  /// 선택 둘레 굵기. 계약 `hanja-tag.variants.selected` `pill.border.width`.
  static const double selectedBorderWidth = 1.5;

  /// skeleton 알약 폭. 계약 `hanja-tag.states.loading.skeleton`.
  static const double skeletonWidth = 64;

  /// 간지 한 글자 → 오행. 계약 `hanja-tag.variants.ganji.parts.ganjiGlyphs`.
  static const Map<String, _Element> _ganjiElements = {
    '甲': _Element.wood,
    '乙': _Element.wood,
    '丙': _Element.fire,
    '丁': _Element.fire,
    '戊': _Element.earth,
    '己': _Element.earth,
    '庚': _Element.metal,
    '辛': _Element.metal,
    '壬': _Element.water,
    '癸': _Element.water,
    '寅': _Element.wood,
    '卯': _Element.wood,
    '巳': _Element.fire,
    '午': _Element.fire,
    '辰': _Element.earth,
    '戌': _Element.earth,
    '丑': _Element.earth,
    '未': _Element.earth,
    '申': _Element.metal,
    '酉': _Element.metal,
    '亥': _Element.water,
    '子': _Element.water,
  };

  /// 원 안 한자 한 글자.
  final String glyph;

  /// 이름 글자(ARB 문구). 스크린리더가 읽는 유일한 글자입니다.
  final String label;

  /// 톤. `ganji` 변형에서는 쓰지 않습니다(글자의 오행 색).
  final HanjaTagTone tone;

  /// 변형.
  final HanjaTagVariant variant;

  /// 눌렀을 때(`explain-sheet`나 `tag-sheet` 열기). null이면 누를 수 없는 표시입니다.
  final VoidCallback? onTap;

  /// 로딩 자리(`states.loading.skeleton`): 폭 64, 높이 30의 알약 뼈.
  static Widget skeleton({int index = 0, bool animated = true}) => SkeletonBone(
    width: skeletonWidth,
    height: height,
    borderRadius: Radii.full,
    index: index,
    animated: animated,
  );

  _TagColors _colors(ColorTokens colors) {
    if (variant == HanjaTagVariant.ganji) {
      final (bg, fg) = switch (_ganjiElements[glyph]!) {
        _Element.wood => (colors.ohaengWoodBg, colors.ohaengWoodFg),
        _Element.fire => (colors.ohaengFireBg, colors.ohaengFireFg),
        _Element.earth => (colors.ohaengEarthBg, colors.ohaengEarthFg),
        _Element.metal => (colors.ohaengMetalBg, colors.ohaengMetalFg),
        _Element.water => (colors.ohaengWaterBg, colors.ohaengWaterFg),
      };
      return _TagColors(bg: bg, fg: fg, glyph: fg);
    }
    if (variant == HanjaTagVariant.emphasis) {
      final badge = dayCharacterBadgeColors(switch (tone) {
        HanjaTagTone.yongsin => DayCharacterVariant.good,
        HanjaTagTone.gwiin => DayCharacterVariant.gwiin,
        HanjaTagTone.gisin => DayCharacterVariant.gisin,
        _ => DayCharacterVariant.ordinary,
      }, colors);
      return _TagColors(
        bg: badge.bg,
        fg: badge.fg,
        border: badge.border,
        // 용신의 날은 이름이 흰 글자라 흰 원 안 한자를 알약 바탕색으로 그립니다(V78).
        glyph: tone == HanjaTagTone.yongsin ? colors.badgeGoodBg : badge.fg,
      );
    }
    final base = switch (tone) {
      HanjaTagTone.term => _TagColors(bg: colors.termBg, fg: colors.termFg),
      HanjaTagTone.gwiin || HanjaTagTone.yongsin || HanjaTagTone.good =>
        _TagColors(bg: colors.tagGoodBg, fg: colors.tagGoodFg),
      HanjaTagTone.gisin ||
      HanjaTagTone.bad => _TagColors(bg: colors.tagBadBg, fg: colors.tagBadFg),
      HanjaTagTone.ordinary => _TagColors(
        fg: colors.tagNeutralFg,
        border: colors.tagNeutralBorder,
      ),
    };
    return base;
  }

  @override
  Widget build(BuildContext context) {
    assert(
      variant != HanjaTagVariant.ganji || _ganjiElements.containsKey(glyph),
      'ganji는 천간 10자, 지지 12자만 그립니다',
    );
    final tokens = context.tokens;
    final colors = _colors(tokens.colors);
    final selected = variant == HanjaTagVariant.selected;
    const radius = BorderRadius.all(Radius.circular(Radii.full));

    final pill = DecoratedBox(
      key: surfaceKey,
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: radius,
        // 테두리는 안쪽에 그려 크기가 그대로입니다. 선택 테두리가 톤 테두리를 대신합니다.
        border: selected
            ? Border.all(
                color: tokens.colors.actionPrimary,
                width: selectedBorderWidth,
              )
            : colors.border == null
            ? null
            : Border.all(color: colors.border!),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: height),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: paddingStart,
            end: paddingEnd,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _GlyphCircle(glyph: glyph, color: colors.glyph),
              const SizedBox(width: gap),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.labelMd.copyWith(color: colors.fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final onTap = this.onTap;
    if (onTap == null) {
      return Semantics(
        container: true,
        label: label,
        child: ExcludeSemantics(child: pill),
      );
    }
    // 눌림 영역을 넓히는 상자는 조상이 가로채지 못하도록 가장 바깥에 둡니다.
    return VerticalHitSlop(
      child: PressInkTarget(
        semanticLabel: label,
        onTap: onTap,
        borderRadius: radius,
        inkColor: colors.fg,
        child: pill,
      ),
    );
  }
}

/// 간지 글자의 오행.
enum _Element { wood, fire, earth, metal, water }

/// 알약 색 묶음.
class _TagColors {
  const new({required this.fg, this.bg, this.border, Color? glyph})
    : glyph = glyph ?? fg;

  /// 알약 바탕(없으면 투명).
  final Color? bg;

  /// 이름 글자색.
  final Color fg;

  /// 톤 테두리(평범한 날).
  final Color? border;

  /// 한자 글자색.
  final Color glyph;
}

/// 한자 원(지름 22, `bg.sheet`). 장식이라 스크린리더는 읽지 않고, 글자 크기 설정을 따르지
/// 않아 원 안에 늘 들어갑니다.
class _GlyphCircle extends StatelessWidget {
  const new({required this.glyph, required this.color});

  final String glyph;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      key: HanjaTag.glyphKey,
      decoration: BoxDecoration(
        color: tokens.colors.bgSheet,
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: HanjaTag.glyphSize,
        height: HanjaTag.glyphSize,
        child: Center(
          child: Text(
            glyph,
            textScaler: TextScaler.noScaling,
            style: tokens.typography.hanjaPillar.copyWith(
              fontSize: HanjaTag.glyphFontSize,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
