import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/components/sentence/vertical_hit_slop.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/theme/ohaeng_colors.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

/// 행운 항목 변형(`lucky-card` `variants`).
enum LuckyCardVariant {
  /// 행운 색. 앞에 `ohaeng.swatch` 견본 원이 붙습니다.
  color,

  /// 행운 방향. 앞 아이콘 `compass`.
  direction,

  /// 행운 숫자. 앞 아이콘 `hash`.
  number,

  /// 행운 시간. 낮 칩과 밤 칩이 하나씩이고 앞 아이콘은 채운 해와 달입니다(`time.periods`, V115).
  time;

  /// 행운 4종(칩 줄 순서). 대표 태그 칩은 5.0.0에서 지웠습니다(V78, 사주 기운 섹션의 `hanja-tag`).
  static const List<LuckyCardVariant> luckyValues = [
    color,
    direction,
    number,
    time,
  ];
}

const AppGlyph _compass = AppGlyph(
  light: PhosphorIconsLight.compass,
  regular: PhosphorIconsRegular.compass,
);
const AppGlyph _hash = AppGlyph(
  light: PhosphorIconsLight.hash,
  regular: PhosphorIconsRegular.hash,
);

/// 색이 둘인 날(D119 ②)의 둘째 색(`DailyCards.secondColor`, 원전 기준). 칩은 첫째 색과 한 알약의
/// 두 칸으로 그립니다(`lucky-card` `color.parts.pair`, V114).
@immutable
final class LuckySecondColor {
  /// 둘째 색 값을 만듭니다.
  const new({
    required this.element,
    required this.value,
    required this.explain,
  });

  /// 둘째 색의 오행. 칸 견본 색(`ohaeng.swatch`)이 이 값을 따릅니다.
  final FiveElement element;

  /// 둘째 칸에 보이는 색 이름("노랑").
  final String value;

  /// 행운 색 시트 둘째 구역의 풀이 문장(`today.lucky-color.second.body`).
  final RenderedText explain;
}

/// 행운 항목 하나. 표시 값 변환은 이 값을 만드는 한 곳에서 합니다.
@immutable
final class LuckyItem {
  /// 행운 항목을 만듭니다. [element]는 [LuckyCardVariant.color]에서만, [period]는
  /// [LuckyCardVariant.time]에서만(필수) 씁니다. [word]는 밤 칩의 때 낱말이고, [secondColor]는
  /// 색이 둘인 날 색 칩의 둘째 색입니다.
  const new({
    required this.variant,
    required this.name,
    required this.value,
    required this.explain,
    this.element,
    this.period,
    this.word,
    this.secondColor,
  }) : assert(
         (variant == LuckyCardVariant.color) == (element != null),
         'color 변형은 element가 필수이고, 다른 변형은 element를 줄 수 없습니다.',
       ),
       assert(
         (variant == LuckyCardVariant.time) == (period != null),
         'time 변형은 period가 필수이고, 다른 변형은 period를 줄 수 없습니다.',
       ),
       assert(
         word == null || period == AppTimeOfDay.night,
         '때 낱말은 밤 칩에만 붙습니다(V116).',
       ),
       assert(
         secondColor == null || variant == LuckyCardVariant.color,
         '둘째 색은 색 칩에만 붙습니다(D119 ②).',
       );

  /// 변형.
  final LuckyCardVariant variant;

  /// 항목 이름("행운 색"). 스크린리더가 값 앞에 읽고, 설명 시트의 제목이 됩니다. 시간 칩은 그
  /// 칩의 시트 제목 슬롯이라 낮과 밤이 다르게 읽힙니다(`a11y.timeLabel`).
  final String name;

  /// 칩에 보이는 값("파랑").
  final String value;

  /// 누르면 열리는 설명 시트의 문장(server가 렌더한 조각).
  final RenderedText explain;

  /// 색 변형의 오행. 칩이 지금 테마의 견본 색(`ohaeng.swatch`)으로 그립니다.
  /// [LuckyCardVariant.color]에서만 주고(필수), 다른 변형에서는 줄 수 없습니다(assert).
  final FiveElement? element;

