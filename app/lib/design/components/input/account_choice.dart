import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/elements/breathing.dart';
import 'package:myungli_diary/design/interaction/haptics.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// [AccountChoice]의 카드 하나(합칠 계정 하나). 글자는 모두 화면이 문구로 만들어 줍니다.
@immutable
final class AccountChoiceOption {
  /// 카드 글자로 만듭니다.
  const new({
    required this.name,
    required this.current,
    required this.saju,
    required this.diaryCount,
    required this.providers,
  });

  /// 호칭.
  final String name;

  /// 지금 로그인한 계정이면 true. 호칭 뒤에 "현재 계정" 알약을 둡니다.
  final bool current;

  /// 사주 요약 한 줄(`ui.account-merge.saju`). 사주가 없으면 "사주 정보 없음".
  final String saju;

  /// 일기 수("일기 12편", `accountChoiceDiaryCount`).
  final String diaryCount;

  /// 연결된 수단 이름을 구분자로 이은 글자("카카오 · Apple"). 로고는 쓰지 않습니다.
  final String providers;
}

/// 합칠 두 계정 가운데 남길 쪽 고르기(`account-choice`, 결정 V40).
///
/// `bg.sheet` 카드 두 장이고, 고름 표시는 카드 오른쪽 위 알약 동그라미입니다(V26). 처음에는
/// 어느 카드도 고르지 않습니다([selectedIndex] null, `none`). 되돌릴 수 없는 합치기라 남길
/// 계정은 사용자가 직접 고르게 합니다. 다른 카드를 누르면 [onSelected]와 selection 햅틱이 한 번
/// 나가고, 이미 고른 카드를 다시 누르면 아무 일도 없습니다.
///
/// 고른 카드는 테두리와 동그라미가 `action.primary`로 바뀌고 안에 점이 찹니다. 바뀔 때는
/// `select.seep-slide`의 스밈만 쓰고(이동 없음), `none`에서 처음 고를 때는 `appear.seep`입니다.
///
/// [onSelected]가 null이면 `disabled`(합치는 중 고름 잠금)라 누를 수 없고 모양은 그대로입니다.
/// 화면에 보인 고름과 남는 계정이 어긋나지 않게 합니다. [loading]이면 카드 두 장 크기의 빈
/// 카드가 숨쉽니다(`loading.breathe`, IA `account-merge:loading`).
///
/// 일기 수와 수단 이름 줄은 넘치면 말줄임 없이 다음 줄로 감깁니다.
class AccountChoice extends StatelessWidget {
  /// 고르기 묶음을 만듭니다. [options]는 두 개입니다. [groupLabel]은 묶음의 스크린리더 이름
  /// (`account-merge.choice.label`), [currentLabel]은 "현재 계정" 알약 글자입니다.
  const new({
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
    required this.groupLabel,
    required this.currentLabel,
    this.loading = false,
    this.identifier,
    this.animated = true,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('account-choice', {}, {
    'none',
    'selected',
    'pressed',
    'loading',
    'disabled',
  });

  /// 카드 수(`parts.group.count`).
  static const int optionCount = 2;

  /// 카드 테두리 두께(평소 투명, 고르면 `action.primary`).
  static const double cardBorderWidth = 2;

  /// 고름 표시 동그라미 지름.
  static const double markSize = 22;

  /// 고름 표시 동그라미 테두리 두께.
  static const double markBorderWidth = 1.5;

  /// 고른 카드 동그라미 안 점 지름.
  static const double dotSize = 12;

  /// 카드 안쪽 여백(`card.padding`, `space.16`).
  static const double cardPadding = Space.s16;

  /// 고름 표시의 위·오른쪽 자리(`mark.inset`, `space.16`).
  static const double markInset = Space.s16;

  /// 고름 표시와 글자 사이(사주 줄 칸 폭 256 = 320 − 16×2 − 22 − 10의 10).
  static const double _markGap = 10;

  /// [index]번째 카드를 찾는 테스트용 키.
  static Key cardKey(int index) => ValueKey('account-choice-card-$index');

  /// [index]번째 카드의 고른 테두리를 찾는 테스트용 키.
  static Key selectedBorderKey(int index) =>
      ValueKey('account-choice-selected-border-$index');

  /// [index]번째 카드의 고른 점을 찾는 테스트용 키.
  static Key dotKey(int index) => ValueKey('account-choice-dot-$index');

  /// `loading`의 [index]번째 빈 카드를 찾는 테스트용 키.
  static Key loadingCardKey(int index) =>
      ValueKey('account-choice-loading-$index');

  /// "현재 계정" 알약을 찾는 테스트용 키.
  static const Key currentPillKey = ValueKey('account-choice-current');

  /// 두 계정.
  final List<AccountChoiceOption> options;

  /// 고른 카드. null이면 아직 고르지 않음(`none`).
  final int? selectedIndex;

  /// 다른 카드를 골랐을 때. null이면 고름 잠금(`disabled`).
  final ValueChanged<int>? onSelected;

  /// 묶음의 스크린리더 이름.
  final String groupLabel;

  /// "현재 계정" 알약 글자(`accountChoiceCurrent`).
  final String currentLabel;

  /// 불러오는 중. 카드 글자 없이 빈 카드 두 장이 숨쉽니다.
  final bool loading;

  /// IA 슬롯 id. 있으면 묶음 Semantics `identifier`로 붙입니다.
  final String? identifier;

  /// false면 숨쉬기를 정지 상태로 그립니다(golden).
  final bool animated;

  void _choose(int index) {
    if (index == selectedIndex) return;
    unawaited(Haptics.selection());
    onSelected!(index);
  }

  @override
  Widget build(BuildContext context) {
    assert(
      options.length == optionCount,
      'account-choice 카드는 $optionCount장입니다.',
    );
    if (loading) {
      // skeleton과 같이 불확정 로딩으로 읽습니다.
      return Semantics(
        role: SemanticsRole.loadingSpinner,
        label: AppLocalizations.of(context).skeletonLabel,
        identifier: identifier,
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: Space.s12,
            children: [
              for (var i = 0; i < optionCount; i++)
                Breathing(
                  key: loadingCardKey(i),
                  index: i,
                  animated: animated,
                  child: const _LoadingCard(),
                ),
            ],
          ),
        ),
      );
    }
    final onSelected = this.onSelected;
    return Semantics(
      container: true,
      role: SemanticsRole.radioGroup,
      label: groupLabel,
      identifier: identifier,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.s12,
        children: [
          for (final (i, option) in options.indexed)
            _ChoiceCard(
              key: cardKey(i),
              index: i,
              option: option,
              currentLabel: currentLabel,
              selected: i == selectedIndex,
              anySelected: selectedIndex != null,
              onTap: onSelected == null ? null : () => _choose(i),
            ),
        ],
      ),
    );
  }
}

