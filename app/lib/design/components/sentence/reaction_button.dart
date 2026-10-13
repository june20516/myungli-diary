import 'dart:async';

import 'package:flutter/material.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/sentence/vertical_hit_slop.dart';
import 'package:myungli_diary/design/elements/seal.dart';
import 'package:myungli_diary/design/interaction/haptics.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

/// 문장 반응(좋아요, `reaction-button`). 누르면 낙관 도장이 낙관적으로 찍힙니다.
///
/// 하트 Light(`text.secondary`) 22px, 터치 44px. 켜면 `seal` `fill` 34px가
/// `seal.stamp`로 찍히고 하트가 Regular `action.on-primary`로 바뀝니다(light 햅틱).
/// 끄면 `seal.erase`이고 햅틱은 없습니다. 문장 아래 오른쪽 끝에 홀로 두고
/// 근거 보기 링크와 같은 줄에 두지 않습니다. 총운 문장에만 붙습니다(D57).
class ReactionButton extends StatefulWidget {
  /// 반응 버튼을 만듭니다. 켜짐 여부는 호출하는 쪽이 들고 있습니다(낙관 갱신).
  const new({
    required this.on,
    required this.onChanged,
    required this.semanticsLabel,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('reaction-button', {}, {
    'on',
    'off',
  });

  /// 터치 영역을 찾는 테스트용 키.
  static const Key targetKey = ValueKey('reaction-target');

  /// 켜진 도장을 찾는 테스트용 키.
  static const Key sealKey = ValueKey('reaction-seal');

  static const double _heartSize = 22;

  /// 지금 켜져 있는지.
  final bool on;

  /// 눌러서 바뀐 값. 켜면 true, 끄면 false입니다.
  final ValueChanged<bool> onChanged;

  /// 스크린리더 라벨(ARB 문구). 켜짐 여부는 토글 상태로 따로 알립니다.
  final String semanticsLabel;

  @override
  State<ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<ReactionButton>
    with TickerProviderStateMixin {
  // 켜진 쪽은 찍힌 상태(1), 꺼진 쪽은 지워진 상태(1)로 시작해 처음에는 움직이지 않습니다.
  late final AnimationController _stamp = AnimationController(
    vsync: this,
    duration: InteractionPattern.sealStamp.duration,
    value: widget.on ? 1 : 0,
  );
  late final AnimationController _erase = AnimationController(
    vsync: this,
    duration: InteractionPattern.sealErase.duration,
    value: widget.on ? 0 : 1,
  )..addStatusListener(_onEraseStatus);

  void _onEraseStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) setState(() {});
  }

  @override
  void didUpdateWidget(ReactionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.on == oldWidget.on) return;
    if (widget.on) {
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

  void _toggle() {
    final next = !widget.on;
    // 켤 때만 손끝에 알립니다. 끌 때는 햅틱이 없습니다.
    if (next) unawaited(Haptics.light());
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.tokens.colors;
    final prefs = MotionPrefs.of(context);
    final heartOff = Icon(
      PhosphorIconsLight.heart,
      size: ReactionButton._heartSize,
      color: colors.textSecondary,
    );
    final seal = KeyedSubtree(
      key: ReactionButton.sealKey,
      child: Seal(
        size: SealSize.row,
        child: Icon(
          PhosphorIconsRegular.heart,
          size: ReactionButton._heartSize,
          color: colors.actionOnPrimary,
        ),
      ),
    );
    final Widget? sealLayer;
    if (widget.on) {
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
    return Padding(
      padding: const EdgeInsets.only(top: Space.s8),
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        // 라벨 슬롯(`today.reaction.label`)을 이 버튼이 그립니다.
        child: KeyedSubtree(
          key: const ValueKey(SlotIds.todayReactionLabel),
          child: Semantics(
            container: true,
            button: true,
            toggled: widget.on,
            identifier: SlotIds.todayReactionLabel,
            label: widget.semanticsLabel,
            onTap: _toggle,
            child: ExcludeSemantics(
              // 키보드·스위치 접근도 같은 동작으로 켜고 끕니다.
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
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggle,
                  child: SizedBox.square(
                    key: ReactionButton.targetKey,
                    dimension: sentenceMinTarget,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [if (!widget.on) heartOff, ?sealLayer],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
