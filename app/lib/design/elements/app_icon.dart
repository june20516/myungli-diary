import 'package:flutter/material.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

/// 아이콘 굵기. 평소·미선택은 [light], 선택은 [regular]입니다.
///
/// [fill]은 경고 표시(`mark.caution`) 전용이라 [AppIcon.caution]만 씁니다.
/// Bold·Thin·Duotone은 아예 두지 않습니다.
enum AppIconWeight {
  /// 평소·미선택.
  light,

  /// 선택.
  regular,

  /// 경고 표시 전용.
  fill,
}

/// 아이콘 크기(`elements.json` `icon.sizes`).
enum AppIconSize {
  /// 탭 바.
  tab(24),

  /// 앱 바.
  bar(24),

  /// 글줄 안.
  inline(16),

  /// 상태 화면.
  state(28);

  new(this.logical);

  /// 논리 픽셀.
  final double logical;
}

// 경고 표시는 Fill 한 가지뿐이라 쌍의 두 값을 같게 둡니다.
const AppGlyph _cautionGlyph = AppGlyph(
  light: PhosphorIconsFill.warningCircle,
  regular: PhosphorIconsFill.warningCircle,
);

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
    this.size = AppIconSize.bar,
    this.weight = AppIconWeight.light,
    this.color,
    this.semanticLabel,
    super.key,
  }) : assert(
         weight != AppIconWeight.fill,
         'fill은 경고 표시(mark.caution) 전용입니다. AppIcon.caution을 쓰세요.',
       );

  /// 경고 표시(`mark.caution`): `warning-circle` Fill. 색은 놓인 글자색을 따릅니다.
  const new caution({
    this.size = AppIconSize.inline,
    this.color,
    this.semanticLabel,
    super.key,
  }) : icon = _cautionGlyph,
       weight = AppIconWeight.fill;

  /// 그릴 글리프.
  final AppGlyph icon;

  /// 크기.
  final AppIconSize size;

  /// 굵기.
  final AppIconWeight weight;

  /// 색. 없으면 놓인 곳의 [IconTheme] 색.
  final Color? color;

  /// 스크린리더 라벨. 없으면 꾸밈 아이콘으로 읽지 않습니다.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Icon(
      switch (weight) {
        AppIconWeight.light => icon.light,
        AppIconWeight.regular => icon.regular,
        AppIconWeight.fill => PhosphorIconsFill.warningCircle,
      },
      size: size.logical,
      color: color,
      semanticLabel: semanticLabel,
    );
  }
}
