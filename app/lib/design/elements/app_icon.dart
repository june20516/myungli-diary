import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

/// 아이콘 굵기. 평소·미선택은 [light], 선택은 [regular]입니다.
///
/// Bold·Thin·Duotone은 두지 않습니다. Fill은 경고 표시([AppIcon.caution])만
/// 쓰므로 이 타입으로는 고를 수 없습니다.
enum AppIconWeight {
  /// 평소·미선택.
  light,

  /// 선택.
  regular,
}

/// 아이콘 크기 단계(`elements.json` `icon.scale`, `size.icon.*` 토큰).
enum AppIconSize {
  /// `size.icon.16`: 글자 14 이하 옆, 줄 끝 화살표.
  s16(IconSizeTokens.s16),

  /// `size.icon.20`: 글자 15~18 옆, 목록 줄 앞.
  s20(IconSizeTokens.s20),

  /// `size.icon.24`: 글자 19~22 옆, 탭 바, 위 막대.
  s24(IconSizeTokens.s24),

  /// `size.icon.28`: 그 위 글자 옆, 상태 화면.
  s28(IconSizeTokens.s28);

  new(this.logical);

  /// 논리 픽셀.
  final double logical;

  /// 글자 옆 아이콘 크기(`elements.json` `icon.adjacentText`).
  ///
  /// [fontSize]는 기기 글자 배율을 곱하기 전의 기본 글자 크기입니다.
  static AppIconSize adjacentText(double fontSize) {
    if (fontSize <= 14) return s16;
    if (fontSize <= 18) return s20;
    if (fontSize <= 22) return s24;
    return s28;
  }
}

/// 같은 글리프의 Light·Regular 한 쌍.
///
/// 굵기마다 별도 글꼴이라 `const IconData`로 둬야 릴리스 빌드의 아이콘 트리 셰이킹이
/// 됩니다. 그래서 굵기를 런타임에 바꿔 만들지 않고 쌍으로 넘깁니다.
@immutable
final class AppGlyph {
  /// 한 글리프의 두 굵기.
  const new({required this.light, required this.regular});

  /// 평소·미선택 굵기.
  final IconData light;

  /// 선택 굵기.
  final IconData regular;
}

/// Phosphor 아이콘(2.1.2, `phosphor_glyphs`). 굵기는 [weight]가 정합니다.
///
/// 패키지는 `phosphor_flutter`가 아니라 `phosphor_glyphs`입니다.
/// `phosphor_flutter` 2.1.0은 `IconData`를 상속해 Flutter 3.47에서 컴파일되지 않습니다.
class AppIcon extends StatelessWidget {
  /// 평소 Light 또는 선택 Regular 아이콘.
  const new(
    this.icon, {
    this.size = AppIconSize.s24,
    this.weight = AppIconWeight.light,
    this.color,
    this.semanticLabel,
    this.scalesWithText = false,
    this.textScaleMax,
    super.key,
  }) : _caution = false;

  /// 경고 표시(`mark.caution`): `warning-circle` Fill.
  ///
  /// 크기는 [size]를 주면 그 단계로 고정하고(대화상자 제목 앞 20), 없으면 주변 글자의
  /// 기본 크기에서 [AppIconSize.adjacentText]로 고른 단계에 기기 글자 배율을 곱합니다.
  /// 색은 주변 글자색을 따릅니다.
  const new caution({this.size, this.semanticLabel, super.key})
    : icon = _cautionGlyph,
      weight = AppIconWeight.light,
      color = null,
      scalesWithText = false,
      textScaleMax = null,
      _caution = true;

  /// 글자 옆 아이콘의 굵기(`elements.json` `icon.adjacentTextWeight`): 옆 글자가
  /// 400~500이면 [AppIconWeight.light], 600 이상이면 [AppIconWeight.regular]입니다.
  static AppIconWeight weightFor(FontWeight textWeight) =>
      textWeight.value >= 600 ? AppIconWeight.regular : AppIconWeight.light;

  /// 그릴 글리프.
  final AppGlyph icon;

  /// 크기 단계. [AppIcon.caution]에서만 비어 있을 수 있고, 그때는 주변 글자로 고릅니다.
  final AppIconSize? size;

  /// 굵기.
  final AppIconWeight weight;

  /// 색. 없으면 놓인 곳의 [IconTheme] 색.
  final Color? color;

  /// 스크린리더 라벨. 없으면 꾸밈 아이콘으로 읽지 않습니다.
  final String? semanticLabel;

  /// 그리는 크기에 기기 글자 배율을 곱할지(`icon.textScale.adjacent-text`, A111).
  ///
  /// 글자 옆 아이콘만 켭니다. 탭 바, 위 막대, 목록 줄 앞, 빈 화면, 키보드 내리기는
  /// 배율을 따르지 않습니다.
  final bool scalesWithText;

  /// [scalesWithText]일 때 배율 상한. 없으면 기기 배율 그대로입니다.
  final double? textScaleMax;

  final bool _caution;

  @override
  Widget build(BuildContext context) {
    if (_caution) {
      final style = DefaultTextStyle.of(context).style;
      final fixed = size;
      final baseSize =
          fixed ?? AppIconSize.adjacentText(style.fontSize ?? kDefaultFontSize);
      return Icon(
        PhosphorIconsFill.warningCircle,
        size: fixed == null
            ? _scaled(context, baseSize.logical)
            : fixed.logical,
        color: style.color,
        semanticLabel: semanticLabel,
      );
    }
    final logical = size!.logical;
    return Icon(
      switch (weight) {
        AppIconWeight.light => icon.light,
        AppIconWeight.regular => icon.regular,
      },
      size: scalesWithText ? _scaled(context, logical) : logical,
      color: color,
      semanticLabel: semanticLabel,
    );
  }

  double _scaled(BuildContext context, double logical) {
    final scaled = MediaQuery.textScalerOf(context).scale(logical);
    final max = textScaleMax;
    return max == null ? scaled : math.min(scaled, logical * max);
  }
}

// 경고 표시는 Fill 한 가지뿐이라 쌍의 두 값을 같게 둡니다.
const AppGlyph _cautionGlyph = AppGlyph(
  light: PhosphorIconsFill.warningCircle,
  regular: PhosphorIconsFill.warningCircle,
);
