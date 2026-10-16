import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/frame/frame_surface.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/seal.dart';
import 'package:myungli_diary/design/interaction/haptics.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

/// 탭 바 높이(px). 아래 안전 영역은 따로 더합니다.
const double tabBarHeight = 72;

/// 탭 하나의 최소 터치 크기(px).
const double tabMinTarget = 48;

/// 선택 표시 도장 크기(`SealSize.row`, 34px).
const SealSize tabSealSize = SealSize.row;

/// 탭 아이콘(`tab-bar.parts.icons`): 오늘 `sun`, 달력 `calendar-blank`, 일기 `notebook`,
/// 나 `user`. 순서는 탭 순서이고, 계약 테스트가 명세와 대조합니다.
const List<AppGlyph> tabGlyphs = [
  AppGlyph(light: PhosphorIconsLight.sun, regular: PhosphorIconsRegular.sun),
  AppGlyph(
    light: PhosphorIconsLight.calendarBlank,
    regular: PhosphorIconsRegular.calendarBlank,
  ),
  AppGlyph(
    light: PhosphorIconsLight.notebook,
    regular: PhosphorIconsRegular.notebook,
  ),
  AppGlyph(light: PhosphorIconsLight.user, regular: PhosphorIconsRegular.user),
];

/// 아래 탭 4개. 반투명 바탕 + 뒤 흐림, 선택한 탭에 낙관 도장이 찍힙니다.
///
/// 다른 탭을 누르면 [onSelect]와 selection 햅틱, 이미 선택된 탭을 다시 누르면
/// [onScrollToTop]만 부르고 도장은 다시 찍지 않습니다.
class MyungliTabBar extends StatelessWidget {
  /// 탭 바를 만듭니다.
  const new({
    required this.index,
    required this.onSelect,
    this.onScrollToTop,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('tab-bar', {}, {
    'selected',
    'unselected',
    'reduceTransparency',
  });

  /// 선택된 탭(0 오늘, 1 달력, 2 일기, 3 나).
  final int index;

  /// 선택이 바뀔 때.
  final ValueChanged<int> onSelect;

  /// 선택된 탭을 다시 눌렀을 때(그 탭 첫 화면 맨 위로).
  final VoidCallback? onScrollToTop;

  @override
  Widget build(BuildContext context) {
    return FrameSurface(
      surfaceKey: const ValueKey('tab-bar.surface'),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: TabBarRow(
          index: index,
          onSelect: onSelect,
          onScrollToTop: onScrollToTop,
        ),
      ),
    );
  }
}

/// 탭 4개의 줄(바탕·안전 영역 제외). 하단 틀(`MyungliBottomBar`)이 배너와 한 바탕을 나눠 쓰려고
/// 바탕 없이 이 줄만 가져다 씁니다.
class TabBarRow extends StatelessWidget {
  /// 탭 줄을 만듭니다. [topBorder]는 하단 틀이 배너 유무에 따라 정합니다.
  const new({
    required this.index,
    required this.onSelect,
    this.onScrollToTop,
    this.topBorder = true,
    super.key,
  });

  /// 선택된 탭.
  final int index;

  /// 선택이 바뀔 때.
  final ValueChanged<int> onSelect;

  /// 선택된 탭을 다시 눌렀을 때.
  final VoidCallback? onScrollToTop;

  /// 위 0.5px 선을 그릴지(배너가 보이면 선이 배너 위로 가므로 false).
  final bool topBorder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [l10n.tabToday, l10n.tabCalendar, l10n.tabDiary, l10n.tabMe];
    final line = context.tokens.colors.line;
    return Semantics(
      role: SemanticsRole.tabBar,
      container: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: tabBarHeight),
        child: DecoratedBox(
          key: const ValueKey('tab-bar.top-border'),
          decoration: BoxDecoration(
            border: topBorder
                ? Border(
                    top: BorderSide(color: line, width: frameTopBorderWidth),
                  )
                : null,
          ),
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: _TabItem(
                    key: ValueKey('tab-bar.tab.$i'),
                    glyph: tabGlyphs[i],
                    label: labels[i],
                    selected: i == index,
                    onTap: () {
                      if (i == index) {
                        onScrollToTop?.call();
                        return;
                      }
                      unawaited(Haptics.selection());
                      onSelect(i);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatefulWidget {
  const new({
    required this.glyph,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final AppGlyph glyph;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> with TickerProviderStateMixin {
  // 선택된 쪽은 찍힌 상태(1), 아닌 쪽은 지워진 상태(1)로 시작해 처음에는 움직이지 않습니다.
  late final AnimationController _stamp = AnimationController(
    vsync: this,
    duration: InteractionPattern.sealStamp.duration,
    value: widget.selected ? 1 : 0,
  );
  late final AnimationController _erase = AnimationController(
    vsync: this,
    duration: InteractionPattern.sealErase.duration,
    value: widget.selected ? 0 : 1,
  )..addStatusListener(_onEraseStatus);

  void _onEraseStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) setState(() {});
  }

  @override
  void didUpdateWidget(_TabItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected == oldWidget.selected) return;
    if (widget.selected) {
      _stamp.forward(from: 0);
    } else {
      _erase.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _stamp.dispose();
    _erase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final prefs = MotionPrefs.of(context);
    final seal = Seal(
      size: tabSealSize,
      child: AppIcon(
        widget.glyph,
        size: AppIconSize.tab,
        weight: AppIconWeight.regular,
      ),
    );
    final Widget? sealLayer;
    if (widget.selected) {
      sealLayer = animate(
        InteractionPattern.sealStamp,
        t: _stamp,
        prefs: prefs,
        child: seal,
      );
    } else if (_erase.isCompleted) {
      sealLayer = null;
    } else {
      sealLayer = animate(
        InteractionPattern.sealErase,
        t: _erase,
        prefs: prefs,
        child: seal,
      );
    }
    final labelStyle = widget.selected
        ? tokens.typography.captionSm.copyWith(
            color: tokens.colors.actionPrimary,
            fontWeight: FontWeight.w600,
          )
        : tokens.typography.captionSm.copyWith(
            color: tokens.colors.textSecondary,
          );
    return Semantics(
      container: true,
      role: SemanticsRole.tab,
      selected: widget.selected,
      label: widget.label,
      onTap: widget.onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: tabMinTarget),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: tabSealSize.logical,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (!widget.selected)
                        AppIcon(
                          widget.glyph,
                          size: AppIconSize.tab,
                          color: tokens.colors.textSecondary,
                        ),
                      ?sealLayer,
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  // 글자 배율이 커져도 탭 4개가 한 줄에 들어가야 하므로(탭 너비 고정)
                  // 라벨은 줄바꿈 대신 너비에 맞춰 줄입니다.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(widget.label, maxLines: 1, style: labelStyle),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
