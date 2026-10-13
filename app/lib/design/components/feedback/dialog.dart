import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/text_action.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/interaction/haptics.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 확인 창 변형.
enum DialogVariant {
  /// 일반 확인.
  confirm,

  /// 되돌릴 수 없는 동작(일기 삭제, 계정 삭제). 빨간색 없이 경고 표시와 굵은 확정 글자로 구분합니다.
  destructive,
}

/// 확인 창(`dialog`)의 명세 요약.
abstract final class MyungliDialog {
  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'dialog',
    {'confirm', 'destructive'},
    {'opening', 'closing', 'pressed'},
  );

  /// 좌우 바깥 여백(px).
  static const double marginX = 28;
}

/// 확인 창을 열고 확정이면 true, 취소·바깥 누르기·뒤로 가기면 false를 돌려줍니다.
///
/// destructive는 처음 초점이 취소에 있고 바깥을 눌러도 닫히지 않으며, 확정 버튼을 누르면
/// 햅틱 medium이 울립니다.
Future<bool> showMyungliDialog(
  BuildContext context, {
  required DialogVariant variant,
  required String title,
  required String confirm,
  required String cancel,
  String? body,
}) async {
  final result = await Navigator.of(context, rootNavigator: true).push<bool>(
    _DialogRoute(
      variant: variant,
      title: title,
      body: body,
      confirm: confirm,
      cancel: cancel,
      prefs: MotionPrefs.of(context),
      scrim: context.tokens.colors.scrim,
      barrierLabel: AppLocalizations.of(context).sheetDismiss,
    ),
  );
  return result ?? false;
}

class _DialogRoute extends PopupRoute<bool> {
  new({
    required this.variant,
    required this.title,
    required this.body,
    required this.confirm,
    required this.cancel,
    required this.prefs,
    required this.scrim,
    required this.barrierLabel,
  });

  final DialogVariant variant;
  final String title;
  final String? body;
  final String confirm;
  final String cancel;
  final MotionPrefs prefs;
  final Color scrim;

  late final Animation<double> _exit = ReverseAnimation(animation!);

  @override
  final String barrierLabel;

  @override
  Color get barrierColor => scrim;

  @override
  bool get barrierDismissible => variant == DialogVariant.confirm;

  @override
  Duration get transitionDuration => InteractionPattern.appearSeep.duration;

  @override
  Duration get reverseTransitionDuration =>
      InteractionPattern.disappearSeep.duration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return MotionPrefsScope(
      prefs: prefs,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MyungliDialog.marginX,
            ),
            child: DialogCard(
              variant: variant,
              title: title,
              body: body,
              confirm: confirm,
              cancel: cancel,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final closing = animation.status == AnimationStatus.reverse;
        return animate(
          closing
              ? InteractionPattern.disappearSeep
              : InteractionPattern.appearSeep,
          t: closing ? _exit : animation,
          prefs: prefs,
          child: child!,
        );
      },
    );
  }
}

/// 확인 창 카드 하나(제목·본문·버튼). 열고 닫는 움직임은 [showMyungliDialog]가 입힙니다.
class DialogCard extends StatelessWidget {
  /// 카드를 만듭니다.
  const new({
    required this.variant,
    required this.title,
    required this.confirm,
    required this.cancel,
    this.body,
    super.key,
  });

  /// 변형.
  final DialogVariant variant;

  /// 제목.
  final String title;

  /// 본문(없으면 생략).
  final String? body;

  /// 확정 버튼 글자.
  final String confirm;

  /// 취소 버튼 글자.
  final String cancel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final destructive = variant == DialogVariant.destructive;
    final titleStyle = tokens.typography.subtitle.copyWith(
      color: colors.textPrimary,
    );
    final confirmStyle = tokens.typography.labelLg.copyWith(
      color: destructive ? colors.textPrimary : colors.actionPrimary,
      fontWeight: destructive ? FontWeight.w700 : null,
    );
    final cancelStyle = tokens.typography.labelLg.copyWith(
      color: destructive ? colors.actionPrimary : colors.textSecondary,
    );

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      role: SemanticsRole.alertDialog,
      label: title,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.bgSheet,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Space.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: DefaultTextStyle(
                  style: titleStyle,
                  child: Row(
                    children: [
                      if (destructive) ...[
                        const AppIcon.caution(),
                        const SizedBox(width: Space.s8),
                      ],
                      Expanded(child: Text(title)),
                    ],
                  ),
                ),
              ),
              if (body != null) ...[
                const SizedBox(height: Space.s8),
                Text(
                  body!,
                  style: tokens.typography.bodyUi.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: Space.s20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: Space.s8,
                runSpacing: Space.s8,
                children: [
                  FeedbackTextAction(
                    label: cancel,
                    style: cancelStyle,
                    autofocus: destructive,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  FeedbackTextAction(
                    label: confirm,
                    style: confirmStyle,
                    autofocus: !destructive,
                    onPressed: () {
                      if (destructive) unawaited(Haptics.medium());
                      Navigator.of(context).pop(true);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
