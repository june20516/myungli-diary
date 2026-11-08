import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 출생 정보 줄(`birth-info-row`, V88): 쉼표 없이 칸 셋(달력 종류 꼬리표와 날짜, 시진 한자
/// 태그와 시간, 성별 알약)을 세로선으로 나눕니다.
///
/// 칸 사이 세로선은 1 × 16 `color.line`이고 좌우 `space.12`입니다. 한 줄에 다 들어가지
/// 않으면 칸 단위로 다음 줄로 내려가며(줄 사이 `space.8`) 칸 안에서는 줄을 바꾸지 않고,
/// 줄이 바뀐 칸 앞에는 선을 긋지 않습니다. 시진 태그는 시진 뜻 원고가 없어 누를 수 없는
/// 표시입니다. [timeUnknown]이면 시진 칸 자리에 `timeUnknownLabel` 알약 하나를 둡니다.
/// 스크린리더는 달력 종류와 날짜, 시진과 시간, 성별 순서로 이어 읽고 세로선은 읽지 않습니다.
/// 글자 배율은 1.3배에서 멈춥니다(`textScaleMax`).
class BirthInfoRow extends StatelessWidget {
  /// 출생 정보 줄을 만듭니다. [timeUnknown]이 아니면 [hourGlyph], [hourName], [time]이
  /// 모두 있어야 합니다.
  const new({
    required this.calendarTag,
    required this.date,
    required this.gender,
    this.hourGlyph,
    this.hourName,
    this.time,
    this.timeUnknown = false,
    super.key,
  }) : assert(
         timeUnknown || (hourGlyph != null && hourName != null && time != null),
         '시간을 알면 시진 한자, 시진 이름, 시간이 모두 있어야 합니다',
       );

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('birth-info-row', {}, {
    'time-unknown',
    'loading',
  });

  /// 칸 사이 세로선을 찾는 테스트용 키.
  static const Key dividerKey = ValueKey('birth-info-row-divider');

  /// 칸 셋을 찾는 테스트용 키(날짜, 시진, 성별 순).
  static const List<Key> cellKeys = [
    ValueKey('birth-info-row-date'),
    ValueKey('birth-info-row-hour'),
    ValueKey('birth-info-row-gender'),
  ];

  /// 세로선 높이. 계약 `saju.json` `birth-info-row.parts.divider.height`.
  static const double dividerHeight = 16;

  /// 세로선 두께. 계약 `birth-info-row.parts.divider.width`.
  static const double dividerWidth = 1;

  /// 알약 높이(기본 글자 크기). 계약 `birth-info-row.parts.pill.height`.
  static const double pillHeight = 24;

  /// 알약 테두리 두께. 계약 `birth-info-row.parts.pill.border.width`.
  static const double pillBorderWidth = 1;

  /// 글자 크기를 멈추는 배율.
  static const double textScaleMax = 1.3;

  /// skeleton 뼈 폭 비율. 계약 `birth-info-row.states.loading.skeleton`(70%).
  static const double skeletonWidthFactor = 0.7;

  /// 달력 종류 꼬리표 글자(예 "양력", 음력 윤달이면 "음력 윤달").
  final String calendarTag;

  /// 출생 날짜(언어별 숫자 날짜).
  final String date;

  /// 시진 지지 한자 한 글자. [timeUnknown]이면 쓰지 않습니다.
  final String? hourGlyph;

  /// 시진 이름(예 "미시"). [timeUnknown]이면 쓰지 않습니다.
  final String? hourName;

  /// 출생 시각(기기 시간 형식). [timeUnknown]이면 쓰지 않습니다.
  final String? time;

  /// 성별 한 낱말.
  final String gender;

  /// 출생 시간을 모르는지. 시진 태그와 시간 대신 `timeUnknownLabel` 알약입니다.
  final bool timeUnknown;

  /// 불러오는 중(`states.loading`): 머리 제목 아래 폭 70%의 글줄 뼈 하나.
  static Widget skeleton({int index = 0, bool animated = true}) =>
      FractionallySizedBox(
        widthFactor: skeletonWidthFactor,
        alignment: AlignmentDirectional.centerStart,
        child: SkeletonBone(
          height: SkeletonBone.lineHeight,
          borderRadius: Radii.xs,
          index: index,
          animated: animated,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final primaryValue = tokens.typography.labelMd.copyWith(
      color: tokens.colors.textPrimary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final dateCell = Row(
      key: cellKeys[0],
      mainAxisSize: MainAxisSize.min,
      children: [
        _CalendarKindTag(label: calendarTag),
        const SizedBox(width: Space.s4),
        Text(date, maxLines: 1, softWrap: false, style: primaryValue),
      ],
    );
    final hourCell = timeUnknown
        ? _Pill(key: cellKeys[1], label: l10n.timeUnknownLabel)
        : Row(
            key: cellKeys[1],
            mainAxisSize: MainAxisSize.min,
            children: [
              HanjaTag(
                glyph: hourGlyph!,
                label: hourName!,
                variant: HanjaTagVariant.ganji,
              ),
              const SizedBox(width: Space.s8),
              Text(time!, maxLines: 1, softWrap: false, style: primaryValue),
            ],
          );
    final genderCell = _Pill(key: cellKeys[2], label: gender);

    final semanticLabel = [
      '$calendarTag $date',
      if (timeUnknown) l10n.timeUnknownLabel else '$hourName $time',
      gender,
    ].join(l10n.a11yListSeparator);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: textScaleMax,
      child: Semantics(
        container: true,
        label: semanticLabel,
        child: ExcludeSemantics(
          child: _CellFlow(
            runSpacing: Space.s8,
            children: [
              dateCell,
              const _Divider(),
              hourCell,
              const _Divider(),
              genderCell,
            ],
          ),
        ),
      ),
    );
  }
}

/// 달력 종류 꼬리표(`calendarKind`): `caption.sm` `text.secondary`, 0.5px `line` 테두리.
class _CalendarKindTag extends StatelessWidget {
  const new({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.xs),
        border: Border.all(
          color: tokens.colors.line,
          width: BorderTokens.hairline,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.s4),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: tokens.typography.captionSm.copyWith(
            color: tokens.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// 중립 알약(`pill`): 성별과 시간 모름이 같은 모양입니다. 색으로 성별을 나누지 않습니다.
class _Pill extends StatelessWidget {
  const new({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.full),
        border: Border.all(color: tokens.colors.tagNeutralBorder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: BirthInfoRow.pillHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.s8),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: tokens.typography.labelMd.copyWith(
                color: tokens.colors.tagNeutralFg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 칸 사이 세로선: 1 × 16 `color.line`, 좌우 `space.12`(장식이라 읽지 않음).
class _Divider extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Space.s12),
    child: SizedBox(
      key: BirthInfoRow.dividerKey,
      width: BirthInfoRow.dividerWidth,
      height: BirthInfoRow.dividerHeight,
      child: ColoredBox(color: context.tokens.colors.line),
    ),
  );
}

/// 칸과 세로선을 번갈아 받아 칸 단위로 줄을 바꾸는 배치. 줄이 바뀐 칸 앞의 세로선은 그리지
/// 않습니다. 줄 안 칸은 세로 가운데로 맞춥니다.
///
/// 자식 순서는 `칸, 선, 칸, 선, 칸`(짝수 번째가 칸, 홀수 번째가 선)입니다.
class _CellFlow extends MultiChildRenderObjectWidget {
  const new({required this.runSpacing, required super.children});

  final double runSpacing;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCellFlow(runSpacing: runSpacing);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderCellFlow renderObject,
  ) => renderObject.runSpacing = runSpacing;
}

class _CellFlowParentData extends ContainerBoxParentData<RenderBox> {
  /// 줄이 바뀐 칸 앞의 선처럼 그리지 않는 자식.
  bool hidden = false;
}

class _RenderCellFlow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _CellFlowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _CellFlowParentData> {
  new({required double runSpacing}) {
    _runSpacing = runSpacing;
  }

  late double _runSpacing;

  double get runSpacing => _runSpacing;

  set runSpacing(double value) {
    if (_runSpacing == value) return;
    _runSpacing = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CellFlowParentData) {
      child.parentData = _CellFlowParentData();
    }
  }

  List<RenderBox> get _children {
    final result = <RenderBox>[];
    var child = firstChild;
    while (child != null) {
      result.add(child);
      child = childAfter(child);
    }
    return result;
  }

  /// 배치 결과. [place]가 있으면 자식 위치와 숨김을 기록합니다(dry 배치에서는 null).
  Size _flow(
    BoxConstraints constraints,
    Size Function(RenderBox child, BoxConstraints constraints) measure, {
    bool place = false,
  }) {
    final children = _children;
    final maxWidth = constraints.maxWidth;
    final loose = BoxConstraints(maxWidth: maxWidth);
    final sizes = [for (final child in children) measure(child, loose)];

    // 줄마다 (자식 index, x) 목록으로 모읍니다.
    final lines = <List<(int, double)>>[[]];
    var x = 0.0;
    for (var i = 0; i < children.length; i += 2) {
      final dividerWidth = i == 0 ? 0.0 : sizes[i - 1].width;
      final line = lines.last;
      if (line.isEmpty) {
        line.add((i, 0));
        x = sizes[i].width;
      } else if (x + dividerWidth + sizes[i].width <= maxWidth) {
        line
          ..add((i - 1, x))
          ..add((i, x + dividerWidth));
        x += dividerWidth + sizes[i].width;
      } else {
        lines.add([(i, 0)]);
        x = sizes[i].width;
      }
    }

    var y = 0.0;
    var width = 0.0;
    final placed = <int>{};
    for (final line in lines) {
      var lineHeight = 0.0;
      for (final (index, _) in line) {
        lineHeight = lineHeight < sizes[index].height
            ? sizes[index].height
            : lineHeight;
      }
      for (final (index, dx) in line) {
        placed.add(index);
        final end = dx + sizes[index].width;
        width = width < end ? end : width;
        if (place) {
          children[index].parentData! as _CellFlowParentData
            ..hidden = false
            ..offset = Offset(dx, y + (lineHeight - sizes[index].height) / 2);
        }
      }
      y += lineHeight + runSpacing;
    }
    if (place) {
      for (final (index, child) in children.indexed) {
        if (!placed.contains(index)) {
          (child.parentData! as _CellFlowParentData).hidden = true;
          // 줄이 바뀐 칸 앞의 선은 자리를 차지하지 않게 크기 0으로 둡니다.
          child.layout(BoxConstraints.tight(Size.zero), parentUsesSize: true);
        }
      }
    }
    final height = lines.isEmpty ? 0.0 : y - runSpacing;
    return constraints.constrain(Size(width, height < 0 ? 0 : height));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _flow(constraints, (child, c) => child.getDryLayout(c));

  @override
  void performLayout() {
    size = _flow(constraints, (child, c) {
      child.layout(c, parentUsesSize: true);
      return child.size;
    }, place: true);
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    // 가장 넓은 칸 하나가 들어가는 폭입니다(칸은 쪼개지지 않음).
    var widest = 0.0;
    final children = _children;
    for (var i = 0; i < children.length; i += 2) {
      final width = children[i].getMinIntrinsicWidth(height);
      widest = widest < width ? width : widest;
    }
    return widest;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    var sum = 0.0;
    for (final child in _children) {
      sum += child.getMaxIntrinsicWidth(height);
    }
    return sum;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      getDryLayout(BoxConstraints(maxWidth: width)).height;

  @override
  void paint(PaintingContext context, Offset offset) {
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as _CellFlowParentData;
      if (!data.hidden) context.paintChild(child, data.offset + offset);
      child = data.nextSibling;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    var child = lastChild;
    while (child != null) {
      final data = child.parentData! as _CellFlowParentData;
      if (!data.hidden) {
        final hit = result.addWithPaintOffset(
          offset: data.offset,
          position: position,
          hitTest: (result, transformed) =>
              child!.hitTest(result, position: transformed),
        );
        if (hit) return true;
      }
      child = data.previousSibling;
    }
    return false;
  }
}