/// 카드 하나. 고름 표시(테두리·점)의 들어옴·나감을 자기 안에서 그립니다.
class _ChoiceCard extends StatefulWidget {
  const new({
    required this.index,
    required this.option,
    required this.currentLabel,
    required this.selected,
    required this.anySelected,
    required this.onTap,
    super.key,
  });

  final int index;
  final AccountChoiceOption option;
  final String currentLabel;
  final bool selected;

  /// 묶음에 고른 카드가 있는지. `none`에서 처음 고를 때를 가립니다.
  final bool anySelected;

  /// 누를 때. null이면 고름 잠금입니다.
  final VoidCallback? onTap;

  @override
  State<_ChoiceCard> createState() => _ChoiceCardState();
}

class _ChoiceCardState extends State<_ChoiceCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _seep = AnimationController(
    vsync: this,
    duration: InteractionPattern.selectSeepSlide.duration,
  )..addStatusListener(_onStatus);

  /// 지금 표시가 따르는 패턴. `none`에서 처음 고른 표시만 `appear.seep`입니다.
  InteractionPattern _pattern = InteractionPattern.selectSeepSlide;

  /// 고름이 풀린 뒤 이전 표시가 사라지는 동안 true입니다.
  bool _outgoing = false;

  static const BorderRadius _radius = BorderRadius.all(
    Radius.circular(Radii.md),
  );

  @override
  void initState() {
    super.initState();
    // 처음부터 고른 카드는 애니메이션 없이 선명하게 시작합니다.
    if (widget.selected) _seep.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _seep.duration = patternDuration(_pattern, MotionPrefs.of(context));
  }

  @override
  void didUpdateWidget(_ChoiceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected == oldWidget.selected) return;
    _outgoing = !widget.selected;
    _pattern = widget.selected && !oldWidget.anySelected
        ? InteractionPattern.appearSeep
        : InteractionPattern.selectSeepSlide;
    _seep
      ..duration = patternDuration(_pattern, MotionPrefs.of(context))
      ..forward(from: 0);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _outgoing && mounted) {
      setState(() => _outgoing = false);
    }
  }

  @override
  void dispose() {
    _seep.dispose();
    super.dispose();
  }

  String _semanticLabel(AppLocalizations l10n) {
    final option = widget.option;
    return [
      option.name,
      if (option.current) widget.currentLabel,
      option.saju,
      option.diaryCount,
      option.providers,
    ].join(l10n.a11yListSeparator);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final typography = tokens.typography;
    final option = widget.option;
    final selected = widget.selected;
    final enabled = widget.onTap != null;
    final semanticLabel = _semanticLabel(AppLocalizations.of(context));
    const tabular = [FontFeature.tabularFigures()];

    final content = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AccountChoice.cardPadding,
        AccountChoice.cardPadding,
        AccountChoice.cardPadding +
            AccountChoice.markSize +
            AccountChoice._markGap,
        AccountChoice.cardPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Space.s8,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  option.name,
                  style: typography.subtitle.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (option.current) ...[
                const SizedBox(width: Space.s8),
                _CurrentPill(label: widget.currentLabel),
              ],
            ],
          ),
          Text(
            option.saju,
            style: typography.captionLg.copyWith(
              color: colors.textSecondary,
              fontFeatures: tabular,
            ),
          ),
          // 넘치면 말줄임 없이 다음 줄로 감습니다.
          Wrap(
            spacing: Space.s12,
            // 감긴 줄 사이는 카드 안 줄 사이(`space.8`)와 같습니다.
            runSpacing: Space.s8,
            children: [
              Text(
                option.diaryCount,
                style: typography.captionLg.copyWith(
                  color: colors.textPrimary,
                  fontFeatures: tabular,
                ),
              ),
              Text(
                option.providers,
                style: typography.captionLg.copyWith(color: colors.textPrimary),
              ),
            ],
          ),
        ],
      ),
    );

    final indicator = selected || _outgoing
        ? Positioned.fill(
            child: animate(
              _pattern,
              t: _seep,
              prefs: MotionPrefs.of(context),
              // 고름 표시는 제자리에서 스미기만 합니다(이동 없음).
              options: PatternOptions(
                previousSide: Offset.zero,
                outgoing: _outgoing,
              ),
              child: _SelectedMark(index: widget.index),
            ),
          )
        : null;

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bgSheet,
        borderRadius: _radius,
        border: Border.all(
          color: Colors.transparent,
          width: AccountChoice.cardBorderWidth,
        ),
      ),
      child: Stack(
        children: [
          content,
          PositionedDirectional(
            top: AccountChoice.markInset,
            end: AccountChoice.markInset,
            child: _Ring(color: colors.line),
          ),
          ?indicator,
        ],
      ),
    );

    final target = enabled
        ? PressInkTarget(
            semanticLabel: semanticLabel,
            onTap: widget.onTap,
            borderRadius: _radius,
            inkColor: colors.textPrimary,
            child: card,
          )
        : card;

    // segmented와 같이 Flutter에 radio 역할이 없어 묶음은 `radioGroup`, 카드는
    // `inMutuallyExclusiveGroup` + `checked`로 표현하고 눌림 노드의 button 의미는 덮어씁니다.
    return Semantics(
      container: true,
      excludeSemantics: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: enabled,
      label: semanticLabel,
      onTap: widget.onTap,
      child: target,
    );
  }
}

