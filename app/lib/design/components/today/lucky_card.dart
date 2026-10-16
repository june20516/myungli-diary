import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/live_announcement.dart';
import 'package:myungli_diary/design/components/feedback/seep_presence.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/components/sentence/rendered_text_view.dart';
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
  time,

  /// 그날의 대표 태그(`Daily.tags.featured`, today만). 앞 아이콘 `tag`(text.primary)와
  /// 굵기 600으로만 행운 칩과 구분하고, 길흉(`polarity`)으로 모양을 나누지 않습니다.
  tag,
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
const AppGlyph _tag = AppGlyph(
  light: PhosphorIconsLight.tag,
  regular: PhosphorIconsRegular.tag,
);

/// 행운 항목 하나(대표 태그 포함). 표시 값 변환은 이 값을 만드는 한 곳에서 합니다.
@immutable
final class LuckyItem {
  /// 행운 항목을 만듭니다. [element]는 [LuckyCardVariant.color]에서만 씁니다.
  /// 대표 태그는 [LuckyItem.tag]로 만듭니다.
  const new({
    required this.variant,
    required this.name,
    required this.value,
    required RenderedText this.explain,
    this.element,
  }) : tagKey = null,
       assert(variant != LuckyCardVariant.tag, 'tag 변형은 LuckyItem.tag로 만듭니다.'),
       assert(
         (variant == LuckyCardVariant.color) == (element != null),
         'color 변형은 element가 필수이고, 다른 변형은 element를 줄 수 없습니다.',
       );

  /// 대표 태그 하나(D76, 계약 `Daily.tags.featured`). 이름과 값이 같은 태그 이름입니다.
  ///
  /// [meaning]이 없으면 누를 수 없는 이름 칩입니다.
  const new tag({
    required String this.tagKey,
    required this.name,
    RenderedText? meaning,
  }) : variant = LuckyCardVariant.tag,
       value = name,
       explain = meaning,
       element = null;

  /// 변형.
  final LuckyCardVariant variant;

  /// 항목 이름("행운 색"). 스크린리더가 값 앞에 읽습니다. 태그는 태그 이름입니다.
  final String name;

  /// 칩에 보이는 값("파랑"). 태그는 태그 이름입니다.
  final String value;

  /// 누르면 열리는 설명 문장(server가 렌더한 조각). 뜻이 없는 태그만 null입니다.
  final RenderedText? explain;

  /// 색 변형의 오행. 칩이 지금 테마의 견본 색(`ohaeng.swatch`)으로 그립니다.
  /// [LuckyCardVariant.color]에서만 주고(필수), 다른 변형에서는 줄 수 없습니다(assert).
  final FiveElement? element;

  /// 태그 변형의 태그 키(glossary `tag` 범주의 키, 예 `cheoneul_gwiin`). 다른 변형은 null.
  final String? tagKey;
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

  /// `tag` 변형 값의 글자 굵기(`tag.parts.value.fontWeight`).
  static const FontWeight tagValueWeight = FontWeight.w600;
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
    LuckyCardVariant.tag => _tag,
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
            size: AppIconSize.inline,
            weight: AppIconWeight.regular,
            // tag 변형만 앞 아이콘이 text.primary입니다.
            color: item.variant == LuckyCardVariant.tag
                ? colors.textPrimary
                : colors.textSecondary,
          );
    return _ChipFrame(
      lead: lead,
      value: item.value,
      // 시간 값(`09:30–11:30`)은 숫자 폭을 고르게 둡니다(`time.parts.value` tnum).
      valueFeatures: item.variant == LuckyCardVariant.time
          ? timeValueFeatures
          : null,
      // 태그는 이름만 읽습니다(`a11y.label`).
      label: item.variant == LuckyCardVariant.tag
          ? item.name
          : '${item.name}, ${item.value}',
      valueWeight: item.variant == LuckyCardVariant.tag ? tagValueWeight : null,
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
    required this.valueWeight,
    required this.label,
    required this.open,
    required this.onTap,
  });

  final Widget? lead;
  final String value;
  final List<FontFeature>? valueFeatures;
  final FontWeight? valueWeight;
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
        color: colors.chipBg,
        borderRadius: const BorderRadius.all(Radius.circular(Radii.full)),
      ),
      // 안쪽 테두리는 앞에 덧그려 칩 크기와 안쪽 배치를 바꾸지 않습니다.
      foregroundDecoration: open
          ? BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(Radii.full)),
              border: Border.all(
                color: colors.actionPrimary,
                width: LuckyChip._openBorder,
              ),
            )
          : null,
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
                fontWeight: valueWeight,
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
/// 대표 태그([LuckyCardVariant.tag], D76)는 [items] 맨 앞에 두면 됩니다(칩 줄 맨 앞, 행운 4종
/// 앞). 같은 눌림·열림 규칙을 따르고, 칩을 통틀어 하나만 열립니다. 칩 수 상한(태그 2 + 행운 4)은
/// 값을 만드는 쪽이 지키고 줄은 따로 자르지 않으며, 폭이 모자라면 칩 하나를 끊지 않고 다음 줄로
/// 넘깁니다.
///
/// [interactive]가 false면(공유 이미지) 눌러도 열리지 않고 칩이 버튼으로 읽히지 않습니다.
/// [slotIds]는 변형 → 설명 슬롯 id(`today.lucky-color.body`, 태그는
/// `today.lucky-tag.body` 등)이며 있으면 설명 상자에 Key와 Semantics `identifier`로 붙습니다.
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
    {'color', 'direction', 'number', 'time', 'tag'},
    {'pressed', 'open', 'closed'},
  );

  /// 설명 상자를 찾는 테스트용 키.
  static const Key explainKey = ValueKey('lucky-card-explain');

  /// [variant]의 칩을 찾는 테스트용 키. 태그는 여럿일 수 있어 [tagChipKey]를 씁니다.
  static Key chipKey(LuckyCardVariant variant) =>
      ValueKey('lucky-card-chip-${variant.name}');

  /// 태그 키가 [tagKey]인 대표 태그 칩을 찾는 테스트용 키.
  static Key tagChipKey(String tagKey) =>
      ValueKey('lucky-card-chip-tag-$tagKey');

  static Key _keyOf(LuckyItem item) =>
      item.tagKey == null ? chipKey(item.variant) : tagChipKey(item.tagKey!);

  static const double _rowGap = Space.s8;

  /// 칩 줄 위아래에 두는 판정 여유. 칩 높이 34를 `a11y.minTarget` 44까지 넓히는 양
  /// (위아래 5)이라, 첫 줄 위·마지막 줄 아래도 44로 눌립니다. 보이는 간격은 그대로 두도록
  /// 설명 상자 위 간격은 [_rowGap]에서 이 값을 뺍니다. 줄 위쪽에는 이 값만큼 빈 자리가
  /// 생기므로 쓰는 화면이 위 간격에서 그만큼 뺍니다.
  static const double hitInset = (sentenceMinTarget - LuckyChip._height) / 2;

  /// 보여 줄 칩 항목(앞에서부터 그립니다). 같은 변형이 둘 이상이면 앞의 것만 설명을 엽니다
  /// (태그는 태그 키마다 다른 칩입니다).
  final List<LuckyItem> items;

  /// false면 표시 전용입니다.
  final bool interactive;

  /// 변형 → 설명 슬롯 id. 태그가 여럿이어도 한 번에 하나만 열리므로 변형마다 하나입니다.
  final Map<LuckyCardVariant, String> slotIds;

  @override
  State<LuckyCardRow> createState() => _LuckyCardRowState();
}

