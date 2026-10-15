import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/live_announcement.dart';
import 'package:myungli_diary/design/components/feedback/seep_presence.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/components/sentence/rendered_text_view.dart';
import 'package:myungli_diary/design/components/sentence/vertical_hit_slop.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
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
  time,
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
  /// 행운 항목을 만듭니다. [swatch]는 [LuckyCardVariant.color]에서만 씁니다.
  const new({
    required this.variant,
    required this.name,
    required this.value,
    required this.explain,
    this.swatch,
  });

  /// 변형.
  final LuckyCardVariant variant;

  /// 항목 이름("행운 색"). 스크린리더가 값 앞에 읽습니다.
  final String name;

  /// 칩에 보이는 값("파랑").
  final String value;

  /// 누르면 열리는 설명 문장(server가 렌더한 조각).
  final RenderedText explain;

  /// 색 변형의 견본 색(`ohaeng.swatch`).
  final Color? swatch;
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

  static const double _height = 34;
  static const double _gap = 6;
  static const double _swatchSize = 14;
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
    final tokens = context.tokens;
    final colors = tokens.colors;
    final glyph = _glyph;
    final lead = glyph == null
        ? Container(
            key: swatchKey,
            width: _swatchSize,
            height: _swatchSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.swatch,
              border: Border.all(color: colors.swatchBorder),
            ),
          )
        : AppIcon(
            glyph,
            size: AppIconSize.inline,
            weight: AppIconWeight.regular,
            color: colors.textSecondary,
          );
    final surface = Container(
      key: surfaceKey,
      constraints: const BoxConstraints(minHeight: _height),
      padding: const EdgeInsets.symmetric(horizontal: Space.s12),
      decoration: BoxDecoration(
        color: colors.chipBg,
        borderRadius: const BorderRadius.all(Radius.circular(Radii.full)),
      ),
      // 안쪽 테두리는 앞에 덧그려 칩 크기와 안쪽 배치를 바꾸지 않습니다.
      foregroundDecoration: open
          ? BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(Radii.full)),
              border: Border.all(
                color: colors.actionPrimary,
                width: _openBorder,
              ),
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: _gap,
        children: [
          lead,
          Flexible(
            child: Text(
              item.value,
              style: tokens.typography.labelMd.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
    final label = '${item.name}, ${item.value}';
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
        expanded: open,
        onTap: tap,
        borderRadius: const BorderRadius.all(Radius.circular(Radii.full)),
        child: surface,
      ),
    );
  }
}

/// 행운 칩 줄과 그 아래 설명 한 줄(`lucky-card`).
///
/// 칩을 누르면 줄 아래 전체 폭에 설명 상자가 `appear.seep`으로 열리고, 같은 칩을 다시 누르면
/// 닫힙니다. 한 번에 하나만 열려 다른 칩을 누르면 설명이 바뀝니다. 햅틱은 없습니다(명세
/// `haptic` 비어 있음). 열린 설명은 스크린리더에 상태 알림으로 읽힙니다.
///
/// [interactive]가 false면(공유 이미지) 눌러도 열리지 않고 칩이 버튼으로 읽히지 않습니다.
/// [slotIds]는 변형 → 설명 슬롯 id(`today.lucky-color.body` 등)이며 있으면 설명 상자에
/// Key와 Semantics `identifier`로 붙습니다.
class LuckyCardRow extends StatefulWidget {
  /// 칩 줄을 만듭니다.
  const new({
    required this.items,
    this.interactive = true,
    this.slotIds = const {},
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'lucky-card',
    {'color', 'direction', 'number', 'time'},
    {'pressed', 'open', 'closed'},
  );

  /// 설명 상자를 찾는 테스트용 키.
  static const Key explainKey = ValueKey('lucky-card-explain');

  /// [variant]의 칩을 찾는 테스트용 키.
  static Key chipKey(LuckyCardVariant variant) =>
      ValueKey('lucky-card-chip-${variant.name}');

  static const double _rowGap = Space.s8;

  /// 보여 줄 행운 항목. 같은 변형이 둘 이상이면 앞의 것만 설명을 엽니다.
  final List<LuckyItem> items;

  /// false면 표시 전용입니다.
  final bool interactive;

  /// 변형 → 설명 슬롯 id.
  final Map<LuckyCardVariant, String> slotIds;

  @override
  State<LuckyCardRow> createState() => _LuckyCardRowState();
}

class _LuckyCardRowState extends State<LuckyCardRow> {
  LuckyCardVariant? _open;

  // 닫히는 동안에도 설명 내용을 그리려고 마지막으로 열린 항목을 기억합니다.
  LuckyItem? _lastOpenItem;

  LuckyItem? _itemOf(LuckyCardVariant? variant) {
    if (variant == null) return null;
    for (final item in widget.items) {
      if (item.variant == variant) return item;
    }
    return null;
  }

  @override
  void didUpdateWidget(LuckyCardRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = _itemOf(_open);
    if (_open != null && current == null) {
      _open = null;
    } else if (current != null) {
      _lastOpenItem = current;
    }
  }

  void _toggle(LuckyItem item) {
    setState(() {
      _open = _open == item.variant ? null : item.variant;
      if (_open != null) _lastOpenItem = item;
    });
  }

  @override
  Widget build(BuildContext context) {
    final shown = _lastOpenItem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: LuckyCardRow._rowGap,
          runSpacing: LuckyCardRow._rowGap,
          children: [
            for (final item in widget.items)
              LuckyChip(
                key: LuckyCardRow.chipKey(item.variant),
                item: item,
                open: _open == item.variant,
                onTap: widget.interactive ? () => _toggle(item) : null,
              ),
          ],
        ),
        SeepPresence(
          present: _open != null,
          child: shown == null
              ? const SizedBox.shrink()
              : _Explain(item: shown, slotId: widget.slotIds[shown.variant]),
        ),
      ],
    );
  }
}

/// 칩 줄 아래 설명 상자(`lucky-card` `explain`).
class _Explain extends StatelessWidget {
  const new({required this.item, required this.slotId});

  final LuckyItem item;
  final String? slotId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final spoken = item.explain.segments.map((s) => s.text).join();
    final box = Padding(
      padding: const EdgeInsets.only(top: LuckyCardRow._rowGap),
      child: Container(
        key: LuckyCardRow.explainKey,
        padding: const EdgeInsets.all(Space.s12),
        decoration: BoxDecoration(
          color: colors.chipBg,
          borderRadius: const BorderRadius.all(Radius.circular(Radii.md)),
        ),
        child: RenderedTextView(
          text: item.explain,
          style: tokens.typography.captionLg.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ),
    );
    final id = slotId;
    // 열릴 때 설명을 상태 알림으로 읽습니다(`a11y.expandedAnnounced`).
    final announced = LiveAnnouncement(
      identifier: id,
      label: spoken,
      role: SemanticsRole.status,
      child: box,
    );
    if (id == null) return announced;
    return KeyedSubtree(key: ValueKey(id), child: announced);
  }
}
