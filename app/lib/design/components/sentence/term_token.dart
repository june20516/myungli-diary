import 'package:flutter/material.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/components/sentence/vertical_hit_slop.dart';
import 'package:myungli_diary/design/text/keep_all.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 용어 표시 변형.
enum TermTokenVariant {
  /// 문장 안: 놓인 글자 스타일 그대로, 가로 3px.
  inline,

  /// 표 행 머리·십성 줄: `type.caption.md`, 가로 4px.
  label,
}

/// 명리 용어 표시(`term-token`). 누르면 풀이 시트를 엽니다.
///
/// 바탕 `term.bg`, 글자 `term.fg`, `radius.xs`이고 굵게 하지 않습니다(결정 V0).
/// 터치 영역은 글자 높이가 낮아도 위아래로 44px까지 넓습니다. 스크린리더 라벨은
/// "용어 + 풀이 보기"이며 풀이를 찾는 `term` 값은 읽지 않습니다.
///
/// 명세 2.0.0에서 `locked` 상태는 빠졌습니다. 풀이 시트는 무료라 늘 눌립니다(D60).
class TermToken extends StatelessWidget {
  /// 용어 토큰을 만듭니다.
  const new({
    required this.label,
    required this.variant,
    required this.onTap,
    this.textStyle,
    this.before,
    this.after,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'term-token',
    {'inline', 'label'},
    {'pressed'},
  );

  /// 화면에 보이는 용어 글자(풀이 키가 아닙니다).
  final String label;

  /// 변형.
  final TermTokenVariant variant;

  /// 눌렀을 때(풀이 시트 열기).
  final VoidCallback onTap;

  /// 글자 스타일. `inline`은 문장 스타일을 넘기고, 없으면 주변 [DefaultTextStyle]입니다.
  /// `label`은 무시하고 `type.caption.md`를 씁니다.
  final TextStyle? textStyle;

  /// 칩 바로 앞에 공백 없이 붙은 글자. 칩 밖이라 눌리지 않지만 한 덩어리로 줄이 바뀌고,
  /// 스크린리더 라벨은 칩 라벨에 묶입니다.
  final String? before;

  /// 칩 바로 뒤에 공백 없이 붙은 글자(한국어 조사). [before]와 같습니다.
  final String? after;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final tokens = context.tokens;
    final colors = tokens.colors;
    final base = switch (variant) {
      TermTokenVariant.inline =>
        textStyle ?? DefaultTextStyle.of(context).style,
      TermTokenVariant.label => tokens.typography.captionMd,
    };
    final paddingX = switch (variant) {
      TermTokenVariant.inline => 3.0,
      TermTokenVariant.label => 4.0,
    };
    const radius = BorderRadius.all(Radius.circular(Radii.xs));
    final chip = PressInkTarget(
      // 붙은 글자(조사)도 칩과 같은 낭독 정지점에 묶어 따로 읽히지 않게 합니다.
      semanticLabel: AppLocalizations.of(context)
          .termTokenSemantics('${before ?? ''}$label${after ?? ''}'),
      onTap: onTap,
      borderRadius: radius,
      inkColor: colors.termFg,
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.termBg, borderRadius: radius),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: paddingX),
          child: Text(label, style: base.copyWith(color: colors.termFg)),
        ),
      ),
    );
    // 눌림 영역을 넓히는 상자는 조상이 가로채지 못하도록 가장 바깥에 둡니다.
    if (before == null && after == null) return VerticalHitSlop(child: chip);
    return VerticalHitSlop(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          if (before != null)
            ExcludeSemantics(
              child: Text.rich(
                TextSpan(children: keepAllSpans(locale, before!)),
                style: base,
              ),
            ),
          chip,
          if (after != null)
            ExcludeSemantics(
              child: Text.rich(
                TextSpan(children: keepAllSpans(locale, after!)),
                style: base,
              ),
            ),
        ],
      ),
    );
  }
}
