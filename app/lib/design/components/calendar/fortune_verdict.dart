import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show HitTestResult, RenderPointerListener;
import 'package:myungli_diary/core/api/gen/model/score_item.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/calendar/score_row.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/seep_presence.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/sentence/hanja_glyphs.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/list_divider.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/interaction/press_ink_state.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

const AppGlyph _caretDown = AppGlyph(
  light: PhosphorIconsLight.caretDown,
  regular: PhosphorIconsRegular.caretDown,
);

const AppGlyph _caretUp = AppGlyph(
  light: PhosphorIconsLight.caretUp,
  regular: PhosphorIconsRegular.caretUp,
);

/// 길흉판정(`fortune-verdict`): 위치 막대, 세 이름, 그 아래 내역 [ScoreRow] 줄.
///
/// 막대는 왼쪽 조심할 날에서 오른쪽 잘 풀리는 날로 이어지는 그라데이션이고, 합한 점
/// [score]를 -3~+3으로 잘라 `(score + 3) / 6` 자리에 흰 원 표시를 둡니다. 표시는 움직이지
/// 않습니다(처음부터 제자리, 동작 줄이기와 상관없이 같음). 숫자는 보이지 않고 내역의 크기는
/// [ScoreRow] 점으로만 보입니다.
///
/// 내역은 처음에 늘 접혀 있고(`collapsed`), 카드 전체를 누르면(`press.ink`) 펼쳐지며
/// (`expanded`) 다시 누르면 접힙니다(V108). 맨 아래 안내 줄(`toggle`)은 누를 수 있다는 표시로
/// 접혔을 때 "내역 보기" + 아래 꺾쇠, 펼쳤을 때 "접기" + 위 꺾쇠입니다. 펼친 내역 줄의 태그는
/// 안쪽 요소라 누르면 [onItemTap](뜻 시트)만 불리고 카드는 접히지 않습니다(V61). 내역 줄은
/// `appear.seep`으로 나타나고 카드 높이는 바로 늘어나며, 접을 때는 `disappear.seep` 뒤
/// 줄어듭니다(동작 줄이기에서는 투명도만). 시트를 다시 열면 새 상태라 늘 접힘입니다.
///
/// [items]가 null(내역이 계약에 없음, `noBreakdown`)이거나 비어(`noItems`) 있으면 막대와 이름만
/// 그리고, 펼칠 것이 없어 카드를 누를 수 없으며 안내 줄도 없습니다. 내역은 더함 먼저, 뺌
/// 다음이고 같은 부호 안은 받은 순서(server 순서)이며 점수 0 항목은 그리지 않습니다. 이름
/// ([nameOf])이나 한자 글자표가 없는 항목은 줄을 그리지 않고 [onUnrenderable]로 id를
/// 알립니다(A112). 이 콜백은 다시 그릴 때마다 호출될 수 있어 부르는 쪽이 중복을 제거해야
/// 합니다. 스크린리더는 묶음 하나로 "섹션 제목, 단계 이름"을 읽고, 안내 줄을 펼침 상태가 있는
/// 버튼으로, 펼쳤을 때는 이어서 내역 줄을 읽습니다.
class FortuneVerdict extends StatefulWidget {
  /// 길흉판정 카드를 만듭니다.
  const new({
    required this.score,
    required this.nameOf,
    required this.meaningOf,
    this.items,
    this.onItemTap,
    this.onUnrenderable,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('fortune-verdict', {}, {
    'loading',
    'collapsed',
    'expanded',
    'noBreakdown',
    'noItems',
  });

  /// 막대 높이. 계약 `fortune-verdict.parts.track.height`.
  static const double trackHeight = 4;

  /// 위치 표시 지름. 계약 `parts.marker.size`.
  static const double markerSize = 18;

  /// 위치 표시 테두리 굵기. 계약 `parts.marker.border.width`.
  static const double markerBorderWidth = 2;

  /// 막대가 나타내는 점수 범위의 끝(`marker.position.clamp`).
  static const int scoreLimit = 3;

  /// 막대 키.
  static const Key trackKey = ValueKey('fortune-verdict-track');

  /// 위치 표시 키.
  static const Key markerKey = ValueKey('fortune-verdict-marker');

  /// 카드(누르는 자리) 키.
  static const Key cardKey = ValueKey('fortune-verdict-card');

  /// 안내 줄 키.
  static const Key toggleKey = ValueKey('fortune-verdict-toggle');

  /// 안내 줄 최소 높이(터치 영역).
  ///
  /// 계약 `parts.toggle.minHeight`, `card.pressable.minTarget`.
  static const double toggleMinHeight = 44;

  /// 안내 줄 위 간격. 계약 `parts.toggle.marginTop`.
  static const double toggleGap = Space.s8;

  /// 안내 줄 글자와 꺾쇠 사이. 계약 `parts.toggle.icon.gap`.
  static const double toggleIconGap = Space.s4;

  /// 이름 아래 내역 줄까지의 간격. 계약 `parts.rows.marginTop`.
  static const double rowsGap = Space.s12;

  /// 합한 점.
  final int score;

  /// 항목 id → 이름(태그 글자). 모르면 null입니다.
  final String? Function(String id) nameOf;

  /// 항목 id → 짧은 뜻. 모르면 null이고 뜻 자리를 비웁니다.
  final String? Function(String id) meaningOf;

  /// 내역. null이면 내역이 계약에 없는 상태입니다.
  final List<ScoreItem>? items;

  /// 내역 줄의 태그를 눌렀을 때.
  final FutureOr<void> Function(ScoreItem item)? onItemTap;

  /// 그릴 수 없어 건너뛴 항목 id(이름이나 글자표가 없음)를 알립니다. 다시 그릴 때마다
  /// 호출될 수 있으니 부르는 쪽이 중복을 제거합니다.
  final void Function(List<String> ids)? onUnrenderable;

  /// [score]의 막대 위 자리(0~1): `(clamp(score, -3, 3) + 3) / 6`.
  static double positionOf(int score) =>
      (score.clamp(-scoreLimit, scoreLimit) + scoreLimit) / (2 * scoreLimit);

  /// [items]를 내역 순서로: 점수 0을 빼고 더함 먼저, 뺌 다음, 같은 부호는 받은 순서.
  static List<ScoreItem> orderedItems(List<ScoreItem> items) => [
    ...items.where((item) => item.score > 0),
    ...items.where((item) => item.score < 0),
  ];

  /// 로딩 자리(`states.loading.skeleton`): 막대 자리 글줄 하나. 세 이름은 UI 글자라 바로
  /// 그립니다. 처음에는 접혀 있어 내역 뼈와 안내 줄은 두지 않습니다(V108).
  static Widget skeleton({int index = 0, bool animated = true}) => Builder(
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SkeletonTextLines(index: index, animated: animated, widthFactor: 1),
            _Names(l10n: l10n),
          ],
        ),
      );
    },
  );

  /// 단계 이름: -2 이하 조심할 날, -1~+1 무난한 날, +2 이상 잘 풀리는 날(달력 범례와 같은 낱말).
  static String levelNameOf(AppLocalizations l10n, int score) {
    if (score <= -2) return l10n.calendarLegendBodyCaution;
    if (score >= 2) return l10n.calendarLegendBodyGood;
    return l10n.calendarLegendBodyNeutral;
  }

  @override
  State<FortuneVerdict> createState() => _FortuneVerdictState();
}