  /// 시간 칩의 낮과 밤(`time.periods`). 앞 아이콘(채운 해와 달)과 칩 구분이 이 값을 따릅니다.
  /// [LuckyCardVariant.time]에서만 주고(필수), 다른 변형에서는 줄 수 없습니다(assert).
  final AppTimeOfDay? period;

  /// 밤 칩 값 앞 때 낱말(`time.periods` night `word`, "새벽"이나 "오늘 밤", V116). 낮 칩과 다른
  /// 변형은 null입니다.
  final String? word;

  /// 색이 둘인 날의 둘째 색(D119 ②). 있으면 칩이 두 칸 알약이고([LuckyChip]), 색 하나인 날과
  /// 다른 변형은 null입니다. 응답의 선택 필드라 없는 것이 오류가 아닙니다.
  final LuckySecondColor? secondColor;

  /// 둘째 색을 뺀 같은 항목. 공유 이미지는 첫째 색 칸 하나라(D119 ④) 이 값을 씁니다.
  LuckyItem get withoutSecondColor => secondColor == null
      ? this
      : LuckyItem(
          variant: variant,
          name: name,
          value: value,
          explain: explain,
          element: element,
          period: period,
          word: word,
        );
}

/// 행운 칩 하나(`lucky-card` `chip`).
///
/// [onTap]이 null이면 누를 수 없는 표시 전용 칩입니다(공유 이미지). 줄([LuckyCardRow])이
/// 쓰고, 계획 6 `my-saju`의 행운 색처럼 칩만 필요한 곳도 직접 씁니다. 칩 높이 34는
/// 최소값이라 기기 글자가 커지면 함께 커지고, 누름 영역은 위아래로 44까지 넓힙니다.
class LuckyChip extends StatelessWidget {
  /// 칩을 만듭니다. [open]이면 안쪽 테두리를 그립니다.
  const new({
    required this.item,
    required this.open,
    required this.onTap,
    super.key,
  });

  /// 칩 바탕 면을 찾는 테스트용 키.
  static const Key surfaceKey = ValueKey('lucky-card-chip-surface');

  /// 색 변형 견본 원을 찾는 테스트용 키.
  static const Key swatchKey = ValueKey('lucky-card-swatch');

  /// 색이 둘인 날 알약의 [index]째 칸(0이 첫째 색)을 찾는 테스트용 키.
  static Key pairHalfKey(int index) => ValueKey('lucky-card-pair-half-$index');

  /// 색이 둘인 날 알약 두 칸 사이 세로선을 찾는 테스트용 키.
  static const Key pairDividerKey = ValueKey('lucky-card-pair-divider');

  /// 두 칸 알약 칸마다 좌우 여백(`color.parts.pair.half.paddingX` {space.12}).
  static const double pairHalfPaddingX = Space.s12;

  /// 두 칸 알약 칸 안 견본과 이름 사이(`pair.half.gap` {space.4}).
  static const double pairHalfGap = Space.s4;

  /// 두 칸 알약 칸마다 누름 자리 최소 크기(`pair.half.minTarget` 44). 높이는 칩 줄의 판정
  /// 여유([VerticalHitSlop])가, 폭은 칸의 최소 폭이 지킵니다.
  static const double pairHalfMinTarget = sentenceMinTarget;

  /// 두 칸 사이 세로선 두께(`pair.divider.width` 1px).
  static const double pairDividerWidth = 1;

  /// 두 칸 사이 세로선 높이(`pair.divider.height` 18px).
  static const double pairDividerHeight = 18;

  /// `time` 값의 글꼴 기능(`time.parts.value.fontFeatures`: tnum).
  static const List<FontFeature> timeValueFeatures = [
    FontFeature.tabularFigures(),
  ];

