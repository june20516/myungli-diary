import 'package:flutter/material.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/text/keep_all.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';

/// 대운·세운 표의 십성·12운성 라벨 하나(`term-token` `label`, V49).
@immutable
final class LuckLabel {
  /// [text](사전 이름, 없으면 한자)를 보이는 라벨. [onTap]이 없으면 누를 수 없는 글자입니다.
  const new(this.text, {this.onTap});

  /// 보이는 글자.
  final String text;

  /// 누르면 풀이 시트를 엽니다. null이면 칩 없이 글자만 둡니다(한자 대체).
  final VoidCallback? onTap;
}

/// 칸 폭 라벨의 최대 줄 수.
const int luckLabelMaxLines = 2;

/// 칩 좌우 안쪽 여백(`term-token` `label`). 글자는 칸 폭에서 이만큼 뺀 폭에 놓입니다.
const double _paddingX = 4;

/// 폭 [width] 칸 안에서 [text] 라벨의 글자 스타일.
///
/// 기본은 `type.caption.md`이고, 낱말 하나가 글자 폭보다 넓으면 `type.caption.sm`으로
/// 줄입니다(말줄임 없음).
TextStyle luckLabelStyle(BuildContext context, String text, double width) {
  final typography = context.tokens.typography;
  final available = width - _paddingX * 2;
  final scaler = MediaQuery.textScalerOf(context);
  final direction = Directionality.of(context);
  final base = typography.captionMd;
  final tooWide = text.split(RegExp(r'\s+')).any((word) {
    final painter = TextPainter(
      text: TextSpan(text: word, style: _effective(context, base)),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final wide = painter.width > available;
    painter.dispose();
    return wide;
  });
  return tooWide ? typography.captionSm : base;
}

/// 폭 [width] 칸 안 [label]의 높이. 없으면 0입니다. 같은 줄 칸의 높이를 맞출 때 씁니다.
double luckLabelHeight(BuildContext context, LuckLabel? label, double width) {
  if (label == null) return 0;
  final style = luckLabelStyle(context, label.text, width);
  final painter = TextPainter(
    text: TextSpan(
      children: keepAllSpans(Localizations.localeOf(context), label.text),
      style: _effective(context, style),
    ),
    textDirection: Directionality.of(context),
    textAlign: TextAlign.center,
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: luckLabelMaxLines,
    locale: Localizations.maybeLocaleOf(context),
    textHeightBehavior:
        DefaultTextHeightBehavior.maybeOf(context) ??
        DefaultTextStyle.of(context).textHeightBehavior,
  )..layout(maxWidth: width - _paddingX * 2);
  final height = painter.height;
  painter.dispose();
  return height;
}

/// [Text]가 실제로 쓰는 스타일(주변 [DefaultTextStyle]에 합친 것).
TextStyle _effective(BuildContext context, TextStyle style) =>
    DefaultTextStyle.of(context).style.merge(style);

/// 폭 [width] 칸 가운데의 라벨. 낱말 단위로 두 줄까지 줄을 바꾸고, 넘치는 낱말은 글자를
/// 줄입니다([luckLabelStyle]). 누를 수 있으면 `term-token` `label` 칩입니다.
class LuckLabelView extends StatelessWidget {
  /// 라벨을 그립니다.
  const new({required this.label, required this.width, super.key});

  /// 라벨.
  final LuckLabel label;

  /// 칸 폭.
  final double width;

  @override
  Widget build(BuildContext context) {
    final style = luckLabelStyle(context, label.text, width);
    final onTap = label.onTap;
    if (onTap != null) {
      return TermToken(
        label: label.text,
        variant: TermTokenVariant.label,
        onTap: onTap,
        textStyle: style,
        textAlign: TextAlign.center,
        maxLines: luckLabelMaxLines,
      );
    }
    final colors = context.tokens.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _paddingX),
      child: Text.rich(
        TextSpan(
          children: keepAllSpans(Localizations.localeOf(context), label.text),
        ),
        style: style.copyWith(color: colors.textSecondary),
        textAlign: TextAlign.center,
        maxLines: luckLabelMaxLines,
        overflow: TextOverflow.clip,
      ),
    );
  }
}