/// 열 수 있는 칩 하나의 설명.
@immutable
final class _Openable {
  const new({required this.id, required this.text, required this.slotId});

  /// 칩 줄 안에서 이 칩을 가리키는 id(`variant:<변형>`, 태그는 `tag:<키>`).
  final String id;

  /// 열리는 설명 문장.
  final RenderedText text;

  /// 설명 상자의 슬롯 id.
  final String? slotId;
}

class _LuckyCardRowState extends State<LuckyCardRow> {
  String? _open;

  // 닫히는 동안에도 설명 내용을 그리려고 마지막으로 열린 설명을 기억합니다.
  _Openable? _lastOpen;

  // 열린 채로 다른 칩으로 바뀔 때마다 올려, 바뀐 설명이 appear.seep으로 다시 나타나게 합니다.
  int _swap = 0;

  static String _itemId(LuckyItem item) => item.tagKey == null
      ? 'variant:${item.variant.name}'
      : 'tag:${item.tagKey}';

  /// 설명 문장이 없는 항목(뜻이 없는 태그)은 열 것이 없어 null입니다.
  _Openable? _openableOfItem(LuckyItem item) {
    final explain = item.explain;
    if (explain == null) return null;
    return _Openable(
      id: _itemId(item),
      text: explain,
      slotId: widget.slotIds[item.variant],
    );
  }

  /// 지금 줄에서 [id]인 칩의 설명. 같은 id가 둘 이상이면 앞의 것입니다.
  _Openable? _openableOf(String? id) {
    if (id == null) return null;
    for (final item in widget.items) {
      if (_itemId(item) == id) return _openableOfItem(item);
    }
    return null;
  }

  @override
  void didUpdateWidget(LuckyCardRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = _openableOf(_open);
    if (_open != null && current == null) {
      _open = null;
    } else if (current != null) {
      _lastOpen = current;
    }
  }

  void _toggle(_Openable openable) {
    setState(() {
      final next = _open == openable.id ? null : openable.id;
      if (_open != null && next != null) _swap++;
      _open = next;
      if (next != null) _lastOpen = openable;
    });
  }

  VoidCallback? _onTapOf(_Openable? openable) =>
      widget.interactive && openable != null ? () => _toggle(openable) : null;

  @override
  Widget build(BuildContext context) {
    final shown = _lastOpen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _HitOutset(
          outset: LuckyCardRow.hitInset,
          child: Wrap(
            spacing: LuckyCardRow._rowGap,
            runSpacing: LuckyCardRow._rowGap,
            children: [
              for (final item in widget.items)
                LuckyChip(
                  key: LuckyCardRow._keyOf(item),
                  item: item,
                  open: _open == _itemId(item),
                  onTap: _onTapOf(_openableOfItem(item)),
                ),
            ],
          ),
        ),
        SeepPresence(
          key: ValueKey(_swap),
          present: _open != null,
          child: shown == null
              ? const SizedBox.shrink()
              : _Explain(text: shown.text, slotId: shown.slotId),
        ),
      ],
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

/// 칩 줄 아래 설명 상자(`lucky-card` `explain`).
class _Explain extends StatelessWidget {
  const new({required this.text, required this.slotId});

  final RenderedText text;
  final String? slotId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final spoken = text.segments.map((s) => s.text).join();
    final box = Padding(
      padding: const EdgeInsets.only(
        top: LuckyCardRow._rowGap - LuckyCardRow.hitInset,
      ),
      child: Container(
        key: LuckyCardRow.explainKey,
        padding: const EdgeInsets.all(Space.s12),
        decoration: BoxDecoration(
          color: colors.chipBg,
          borderRadius: const BorderRadius.all(Radius.circular(Radii.md)),
        ),
        child: RenderedTextView(
          text: text,
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
