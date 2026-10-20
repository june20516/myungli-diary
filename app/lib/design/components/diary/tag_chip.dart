import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/tag.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/components/sentence/vertical_hit_slop.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// [TagChip] 변형(`tag-chip` `variants`): 엔진이 준 태그의 길흉.
enum TagChipVariant {
  /// 길한 태그. `tag.good.bg` 채움.
  good,

  /// 흉한 태그. `tag.bad.bg` 채움.
  bad,

  /// 중립 태그. 바탕 없이 1px `tag.neutral.border`.
  neutral;

  /// 계약 `Tag.polarity`의 변형.
  static TagChipVariant ofPolarity(TagPolarityEnum polarity) =>
      switch (polarity) {
        TagPolarityEnum.good => good,
        TagPolarityEnum.bad => bad,
        TagPolarityEnum.neutral => neutral,
      };
}

/// 명리 태그 칩(`tag-chip`): "#이름" 알약, 톤은 태그 길흉.
///
/// 목록(`diary-row`)·보기·저장 순간에 같은 컴포넌트를 씁니다. 누르면 태그 모아보기로 가는
/// 링크이고([onTap]), 없으면 누를 수 없는 표시입니다. 스크린리더는 "#이름, 길흉 낱말"로
/// 읽어 색 없이도 길흉이 전해집니다. 보이는 높이는 26(최소, 글자가 커지면 늘어남)이고 눌림
/// 판정만 위아래로 넓혀 44를 맞춥니다.
class TagChip extends StatelessWidget {
  /// [name](태그 이름, `Glossary.values.tag`) 칩을 만듭니다.
  const new({
    required this.name,
    required this.variant,
    this.onTap,
    this.identifier,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'tag-chip',
    {'good', 'bad', 'neutral'},
    {'pressed', 'appearing'},
  );

  /// 칩 바탕을 그리는 상자를 찾는 테스트용 키.
  static const Key surfaceKey = ValueKey('tag-chip-surface');

  /// 칩 높이(`parts.chip.height`, 최소 높이).
  static const double height = 26;

  static const double _fontSize = 12;
  static const double _paddingX = 10;
  static const BorderRadius _radius = BorderRadius.all(
    Radius.circular(Radii.full),
  );

  /// 태그 이름.
  final String name;

  /// 변형(길흉).
  final TagChipVariant variant;

  /// 눌렀을 때(태그 모아보기). null이면 누를 수 없습니다.
  final VoidCallback? onTap;

  /// IA 슬롯 id. 있으면 Semantics `identifier`로 붙입니다.
  final String? identifier;

  String _polarityWord(AppLocalizations l10n) => switch (variant) {
    TagChipVariant.good => l10n.tagChipPolarityGood,
    TagChipVariant.bad => l10n.tagChipPolarityBad,
    TagChipVariant.neutral => l10n.tagChipPolarityNeutral,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.tokens.colors;
    final (Color? bg, Color fg, BoxBorder? border) = switch (variant) {
      TagChipVariant.good => (colors.tagGoodBg, colors.tagGoodFg, null),
      TagChipVariant.bad => (colors.tagBadBg, colors.tagBadFg, null),
      TagChipVariant.neutral => (
        null,
        colors.tagNeutralFg,
        Border.all(color: colors.tagNeutralBorder),
      ),
    };
    final text = l10n.tagChipLabel(name);
    final surface = DecoratedBox(
      key: surfaceKey,
      decoration: BoxDecoration(
        color: bg,
        border: border,
        borderRadius: _radius,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: height),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _paddingX),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              text,
              style: context.tokens.typography.labelMd.copyWith(
                fontSize: _fontSize,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
    final label = '$text${l10n.a11yListSeparator}${_polarityWord(l10n)}';
    final tap = onTap;
    if (tap == null) {
      return Semantics(
        container: true,
        identifier: identifier,
        label: label,
        child: ExcludeSemantics(child: surface),
      );
    }
    return VerticalHitSlop(
      child: PressInkTarget(
        semanticLabel: label,
        identifier: identifier,
        link: true,
        onTap: tap,
        inkColor: fg,
        borderRadius: _radius,
        child: surface,
      ),
    );
  }
}
