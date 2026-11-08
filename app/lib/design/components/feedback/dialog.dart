import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
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

  /// 되돌릴 수 없는 동작(일기 삭제, 계정 삭제). 빨간색 없이 제목 앞 경고 표시와 본문색 바탕 확정 버튼으로 구분합니다.
  destructive,

  /// 고를 것 없이 읽었다는 확인만 받는 안내(`login.discard.notice`). 확인 버튼 하나이고,
  /// 바깥 누르기·뒤로 가기도 확인과 같습니다. [showMyungliNotice]로 엽니다.
  notice,
}

/// 확인 창(`dialog`)의 명세 요약.
abstract final class MyungliDialog {
  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'dialog',
    {'confirm', 'destructive', 'notice'},
    {'opening', 'closing', 'pressed'},
  );

  /// 좌우 바깥 여백(px).
  static const double marginX = Space.s24;
}

/// 확인 창을 열고 확정이면 true, 취소·바깥 누르기·뒤로 가기면 false를 돌려줍니다.
///
/// 버튼 두 개짜리 창에는 처음 초점을 받는 버튼이 없습니다(V41). destructive는 바깥을 눌러도
/// 닫히지 않고(뒤로 가기는 취소), 확정 버튼을 누르면 햅틱 medium이 울립니다.
/// [identifier]는 창이 채우는 IA 슬롯 id입니다.
/// 확인 버튼 하나짜리 안내는 [showMyungliNotice]를 씁니다.
Future<bool> showMyungliDialog(
  BuildContext context, {
  required DialogVariant variant,
  required String title,
  required String confirm,
  required String cancel,
  String? body,
  String? identifier,
}) async {
  assert(variant != DialogVariant.notice, '안내는 showMyungliNotice로 엽니다.');
  final result = await _pushDialog(
    context,
    variant: variant,
    title: title,
    body: body,
    identifier: identifier,
    confirm: confirm,
    cancel: cancel,
  );
  return result ?? false;
}

/// 확인 버튼 하나짜리 안내(`dialog` `notice`)를 열고, 닫히면 끝납니다.
///
/// 고를 것이 없으므로 확인·바깥 누르기·뒤로 가기가 모두 같은 "읽었음"입니다. 첫 초점은
/// 확인 버튼입니다. [body]는 안내 문장(창이 늘어나는 본문)이고, [title]은 있을 때만
/// 그립니다. 제목이 없으면 창의 스크린리더 이름은 본문입니다.
Future<void> showMyungliNotice(
  BuildContext context, {
  required String body,
  required String confirm,
  String? title,
  String? identifier,
}) async {
  await _pushDialog(
    context,
    variant: DialogVariant.notice,
    title: title,
    body: body,
    identifier: identifier,
    confirm: confirm,
    cancel: null,
  );
}

Future<bool?> _pushDialog(
  BuildContext context, {
  required DialogVariant variant,
  required String? title,
  required String? body,
  required String? identifier,
  required String confirm,
  required String? cancel,
}) {
  // 시트와 같은 navigator에 쌓습니다(셸 밖, 앱 안의 앱에서는 그 앱 안).
  return overlayNavigatorOf(context).push<bool>(
    _DialogRoute(
      variant: variant,
      title: title,
      body: body,
      identifier: identifier,
      confirm: confirm,
      cancel: cancel,
      prefs: MotionPrefs.of(context),
      scrim: context.tokens.colors.scrim,
      barrierLabel: AppLocalizations.of(context).sheetDismiss,
    ),
  );
}

class _DialogRoute extends PopupRoute<bool> {
  new({
    required this.variant,
    required this.title,
    required this.body,
    required this.identifier,
    required this.confirm,
    required this.cancel,
    required this.prefs,
    required this.scrim,
    required this.barrierLabel,
  });

  final DialogVariant variant;
  final String? title;
  final String? body;
  final String? identifier;
  final String confirm;
  final String? cancel;
  final MotionPrefs prefs;
  final Color scrim;

  late final Animation<double> _exit = ReverseAnimation(animation!);

  @override
  final String barrierLabel;

  @override
  Color get barrierColor => scrim;

