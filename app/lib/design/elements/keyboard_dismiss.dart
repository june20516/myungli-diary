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

/// 입력칸 하나에 키보드 내리기 버튼을 붙입니다(`keyboard.dismiss` `where`: `text-field focused`,
/// `diary-editor focused`).
///
/// [KeyboardDismissOverlay]와 달리 화면을 감싸지 않습니다. 키보드가 보이고 [focus]에 초점이
/// 있는 동안만 버튼을 root [Overlay]에 띄워, 칸이 Scaffold 안 어디에 있든 키보드 inset
/// (`View`의 원래 값, OS 자동완성과 추천 줄 포함) 위 `space.12`, 화면 오른쪽 `space.20`에
/// 놓습니다. 키보드 높이가 바뀌면 따라 움직이고, 내려가면 사라집니다.
class KeyboardDismissPortal extends StatefulWidget {
  /// [child](입력칸)에 붙입니다.
  const new({required this.focus, required this.child, super.key});

  /// 입력칸의 초점.
  final FocusNode focus;

  /// 입력칸.
  final Widget child;

  /// 입력칸 스크롤 아래 여백(`scrollPadding`)에 더할 버튼 자리: 버튼 44 + 키보드 위 간격.
  /// 커서 줄이 버튼에 가리지 않습니다.
  static const double reservedHeight =
      KeyboardDismissButton.diameter + KeyboardDismissOverlay.gapAboveKeyboard;

  @override
  State<KeyboardDismissPortal> createState() => _KeyboardDismissPortalState();
}

class _KeyboardDismissPortalState extends State<KeyboardDismissPortal>
    with WidgetsBindingObserver {
  final OverlayPortalController _portal = OverlayPortalController();
  double _keyboard = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.focus.addListener(_sync);
    // 이미 초점이 있는 칸으로 만들어지면 첫 프레임 뒤에 맞춥니다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _keyboard = _keyboardOf(context);
  }

  @override
  void didUpdateWidget(KeyboardDismissPortal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focus != widget.focus) {
      oldWidget.focus.removeListener(_sync);
      widget.focus.addListener(_sync);
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    }
  }

  @override
  void dispose() {
    widget.focus.removeListener(_sync);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final keyboard = _keyboardOf(context);
    if (keyboard == _keyboard) return;
    setState(() => _keyboard = keyboard);
    _sync();
  }

  /// 조상이 소비했는지와 상관없는 플랫폼 키보드 inset(논리 px).
  static double _keyboardOf(BuildContext context) {
    final view = View.of(context);
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  void _sync() {
    if (!mounted) return;
    final visible = widget.focus.hasFocus && _keyboard > 0;
    if (visible == _portal.isShowing) return;
    if (visible) {
      _portal.show();
    } else {
      _portal.hide();
    }
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _portal,
    overlayLocation: OverlayChildLocation.rootOverlay,
    overlayChildBuilder: (context) => PositionedDirectional(
      end: KeyboardDismissOverlay.gapEnd,
      bottom: _keyboard + KeyboardDismissOverlay.gapAboveKeyboard,
      // 칸 밖 누르기로 보지 않게 칸과 같은 누름 묶음에 넣습니다(초점은 버튼이 풉니다).
      child: TextFieldTapRegion(
        child: KeyboardDismissButton(focus: widget.focus),
      ),
    ),
    child: widget.child,
  );
}