  static const double _height = 34;
  // 계약 `lucky-card.parts.chip.gap` {space.4}.
  static const double _gap = Space.s4;
  static const double _swatchSize = 14;
  // 계약 `lucky-card.parts.chip.border.width` 1px.
  static const double _border = 1;
  // 계약 `lucky-card.states.open.parts.chip.border.width` 1.5px.
  static const double _openBorder = 1.5;

  /// 보여 줄 항목.
  final LuckyItem item;

  /// 설명이 열려 있는지.
  final bool open;

  /// 눌렀을 때. null이면 표시 전용입니다.
  final VoidCallback? onTap;

  /// 시간 칩 [period]의 앞 아이콘 색(`time.periods` `lead.iconColor`, 토큰 1.8.0).
  static Color timeIconColorOf(ColorTokens colors, AppTimeOfDay period) =>
      switch (period) {
        AppTimeOfDay.day => colors.timeDay,
        AppTimeOfDay.night => colors.timeNight,
      };

  @override
  Widget build(BuildContext context) {
    final second = item.secondColor;
    if (second != null) {
      return _PairChipFrame(
        name: item.name,
        halves: [
          (element: item.element!, value: item.value),
          (element: second.element, value: second.value),
        ],
        open: open,
        onTap: onTap,
      );
    }
    final colors = context.tokens.colors;
    // `lucky-card` `lead.iconSize`: adjacent-text(옆 글자 label.md).
    final iconSize = AppIconSize.adjacentText(
      context.tokens.typography.labelMd.fontSize!,
    );
    AppIcon regular(AppGlyph glyph) => AppIcon(
      glyph,
      size: iconSize,
      // `lucky-card` `lead.iconWeight`가 regular로 못박혀 있어 짝 규칙보다 우선합니다.
      weight: AppIconWeight.regular,
      // 칩 높이는 최소 높이라 배율만큼 늘어납니다.
      scalesWithText: true,
      color: colors.textSecondary,
    );
    final lead = switch (item.variant) {
      LuckyCardVariant.color => _Swatch(element: item.element!),
      LuckyCardVariant.direction => regular(_compass),
      LuckyCardVariant.number => regular(_hash),
      // 해와 달은 periods의 lead가 굵기(fill)와 색을 덮어씁니다(V115).
      LuckyCardVariant.time => AppIcon.timeOfDay(
        item.period!,
        size: iconSize,
        scalesWithText: true,
        color: timeIconColorOf(colors, item.period!),
      ),
    };
    final word = item.word;
    return _ChipFrame(
      lead: lead,
      word: word,
      value: item.value,
      // 시간 값(`09:30~11:30`)은 숫자 폭을 고르게 둡니다(`time.parts.value` tnum).
      valueFeatures: item.variant == LuckyCardVariant.time
          ? timeValueFeatures
          : null,
      // 해와 달은 읽지 않고, 밤 칩은 항목 이름 + 때 낱말 + 값입니다(`a11y.nightLabel`).
      label: word == null
          ? '${item.name}, ${item.value}'
          : '${item.name}, $word ${item.value}',
      open: open,
      onTap: onTap,
    );
  }
}

/// 색 견본 원(`ohaeng.swatch`, 14).
class _Swatch extends StatelessWidget {
  const new({required this.element});

  final FiveElement element;

  @override
  Widget build(BuildContext context) {
    final colors = context.tokens.colors;
    return Container(
      key: LuckyChip.swatchKey,
      width: LuckyChip._swatchSize,
      height: LuckyChip._swatchSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ohaengSwatchOf(colors, element),
        border: Border.all(color: colors.swatchBorder),
      ),
    );
  }
}

/// 두 칸 알약의 칸 하나가 보일 색.
typedef _PairHalf = ({FiveElement element, String value});

