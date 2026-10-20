import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/theme/ohaeng_colors.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 오행 분포의 한 오행.
@immutable
final class OhaengBarItem {
  /// [element]의 이름 [name]과 값 [value], 범례에 보일 개수 글자 [count].
  const new({
    required this.element,
    required this.name,
    required this.value,
    required this.count,
  });

  /// 오행.
  final FiveElement element;

  /// 오행 이름(용어 사전).
  final String name;

  /// 막대 칸 길이의 기준 값(0 이상).
  final double value;

  /// 범례에 보일 개수 글자(예 "2.9").
  final String count;
}

/// 오행 분포(`ohaeng-bar`): 비례 막대와 5열 범례.
///
/// 막대는 높이 10, `radius.full`, 칸 사이 2이고 칸 길이는 [OhaengBarItem.value]에
/// 비례합니다. 순서는 늘 목·화·토·금·수입니다(받은 순서와 상관없음).
///
/// 값이 0인 오행은 막대에 칸이 없고, 범례 견본이 흐리고(0.35)
/// 개수가 `text.secondary`입니다(`zero`).
///
/// 범례는 견본 12(`ohaeng.swatch` + `swatch.border`),
/// 이름 `type.caption.md`, 개수 `type.numeric.table`입니다.
/// 스크린리더는 그림 하나로 [semanticLabel]("목 N, 화 N, …")을 읽습니다.
class OhaengBar extends StatelessWidget {
  /// 분포를 만듭니다.
  const new({required this.items, required this.semanticLabel, super.key});

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('ohaeng-bar', {}, {'zero'});

  /// 막대 높이.
  static const double barHeight = 10;

  /// 막대를 찾는 테스트용 키.
  static const Key barKey = ValueKey('ohaeng-bar-bar');

  /// [element] 칸을 찾는 테스트용 키.
  static Key segmentKey(FiveElement element) =>
      ValueKey('ohaeng-bar-${element.value}');

  /// 막대 칸 사이.
  static const double segmentGap = 2;

  /// 범례 견본 크기.
  static const double swatchSize = 12;

  /// 오행 다섯(순서 무관, 빠진 오행은 0으로 봄).
  final List<OhaengBarItem> items;

  /// 스크린리더 라벨.
  final String semanticLabel;

  /// 목·화·토·금·수 순서로 맞춘 항목.
  List<OhaengBarItem> get ordered => [
    for (final element in FiveElement.values)
      for (final item in items)
        if (item.element == element) item,
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final ordered = this.ordered;
    final filled = [
      for (final item in ordered)
        if (item.value > 0) item,
    ];
    return Semantics(
      container: true,
      image: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            key: barKey,
            height: barHeight,
            child: Row(
              // 자식 없는 칸이 막대 높이를 그대로 받게 합니다(가운데 정렬이면 높이 0).
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, item) in filled.indexed) ...[
                  if (index > 0) const SizedBox(width: segmentGap),
                  Expanded(
                    flex: (item.value * 100).round().clamp(1, 1 << 30),
                    child: DecoratedBox(
                      key: segmentKey(item.element),
                      decoration: BoxDecoration(
                        color: ohaengSwatchOf(colors, item.element),
                        // 막대 전체가 알약(`radius.full`)이 되도록 양 끝 칸만 둥글게 합니다.
                        borderRadius: BorderRadiusDirectional.horizontal(
                          start: index == 0
                              ? const Radius.circular(barHeight / 2)
                              : Radius.zero,
                          end: index == filled.length - 1
                              ? const Radius.circular(barHeight / 2)
                              : Radius.zero,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Space.s12),
          Row(
            children: [
              for (final item in ordered) Expanded(child: _Legend(item: item)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const new({required this.item});

  final OhaengBarItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final zero = item.value <= 0;
    return Column(
      children: [
        Opacity(
          opacity: zero ? 0.35 : 1,
          child: Container(
            width: OhaengBar.swatchSize,
            height: OhaengBar.swatchSize,
            decoration: BoxDecoration(
              color: ohaengSwatchOf(colors, item.element),
              shape: BoxShape.circle,
              border: Border.all(color: colors.swatchBorder),
            ),
          ),
        ),
        const SizedBox(height: Space.s4),
        Text(
          item.name,
          style: tokens.typography.captionMd.copyWith(
            color: colors.textPrimary,
          ),
        ),
        Text(
          item.count,
          style: tokens.typography.numericTable.copyWith(
            color: zero ? colors.textSecondary : colors.textPrimary,
          ),
        ),
      ],
    );
  }
}