  @override
  bool get barrierDismissible => variant != DialogVariant.destructive;

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
            // 확인 창은 셸 바깥 navigator에 쌓여 셸의 Material을 벗어나므로, 글자가
            // MaterialApp의 오류 스타일(노란 이중 밑줄)을 받지 않게 그리지 않는 Material
            // 조상을 둡니다(시트·탭 셸과 같은 방식).
            child: Material(
              type: MaterialType.transparency,
              child: _withIdentifier(
                DialogCard(
                  variant: variant,
                  title: title,
                  body: body,
                  confirm: confirm,
                  cancel: cancel,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// IA 슬롯 id가 있으면 창 뿌리에 Key와 Semantics `identifier`로 붙입니다.
  Widget _withIdentifier(Widget card) {
    final id = identifier;
    if (id == null) return card;
    return KeyedSubtree(
      key: ValueKey(id),
      child: Semantics(identifier: id, container: true, child: card),
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

/// 확인 창 카드 하나(제목·본문·버튼). 열고 닫는 움직임은 [showMyungliDialog]·
/// [showMyungliNotice]가 입힙니다.
///
/// [DialogVariant.notice]는 취소 버튼이 없고(`parts.cancel.visible: false`) 확인 버튼이
/// 오른쪽 끝에 놓이며 처음 초점을 받습니다. 제목은 없어도 되고, 그때 창 이름은 본문입니다.
class DialogCard extends StatelessWidget {
  /// 카드를 만듭니다. [cancel]은 [DialogVariant.notice]에서만 없고 다른 변형에서는 필수,
  /// [title]은 [DialogVariant.notice]에서만 생략할 수 있습니다.
  const new({
    required this.variant,
    required this.confirm,
    this.title,
    this.cancel,
    this.body,
    super.key,
  }) : assert(
         (variant == DialogVariant.notice) == (cancel == null),
         'notice만 취소 버튼이 없습니다.',
       ),
       assert(
         title != null || (variant == DialogVariant.notice && body != null),
         '제목은 notice에서만 생략하고, 그때 본문이 창 이름이 됩니다.',
       );

  /// 변형.
  final DialogVariant variant;

  /// 제목(notice는 없어도 됨).
  final String? title;

  /// 본문(없으면 생략).
  final String? body;

  /// 확정 버튼 글자.
  final String confirm;

  /// 취소 버튼 글자(notice는 없음).
  final String? cancel;

  /// 취소 버튼을 찾는 테스트용 키.
  static const Key cancelKey = ValueKey('dialog-cancel');

  /// 확정 버튼을 찾는 테스트용 키.
  static const Key confirmKey = ValueKey('dialog-confirm');

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final destructive = variant == DialogVariant.destructive;
    final title = this.title;
    final titleStyle = tokens.typography.subtitle.copyWith(
      color: colors.textPrimary,
    );

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      role: SemanticsRole.alertDialog,
      label: title ?? body,
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
              if (title != null)
                Semantics(
                  header: true,
                  child: DefaultTextStyle(
                    style: titleStyle,
                    child: Row(
                      children: [
                        if (destructive) ...[
                          // `alert` 제목 앞 경고 표시는 `leadingSize` 20 고정입니다.
                          const AppIcon.caution(size: AppIconSize.s20),
                          const SizedBox(width: Space.s8),
                        ],
                        Expanded(child: Text(title)),
                      ],
                    ),
                  ),
                ),
              if (body != null) ...[
                if (title != null) const SizedBox(height: Space.s8),
                // 큰 글자·긴 본문에서는 본문만 스크롤하고 제목·버튼은 늘 보입니다.
                Flexible(
                  child: SingleChildScrollView(
                    primary: false,
                    // 제목이 없으면 본문이 창 이름(라벨)이라 글자 노드는 읽지 않습니다.
                    // 같은 문장을 두 번 읽지 않게 합니다(명세 a11y: label 제목, description 본문).
                    child: ExcludeSemantics(
                      excluding: title == null,
                      child: Text(
                        body!,
                        style: tokens.typography.bodyUi.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: Space.s24),
              _Actions(
                cancelLabel: cancel,
                confirmLabel: confirm,
                destructive: destructive,
                autofocusConfirm: variant == DialogVariant.notice,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 확인 창 버튼 줄(`dialog` `actions`): 같은 폭 두 버튼(취소 왼쪽, 확정 오른쪽), 높이 44,
/// 사이 `space.8`, 좌우 안쪽 `space.12`(V65).
///
/// 두 글자 가운데 하나라도 가로 칸에 한 줄로 들어가지 않으면 세로로 쌓고 확정이 위입니다.
/// 확정만 있는 notice는 확정 하나가 폭 전체입니다.
class _Actions extends StatelessWidget {
  const new({
    required this.cancelLabel,
    required this.confirmLabel,
    required this.destructive,
    required this.autofocusConfirm,
  });

  final String? cancelLabel;
  final String confirmLabel;
  final bool destructive;
  final bool autofocusConfirm;

  /// 버튼 줄 너비가 [width]일 때 두 글자가 가로 칸에 한 줄로 들어가는지.
  bool _fitsSideBySide(BuildContext context, double width) {
    final cancelLabel = this.cancelLabel;
    if (cancelLabel == null) return true;
    final slot = (width - Space.s8) / 2 - Space.s12 * 2;
    final style = context.tokens.typography.labelLg;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double measure(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final textWidth = painter.width;
      painter.dispose();
      return textWidth;
    }

    return measure(cancelLabel) <= slot && measure(confirmLabel) <= slot;
  }

  @override
  Widget build(BuildContext context) {
    final cancelLabel = this.cancelLabel;
    final confirm = PrimaryButton.dialogAction(
      key: DialogCard.confirmKey,
      label: confirmLabel,
      variant: destructive
          ? PrimaryButtonVariant.destructive
          : PrimaryButtonVariant.filled,
      autofocus: autofocusConfirm,
      onPressed: () {
        if (destructive) unawaited(Haptics.medium());
        Navigator.of(context).pop(true);
      },
    );
    if (cancelLabel == null) return confirm;
    final cancel = _CancelButton(
      label: cancelLabel,
      onPressed: () => Navigator.of(context).pop(false),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!_fitsSideBySide(context, constraints.maxWidth)) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              confirm,
              const SizedBox(height: Space.s8),
              cancel,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: cancel),
            const SizedBox(width: Space.s8),
            Expanded(child: confirm),
          ],
        );
      },
    );
  }
}

/// 취소 버튼: `fill.soft` 바탕에 `text.primary` 글자(`dialog` `cancel`). 흰 확인 창 위에서
/// 반투명 `chip.bg`는 보이지 않아 옅은 채움을 씁니다(V74).
class _CancelButton extends StatelessWidget {
  const new({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    const radius = BorderRadius.all(Radius.circular(Radii.md));
    final style = tokens.typography.labelLg.copyWith(
      color: tokens.colors.textPrimary,
    );
    return PressInkTarget(
      key: DialogCard.cancelKey,
      semanticLabel: label,
      onTap: onPressed,
      borderRadius: radius,
      inkColor: tokens.colors.textPrimary,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: PrimaryButton.compactHeight,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.colors.fillSoft,
            borderRadius: radius,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.s12,
              vertical: Space.s8,
            ),
            child: Center(
              heightFactor: 1,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: style,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