/// 색이 둘인 날의 두 칸 알약(`lucky-card` `color.parts.pair`, V114).
///
/// 바탕과 테두리는 칩([_ChipFrame])과 같고, 안을 세로선으로 나눈 두 칸이 칸마다 누름 자리입니다.
/// 어느 칸을 눌러도 같은 [onTap](같은 행운 색 시트)이고, 열림 테두리는 알약 전체에 그립니다.
/// 기준 이름표(내 균형 기준, 원전 기준)는 두지 않습니다(`pair.basisLabel` false). 스크린리더는
/// 칸마다 "항목 이름, 값"으로 읽습니다. 계약 `a11y.pairLabel`의 "두 개 중 몇째"는 원고 문구가
/// 없어 아직 읽지 않습니다(A135, writing 몫).
class _PairChipFrame extends StatelessWidget {
  const new({
    required this.name,
    required this.halves,
    required this.open,
    required this.onTap,
  });

  final String name;
  final List<_PairHalf> halves;
  final bool open;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.tokens.colors;
    const pill = Radius.circular(Radii.full);
    final halfShapes = [
      const BorderRadiusDirectional.horizontal(start: pill),
      const BorderRadiusDirectional.horizontal(end: pill),
    ];
    final direction = Directionality.of(context);
    final surface = Container(
      key: LuckyChip.surfaceKey,
      constraints: const BoxConstraints(minHeight: LuckyChip._height),
      decoration: BoxDecoration(
        color: colors.bgSheet,
        borderRadius: const BorderRadius.all(pill),
      ),
      // 열림 테두리는 알약 전체입니다(`pair.open`). 칩과 같이 앞에 덧그려 크기를 바꾸지 않습니다.
      foregroundDecoration: BoxDecoration(
        borderRadius: const BorderRadius.all(pill),
        border: Border.all(
          color: open ? colors.actionPrimary : colors.line,
          width: open ? LuckyChip._openBorder : LuckyChip._border,
        ),
      ),
      // 두 칸은 같은 글자라 높이가 같고, 세로선은 가운데에 둡니다.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, half) in halves.indexed) ...[
            if (index > 0)
              Container(
                key: LuckyChip.pairDividerKey,
                width: LuckyChip.pairDividerWidth,
                height: LuckyChip.pairDividerHeight,
                color: colors.line,
              ),
            Flexible(
              child: _halfOf(
                context,
                index,
                half,
                halfShapes[index].resolve(direction),
              ),
            ),
          ],
        ],
      ),
    );
    // 칸 위아래 판정 여유는 알약 하나에 둡니다. 넓힌 자리의 눌림은 가로 위치 그대로 알약 안으로
    // 옮겨지므로 누른 쪽 칸이 받습니다.
    return onTap == null ? surface : VerticalHitSlop(child: surface);
  }

  Widget _halfOf(
    BuildContext context,
    int index,
    _PairHalf half,
    BorderRadius shape,
  ) {
    final tokens = context.tokens;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: LuckyChip.pairHalfMinTarget,
        minHeight: LuckyChip._height,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: LuckyChip.pairHalfPaddingX,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: LuckyChip.pairHalfGap,
          children: [
            _Swatch(element: half.element),
            Flexible(
              child: Text(
                half.value,
                style: tokens.typography.labelMd.copyWith(
                  color: tokens.colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final label = '$name, ${half.value}';
    final tap = onTap;
    if (tap == null) {
      return Semantics(
        key: LuckyChip.pairHalfKey(index),
        container: true,
        label: label,
        child: ExcludeSemantics(child: content),
      );
    }
    return PressInkTarget(
      key: LuckyChip.pairHalfKey(index),
      semanticLabel: label,
      onTap: tap,
      borderRadius: shape,
      child: content,
    );
  }
}

/// 칩 바탕과 눌림(`lucky-card` `chip`).
class _ChipFrame extends StatelessWidget {
  const new({
    required this.lead,
    required this.word,
    required this.value,
    required this.valueFeatures,
    required this.label,
    required this.open,
    required this.onTap,
  });

  final Widget? lead;
  final String? word;
  final String value;
  final List<FontFeature>? valueFeatures;
  final String label;
  final bool open;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final lead = this.lead;
    final word = this.word;
    final valueStyle = tokens.typography.labelMd.copyWith(
      color: colors.textPrimary,
    );
    final surface = Container(
      key: LuckyChip.surfaceKey,
      constraints: const BoxConstraints(minHeight: LuckyChip._height),
      padding: const EdgeInsets.symmetric(horizontal: Space.s12),
      decoration: BoxDecoration(
        // 반투명 chip.bg 대신 불투명 bg.sheet라 어느 바탕 위에서도 테두리로 구분됩니다(V75).
        color: colors.bgSheet,
        borderRadius: const BorderRadius.all(Radius.circular(Radii.full)),
      ),
      // 테두리는 앞에 덧그려 칩 크기와 안쪽 배치를 바꾸지 않습니다. 시트가 열린 동안에는
      // 1.5px action.primary로 바뀝니다.
      foregroundDecoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(Radii.full)),
        border: Border.all(
          color: open ? colors.actionPrimary : colors.line,
          width: open ? LuckyChip._openBorder : LuckyChip._border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: LuckyChip._gap,
        children: [
          ?lead,
          // 밤 칩 때 낱말은 값과 같은 글자로 값 앞 space.4에 둡니다(`periods` night `word`).
          if (word != null) Text(word, style: valueStyle),
          Flexible(
            child: Text(
              value,
              style: valueStyle.copyWith(fontFeatures: valueFeatures),
            ),
          ),
        ],
      ),
    );
    final tap = onTap;
    if (tap == null) {
      return Semantics(
        container: true,
        label: label,
        child: ExcludeSemantics(child: surface),
      );
    }
    return VerticalHitSlop(
      child: PressInkTarget(
        semanticLabel: label,
        onTap: tap,
        borderRadius: const BorderRadius.all(Radius.circular(Radii.full)),
        child: surface,
      ),
    );
  }
}

/// 행운 칩 줄(`lucky-card`).
///
/// 칩을 누르면 [onOpen]이 설명 시트(`explain-sheet`)를 엽니다. 계약 `a11y.opensSheet`는 별도 힌트 없이
/// 시트 route가 열릴 때 제목으로 알려지는 것으로 충족합니다(depth-link와 같은 원칙). 설명을 줄 아래에 끼워 넣지
/// 않습니다. [onOpen]이 끝날 때까지(시트가 닫힐 때까지) 누른 칩에만 열림 테두리(1.5px
/// `action.primary`)가 생기고, 낮과 밤 시간 칩은 각자의 시트를 엽니다(V116).
/// 햅틱은 없습니다(명세 `haptic` 비어 있음). 칩 수 상한(색, 방향, 숫자 3 + 시간 2, V52)은 값을
/// 만드는 쪽이 지키고 줄은 따로 자르지 않으며, 폭이 모자라면 칩 하나를 끊지 않고 다음 줄로
/// 넘깁니다.
///
/// [onOpen]이 null이면 표시 전용입니다(칩이 버튼으로 읽히지 않음).
class LuckyCardRow extends StatefulWidget {
  /// 칩 줄을 만듭니다.
  const new({required this.items, this.onOpen, super.key});

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'lucky-card',
    {'color', 'direction', 'number', 'time'},
    {'loading', 'pressed', 'open', 'closed'},
  );

  /// 뼈 칩 너비(`states.loading.skeleton` `chip.widths`, 72, 56, 64px).
  static const List<double> skeletonChipWidths = [72, 56, 64];

  /// 불러오는 중 뼈: 칩 높이의 알약 셋을 [Space.s8] 사이로 줄 세웁니다(`chip.gap`).
  /// 칩을 하나만 보이는 화면(나의 사주 행운 색)은 [count]로 앞에서부터 줄입니다.
  static Widget skeleton({
    int count = 3,
    int index = 0,
    bool animated = true,
  }) => Wrap(
    spacing: _rowGap,
    runSpacing: _rowGap,
    children: [
      for (final (i, width) in skeletonChipWidths.take(count).indexed)
        SkeletonChip(
          width: width,
          height: LuckyChip._height,
          index: index + i,
          animated: animated,
        ),
    ],
  );

  /// 행운 4종 [variant]의 칩을 찾는 테스트용 키. 시간 칩은 낮과 밤이 하나씩이라 [period]로
  /// 나눕니다(낮이나 null이면 `time` 칩 그대로).
  static Key chipKey(LuckyCardVariant variant, {AppTimeOfDay? period}) =>
      ValueKey(
        period == AppTimeOfDay.night
            ? 'lucky-card-chip-${variant.name}-${period!.name}'
            : 'lucky-card-chip-${variant.name}',
      );

  static const double _rowGap = Space.s8;

  /// 칩 줄 위아래에 두는 판정 여유. 칩 높이 34를 `a11y.minTarget` 44까지 넓히는 양
  /// (위아래 5)이라, 첫 줄 위·마지막 줄 아래도 44로 눌립니다. 줄 위쪽에는 이 값만큼 빈 자리가
  /// 생기므로 쓰는 화면이 위 간격에서 그만큼 뺍니다.
  static const double hitInset = (sentenceMinTarget - LuckyChip._height) / 2;

  /// 보여 줄 칩 항목(앞에서부터 그립니다). 칩은 변형과 낮과 밤([LuckyItem.period])으로 나뉘어
  /// 따로 열립니다.
  final List<LuckyItem> items;

  /// 칩을 눌렀을 때 설명 시트를 엽니다. 시트가 닫히면 끝나는 Future를 돌려주면 그동안 열림
  /// 테두리를 그립니다. null이면 표시 전용입니다.
  final FutureOr<void> Function(LuckyItem item)? onOpen;

  @override
  State<LuckyCardRow> createState() => _LuckyCardRowState();
}