class _FortuneVerdictState extends State<FortuneVerdict>
    with TickerProviderStateMixin, PressInkState<FortuneVerdict> {
  /// 내역을 펼쳤는지. 시트를 열 때마다 새 상태라 처음에는 늘 접힘입니다.
  bool _expanded = false;

  /// 이번 누름에서 카드 잉크를 시작했는지.
  bool _inked = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  /// 카드 잉크를 시작합니다. 안쪽 누르는 자리(내역 태그)를 눌렀으면 그 안에만 번지도록
  /// 카드 잉크는 시작하지 않습니다(V61). 안쪽이 이기는지는 손을 뗄 때 정해지는데, 길게
  /// 누르면 바깥 `onTapDown`도 먼저 불리기 때문입니다.
  void _tapDown(TapDownDetails details) {
    if (_pressesInner(details.globalPosition)) return;
    _inked = true;
    pressInkDown(details);
  }

  void _releaseInk() {
    if (!_inked) return;
    _inked = false;
    pressInkUp();
  }

  void _tapUp(TapUpDetails details) {
    _releaseInk();
    _toggle();
  }

  /// [position]의 hit test 경로에서 이 카드보다 안쪽에 포인터를 받는 자리
  /// (`GestureDetector`의 `RenderPointerListener`)가 카드 자신 말고 더 있는지.
  bool _pressesInner(Offset position) {
    final root = context.findRenderObject();
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(
      result,
      position,
      View.of(context).viewId,
    );
    var listeners = 0;
    // 경로는 깊은 쪽부터라 이 위젯의 뿌리에 닿을 때까지가 카드 안쪽입니다.
    for (final entry in result.path) {
      final target = entry.target;
      if (identical(target, root)) break;
      if (target is RenderPointerListener && target.onPointerDown != null) {
        listeners++;
      }
    }
    // 하나는 카드 자신의 GestureDetector입니다.
    return listeners > 1;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = _rows();
    final names = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: _Track(position: FortuneVerdict.positionOf(widget.score)),
        ),
        ExcludeSemantics(child: _Names(l10n: l10n)),
      ],
    );
    final label = [
      l10n.daySheetVerdictTitle,
      FortuneVerdict.levelNameOf(l10n, widget.score),
    ].join(l10n.a11yListSeparator);
    // 펼칠 내역이 없으면(noBreakdown, noItems) 카드는 누를 수 없고 안내 줄도 없습니다.
    if (rows.isEmpty) {
      return Semantics(
        container: true,
        label: label,
        child: _Card(key: FortuneVerdict.cardKey, child: names),
      );
    }
    final card = _Card(
      key: FortuneVerdict.cardKey,
      // 안내 줄이 카드 안쪽 아래 여백 자리를 대신합니다(V108).
      bottomPadding: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          names,
          SeepPresence(
            present: _expanded,
            child: Padding(
              padding: const EdgeInsets.only(top: FortuneVerdict.rowsGap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rows,
              ),
            ),
          ),
          const SizedBox(height: FortuneVerdict.toggleGap),
          const ListDivider(),
          _Toggle(expanded: _expanded, onTap: _toggle),
        ],
      ),
    );
    return Semantics(
      container: true,
      label: label,
      // 키보드 포커스와 확정은 다른 press.ink 대상(PressInkTarget)과 같습니다. 포커스 테두리
      // (`focus.ring`)는 입력 칸의 패턴이라 두지 않습니다.
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _toggle();
              return null;
            },
          ),
        },
        // 카드 전체가 누르는 자리입니다. 안쪽 태그는 더 깊은 누르는 자리라 먼저 이겨 뜻 시트만
        // 열립니다(V61). 스크린리더 동작은 안내 줄 버튼 하나에만 둡니다.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapDown: _tapDown,
          onTapUp: _tapUp,
          onTapCancel: _releaseInk,
          child: animate(
            InteractionPattern.pressInk,
            t: pressInk,
            prefs: MotionPrefs.of(context),
            options: PatternOptions(
              origin: pressInkOrigin,
              release: pressInkRelease,
              inkColor: context.tokens.colors.textPrimary,
              borderRadius: const BorderRadius.all(Radius.circular(Radii.lg)),
            ),
            child: card,
          ),
        ),
      ),
    );
  }

  /// 그릴 수 있는 내역 줄(줄마다 위에 구분선). 그릴 수 없는 항목은 그린 뒤에 알립니다.
  List<Widget> _rows() {
    final rows = <Widget>[];
    final skipped = <String>[];
    final onItemTap = widget.onItemTap;
    for (final item in FortuneVerdict.orderedItems(widget.items ?? const [])) {
      final name = widget.nameOf(item.id);
      final glyph = HanjaGlyphs.forScoreItem(item.id);
      if (name == null || glyph == null) {
        skipped.add(item.id);
        continue;
      }
      rows
        ..add(const ListDivider())
        ..add(
          ScoreRow.verdict(
            glyph: glyph,
            name: name,
            meaning: widget.meaningOf(item.id) ?? '',
            score: item.score,
            onTagTap: onItemTap == null ? null : () => onItemTap(item),
          ),
        );
    }
    final report = widget.onUnrenderable;
    if (skipped.isNotEmpty && report != null) {
      // build 중 상태를 바꾸지 않도록 그린 뒤에 알립니다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        report(skipped);
      });
    }
    return rows;
  }
}

