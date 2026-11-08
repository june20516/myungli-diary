import 'package:flutter/material.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

const AppGlyph _caretDown = AppGlyph(
  light: PhosphorIconsLight.caretDown,
  regular: PhosphorIconsRegular.caretDown,
);

/// 키보드 내리기 버튼(`keyboard.dismiss`, V68): 44 원형, `bg.sheet` 바탕에 `shadow.raised`,
/// `caret-down` Regular 20. 누르면 [focus]의 초점을 풉니다.
///
/// 아이콘은 단독이라 글자 배율을 따르지 않습니다. 보일지는 [KeyboardDismissOverlay]가 정합니다.
class KeyboardDismissButton extends StatelessWidget {
  /// 버튼을 만듭니다.
  const new({required this.focus, super.key});

  /// 내릴 입력칸의 초점.
  final FocusNode focus;

  /// 버튼 지름(`keyboard.dismiss` `size`).
  static const double diameter = 44;

  @override
  Widget build(BuildContext context) {
    final colors = context.tokens.colors;
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).keyboardDismiss,
      excludeSemantics: true,
      onTap: focus.unfocus,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: focus.unfocus,
        child: Container(
          width: diameter,
          height: diameter,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.bgSheet,
            shape: BoxShape.circle,
            boxShadow: Shadows.raised,
          ),
          child: AppIcon(
            _caretDown,
            size: AppIconSize.s20,
            weight: AppIconWeight.regular,
            color: colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// [child] 위에 키보드 내리기 버튼을 겹칩니다(`keyboard.dismiss` `where`).
///
/// 키보드가 보이고([View]의 viewInsets 아래쪽이 0보다 큼) [focus]에 초점이 있는 동안만
/// 버튼을 그립니다. 위치는 키보드 inset 위 `space.12`, 오른쪽 `space.20`입니다.
/// inset은 OS 자동완성, 추천 줄을 포함한 플랫폼 값입니다.
///
/// Scaffold 안(기본 `resizeToAvoidBottomInset: true`)에서도, 바깥이나
/// `resizeToAvoidBottomInset: false`에서도 같은 자리에 뜹니다. 키보드 inset은 `View`의 원래 값을
/// 읽고, 조상이 이미 소비한 만큼(`MediaQuery.viewInsets`에 남지 않은 만큼)은 [child] 영역이
/// 줄어든 것으로 보아 뺍니다. [child]는 키보드 위쪽 영역 전체를 채워야 합니다.
class KeyboardDismissOverlay extends StatelessWidget {
  /// [child]를 감쌉니다.
  const new({required this.focus, required this.child, super.key});

  /// 입력칸의 초점.
  final FocusNode focus;

  /// 감쌀 화면.
  final Widget child;

  /// 키보드 위 간격.
  static const double gapAboveKeyboard = Space.s12;

  /// 화면 오른쪽 간격.
  static const double gapEnd = Space.s20;

  @override
  Widget build(BuildContext context) {
    final view = View.of(context);
    final keyboard = view.viewInsets.bottom / view.devicePixelRatio;
    final unconsumed = MediaQuery.viewInsetsOf(context).bottom;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (keyboard > 0)
          ListenableBuilder(
            listenable: focus,
            builder: (context, _) => focus.hasFocus
                ? PositionedDirectional(
                    end: gapEnd,
                    bottom: unconsumed + gapAboveKeyboard,
                    child: KeyboardDismissButton(focus: focus),
                  )
                : const SizedBox.shrink(),
          ),
      ],
    );
  }
}
