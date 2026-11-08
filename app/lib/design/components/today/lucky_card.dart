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

  /// 행운 시간. 앞 아이콘 `clock`.
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
const AppGlyph _clock = AppGlyph(
  light: PhosphorIconsLight.clock,
  regular: PhosphorIconsRegular.clock,
);

/// 행운 항목 하나. 표시 값 변환은 이 값을 만드는 한 곳에서 합니다.
@immutable
final class LuckyItem {
  /// 행운 항목을 만듭니다. [element]는 [LuckyCardVariant.color]에서만 씁니다.
  /// [ordinal]은 [LuckyCardVariant.time]에서만 0이 아닐 수 있습니다(구간마다 칩 하나, V52).
  const new({
    required this.variant,
    required this.name,
    required this.value,
    required this.explain,
    this.element,
    this.ordinal = 0,
  }) : assert(
         (variant == LuckyCardVariant.color) == (element != null),
         'color 변형은 element가 필수이고, 다른 변형은 element를 줄 수 없습니다.',
       ),
       assert(
         ordinal >= 0 && (ordinal == 0 || variant == LuckyCardVariant.time),
         '순번은 0 이상이고, 칩이 여럿일 수 있는 time 변형만 0이 아닐 수 있습니다.',
       );

  /// 변형.
  final LuckyCardVariant variant;

  /// 항목 이름("행운 색"). 스크린리더가 값 앞에 읽고, 설명 시트의 제목이 됩니다.
  final String name;

  /// 칩에 보이는 값("파랑").
  final String value;

  /// 누르면 열리는 설명 시트의 문장(server가 렌더한 조각).
  final RenderedText explain;

  /// 색 변형의 오행. 칩이 지금 테마의 견본 색(`ohaeng.swatch`)으로 그립니다.
  /// [LuckyCardVariant.color]에서만 주고(필수), 다른 변형에서는 줄 수 없습니다(assert).
  final FiveElement? element;

  /// 같은 변형 안의 순번(0부터). 집중 시간 구간이 둘이면 시간 칩이 0, 1입니다(계약 순서, V52).
  /// 다른 변형은 0입니다.
  final int ordinal;
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

  /// `time` 값의 글꼴 기능(`time.parts.value.fontFeatures`: tnum).
  static const List<FontFeature> timeValueFeatures = [
    FontFeature.tabularFigures(),
  ];

  static const double _height = 34;
  static const double _gap = 6;
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

  AppGlyph? get _glyph => switch (item.variant) {
    LuckyCardVariant.color => null,
    LuckyCardVariant.direction => _compass,
    LuckyCardVariant.number => _hash,
    LuckyCardVariant.time => _clock,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.tokens.colors;
    final glyph = _glyph;
    final lead = glyph == null
        ? Container(
            key: swatchKey,
            width: _swatchSize,
            height: _swatchSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ohaengSwatchOf(colors, item.element!),
              border: Border.all(color: colors.swatchBorder),
            ),
          )
        : AppIcon(
            glyph,
            // `lucky-card` `lead.iconSize`: adjacent-text(옆 글자 label.md).
            size: AppIconSize.adjacentText(
              context.tokens.typography.labelMd.fontSize!,
            ),
            // `lucky-card` `lead.iconWeight`가 regular로 못박혀 있어 짝 규칙보다 우선합니다.
            weight: AppIconWeight.regular,
            // 칩 높이는 최소 높이라 배율만큼 늘어납니다.
            scalesWithText: true,
            color: colors.textSecondary,
          );
    return _ChipFrame(
      lead: lead,
      value: item.value,
      // 시간 값(`09:30~11:30`)은 숫자 폭을 고르게 둡니다(`time.parts.value` tnum).
      valueFeatures: item.variant == LuckyCardVariant.time
          ? timeValueFeatures
          : null,
      label: '${item.name}, ${item.value}',
      open: open,
      onTap: onTap,
    );
  }
}

/// 칩 바탕과 눌림(`lucky-card` `chip`).
class _ChipFrame extends StatelessWidget {
  const new({
    required this.lead,
    required this.value,
    required this.valueFeatures,
    required this.label,
    required this.open,
    required this.onTap,
  });

  final Widget? lead;
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
          Flexible(
            child: Text(
              value,
              style: tokens.typography.labelMd.copyWith(
                color: colors.textPrimary,
                fontFeatures: valueFeatures,
              ),
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
/// 칩을 누르면 [onOpen]이 설명 시트(`explain-sheet`)를 엽니다. 설명을 줄 아래에 끼워 넣지
/// 않습니다. [onOpen]이 끝날 때까지(시트가 닫힐 때까지) 누른 칩에만 열림 테두리(1.5px
/// `action.primary`)가 생기고, 시간 칩 둘은 같은 설명을 열어도 누른 칩만 테두리가 바뀝니다(V52).
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

  /// 행운 4종 [variant]의 칩을 찾는 테스트용 키. 시간 칩은 구간마다 하나라 [ordinal]
  /// (0이면 첫 구간)로 나눕니다.
  static Key chipKey(LuckyCardVariant variant, {int ordinal = 0}) => ValueKey(
    ordinal == 0
        ? 'lucky-card-chip-${variant.name}'
        : 'lucky-card-chip-${variant.name}-$ordinal',
  );

  static const double _rowGap = Space.s8;

  /// 칩 줄 위아래에 두는 판정 여유. 칩 높이 34를 `a11y.minTarget` 44까지 넓히는 양
  /// (위아래 5)이라, 첫 줄 위·마지막 줄 아래도 44로 눌립니다. 줄 위쪽에는 이 값만큼 빈 자리가
  /// 생기므로 쓰는 화면이 위 간격에서 그만큼 뺍니다.
  static const double hitInset = (sentenceMinTarget - LuckyChip._height) / 2;

  /// 보여 줄 칩 항목(앞에서부터 그립니다). 칩은 변형과 순번([LuckyItem.ordinal])으로 나뉘어
  /// 따로 열립니다.
  final List<LuckyItem> items;

  /// 칩을 눌렀을 때 설명 시트를 엽니다. 시트가 닫히면 끝나는 Future를 돌려주면 그동안 열림
  /// 테두리를 그립니다. null이면 표시 전용입니다.
  final FutureOr<void> Function(LuckyItem item)? onOpen;

  @override
  State<LuckyCardRow> createState() => _LuckyCardRowState();
}

class _LuckyCardRowState extends State<LuckyCardRow> {
  // 지금 열려 있는 칩의 id(`<변형>:<순번>`).
  String? _openId;

  static String _itemId(LuckyItem item) =>
      '${item.variant.name}:${item.ordinal}';

  Future<void> _open(LuckyItem item) async {
    final onOpen = widget.onOpen;
    if (onOpen == null) return;
    setState(() => _openId = _itemId(item));
    try {
      await onOpen(item);
    } finally {
      if (mounted) setState(() => _openId = null);
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
              key: LuckyCardRow.chipKey(item.variant, ordinal: item.ordinal),
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