class _LuckyCardRowState extends State<LuckyCardRow> {
  // 지금 열려 있는 칩의 id(`<변형>:<낮과 밤>`).
  String? _openId;

  static String _itemId(LuckyItem item) =>
      '${item.variant.name}:${item.period?.name}';

  Future<void> _open(LuckyItem item) async {
    final onOpen = widget.onOpen;
    if (onOpen == null) return;
    final id = _itemId(item);
    setState(() => _openId = id);
    try {
      await onOpen(item);
    } finally {
      // 그사이 다른 칩이 열렸다면 그 칩의 열림 테두리를 지우지 않습니다.
      if (mounted && _openId == id) setState(() => _openId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onOpen != null;
    return _HitOutset(
      outset: LuckyCardRow.hitInset,
      child: Wrap(
        spacing: LuckyCardRow._rowGap,
        runSpacing: LuckyCardRow._rowGap,
        children: [
          for (final item in widget.items)
            LuckyChip(
              key: LuckyCardRow.chipKey(item.variant, period: item.period),
              item: item,
              open: _openId == _itemId(item),
              onTap: interactive ? () => unawaited(_open(item)) : null,
            ),
        ],
      ),
    );
  }
}

/// [child] 위아래에 [outset]만큼 판정 여유를 두는 상자.
///
/// 여유 자리에서 누르면 가장 가까운 child 가장자리로 옮겨 child에 넘기므로, 가장자리 칩의
/// `VerticalHitSlop`이 부모 경계 밖까지 닿습니다. 여유는 레이아웃 높이에 포함됩니다.
class _HitOutset extends SingleChildRenderObjectWidget {
  const new({required this.outset, required super.child});

  final double outset;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHitOutset(outset);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderHitOutset).outset = outset;
}

class _RenderHitOutset extends RenderShiftedBox {
  new(this._outset) : super(null);

  double _outset;

  double get outset => _outset;

  set outset(double value) {
    if (_outset == value) return;
    _outset = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.constrain(Size(0, _outset * 2));
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    (child.parentData! as BoxParentData).offset = Offset(0, _outset);
    size = constraints.constrain(
      Size(child.size.width, child.size.height + _outset * 2),
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null || !size.contains(position)) return false;
    final y = position.dy.clamp(_outset, _outset + child.size.height - 0.01);
    final hit = child.hitTest(
      result,
      position: Offset(position.dx, y - _outset),
    );
    if (hit) result.add(BoxHitTestEntry(this, position));
    return hit;
  }
}