/// 고름 표시 동그라미의 테두리.
class _Ring extends StatelessWidget {
  const new({required this.color, this.child});

  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color, width: AccountChoice.markBorderWidth),
    ),
    child: SizedBox.square(
      dimension: AccountChoice.markSize,
      child: Center(child: child),
    ),
  );
}

/// 고른 카드 위에 얹는 표시: `action.primary` 테두리 2px과 동그라미 안 점.
class _SelectedMark extends StatelessWidget {
  const new({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final primary = context.tokens.colors.actionPrimary;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            key: AccountChoice.selectedBorderKey(index),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(Radii.md)),
              border: Border.all(
                color: primary,
                width: AccountChoice.cardBorderWidth,
              ),
            ),
          ),
        ),
        PositionedDirectional(
          top: AccountChoice.markInset,
          end: AccountChoice.markInset,
          child: _Ring(
            color: primary,
            child: DecoratedBox(
              key: AccountChoice.dotKey(index),
              decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
              child: const SizedBox.square(dimension: AccountChoice.dotSize),
            ),
          ),
        ),
      ],
    );
  }
}

/// "현재 계정" 알약.
class _CurrentPill extends StatelessWidget {
  const new({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      key: AccountChoice.currentPillKey,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(Radii.full)),
        border: Border.all(color: tokens.colors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s8,
          vertical: Space.s2,
        ),
        child: Text(
          label,
          style: tokens.typography.captionSm.copyWith(
            color: tokens.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// `loading`의 빈 카드. 글줄 자리는 skeleton과 같이 그 줄 글자 높이의 60%이고, 카드 전체가
/// 숨쉽니다(바깥 [Breathing]).
class _LoadingCard extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final typography = tokens.typography;
    final scaler = MediaQuery.textScalerOf(context);

    Widget line(TextStyle style, double widthFactor) {
      final lineHeight =
          scaler.scale(style.fontSize ?? 14) * (style.height ?? 1.5);
      return SizedBox(
        height: lineHeight,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: widthFactor,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.colors.skeletonBone,
                borderRadius: const BorderRadius.all(Radius.circular(Radii.xs)),
              ),
              child: SizedBox(height: lineHeight * 0.6),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.bgSheet,
        borderRadius: const BorderRadius.all(Radius.circular(Radii.md)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AccountChoice.cardPadding,
          AccountChoice.cardPadding,
          AccountChoice.cardPadding +
              AccountChoice.markSize +
              AccountChoice._markGap,
          AccountChoice.cardPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.s8,
          children: [
            line(typography.subtitle, 0.4),
            line(typography.captionLg, 0.8),
            line(typography.captionLg, 0.6),
          ],
        ),
      ),
    );
  }
}