/// 맨 아래 안내 줄(`parts.toggle`): 접혔을 때 "내역 보기" + 아래 꺾쇠, 펼쳤을 때 "접기" + 위
/// 꺾쇠. 카드 전체가 버튼이라는 표시이고, 스크린리더는 펼침 상태가 있는 버튼으로 읽습니다.
class _Toggle extends StatelessWidget {
  const new({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final style = tokens.typography.captionLg.copyWith(
      color: tokens.colors.textSecondary,
    );
    final text = expanded
        ? l10n.daySheetVerdictCollapse
        : l10n.daySheetVerdictExpand;
    return Semantics(
      container: true,
      button: true,
      expanded: expanded,
      label: text,
      identifier: expanded
          ? SlotIds.daySheetVerdictCollapse
          : SlotIds.daySheetVerdictExpand,
      onTap: onTap,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          key: FortuneVerdict.toggleKey,
          constraints: const BoxConstraints(
            minHeight: FortuneVerdict.toggleMinHeight,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: FortuneVerdict.toggleIconGap,
            children: [
              Flexible(
                child: Text(text, textAlign: TextAlign.center, style: style),
              ),
              AppIcon(
                expanded ? _caretUp : _caretDown,
                size: AppIconSize.adjacentText(style.fontSize!),
                weight: AppIconWeight.regular,
                color: tokens.colors.textSecondary,
                scalesWithText: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `bg.base` 카드. 안내 줄이 있으면 아래 여백([bottomPadding])을 그 줄이 대신합니다.
class _Card extends StatelessWidget {
  const new({required this.child, this.bottomPadding = Space.s16, super.key});

  final Widget child;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.tokens.colors.bgBase,
      borderRadius: const BorderRadius.all(Radius.circular(Radii.lg)),
    ),
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        Space.s16,
        Space.s16,
        Space.s16,
        bottomPadding,
      ),
      child: child,
    ),
  );
}

/// 그라데이션 막대와 위치 표시. 양끝을 표시 반지름만큼 들여 표시가 카드 밖으로 나가지 않습니다.
class _Track extends StatelessWidget {
  const new({required this.position});

  final double position;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    const radius = FortuneVerdict.markerSize / 2;
    return SizedBox(
      height: FortuneVerdict.markerSize,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final span = constraints.maxWidth - FortuneVerdict.markerSize;
          return Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: radius),
                child: DecoratedBox(
                  key: FortuneVerdict.trackKey,
                  decoration: BoxDecoration(
                    gradient: tokens.gradients.verdictTrack,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(Radii.full),
                    ),
                  ),
                  child: const SizedBox(
                    height: FortuneVerdict.trackHeight,
                    width: double.infinity,
                  ),
                ),
              ),
              // 움직이지 않는 표시라 위치만 계산해 바로 놓습니다(동작 줄이기와 상관없음).
              Positioned.directional(
                textDirection: Directionality.of(context),
                start: span * position,
                top: 0,
                child: DecoratedBox(
                  key: FortuneVerdict.markerKey,
                  decoration: BoxDecoration(
                    color: tokens.colors.bgSheet,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: tokens.colors.actionPrimary,
                      width: FortuneVerdict.markerBorderWidth,
                    ),
                  ),
                  child: const SizedBox(
                    width: FortuneVerdict.markerSize,
                    height: FortuneVerdict.markerSize,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 막대 아래 세 이름(조심할 날, 무난한 날, 잘 풀리는 날).
class _Names extends StatelessWidget {
  const new({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final style = tokens.typography.captionMd.copyWith(
      color: tokens.colors.textSecondary,
    );
    return Padding(
      padding: const EdgeInsets.only(top: Space.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              l10n.calendarLegendBodyCaution,
              textAlign: TextAlign.start,
              style: style,
            ),
          ),
          Expanded(
            child: Text(
              l10n.calendarLegendBodyNeutral,
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
          Expanded(
            child: Text(
              l10n.calendarLegendBodyGood,
              textAlign: TextAlign.end,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}
