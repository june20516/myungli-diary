import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

const AppGlyph _xCircle = AppGlyph(
  light: PhosphorIconsLight.xCircle,
  regular: PhosphorIconsRegular.xCircle,
);

/// 글자 입력칸(`text-field`).
///
/// `bg.sheet` 바탕에 1px `line` 테두리, `radius.md`, 높이 52px(최소), 글자 17px입니다.
/// 포커스에는 `focus.ring`(1px `line` → 2px `action.primary`)만 입히고 바탕색은
/// 바꾸지 않습니다. [error]면 2px `text.primary` 테두리이고 오류 줄은 `input-step`이
/// 그립니다. 지우기 아이콘은 글자가 있고 포커스가 있을 때만 보입니다.
///
/// 명세 높이 52는 최소 높이라 기기 글자 크기가 크면 칸이 함께 커집니다.
class MyungliTextField extends StatefulWidget {
  /// 입력칸을 만듭니다.
  ///
  /// [label]은 스크린리더가 읽는 칸 이름, [hint]는 비었을 때 보이는 예시입니다.
  /// [controller]가 없으면 칸이 직접 만들고 지웁니다. [maxLength]를 넘는 입력은 막고
  /// 오른쪽 아래에 글자 수를 보입니다. [identifier]는 IA 슬롯 id입니다.
  const new({
    required this.label,
    this.controller,
    this.hint,
    this.maxLength,
    this.error = false,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.identifier,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('text-field', {}, {
    'focused',
    'disabled',
    'error',
  });

  /// 칸 바탕(`bg.sheet`)을 그리는 상자를 찾는 테스트용 키.
  static const Key containerKey = ValueKey('text-field-container');

  /// 지우기 버튼을 찾는 테스트용 키.
  static const Key clearKey = ValueKey('text-field-clear');

  static const double _minHeight = 52;
  static const double _fontSize = 17;
  static const double _clearTarget = 48;
  static const double _clearIconSize = 20;

  /// 칸 이름(스크린리더 라벨).
  final String label;

  /// 입력 값을 쥔 controller. 없으면 칸이 만듭니다.
  final TextEditingController? controller;

  /// 비었을 때 보이는 예시.
  final String? hint;

  /// 글자 수 상한. 없으면 제한하지 않습니다.
  final int? maxLength;

  /// 오류 상태. 테두리가 2px `text.primary`가 됩니다.
  final bool error;

  /// false면 입력할 수 없고 `disabled` 색입니다.
  final bool enabled;

  /// 글자가 바뀔 때.
  final ValueChanged<String>? onChanged;

  /// 키보드의 완료를 눌렀을 때.
  final ValueChanged<String>? onSubmitted;

  /// IA 슬롯 id. 있으면 Semantics `identifier`로 붙입니다.
  final String? identifier;

  @override
  State<MyungliTextField> createState() => _MyungliTextFieldState();
}

class _MyungliTextFieldState extends State<MyungliTextField>
    with SingleTickerProviderStateMixin {
  final FocusNode _focus = FocusNode();
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: InteractionPattern.focusRing.duration,
  );
  TextEditingController? _ownController;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ring.duration = patternDuration(
      InteractionPattern.focusRing,
      MotionPrefs.of(context),
    );
  }

  @override
  void didUpdateWidget(MyungliTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null && _ownController != null) {
      _ownController!.dispose();
      _ownController = null;
    }
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChanged)
      ..dispose();
    _ring.dispose();
    _ownController?.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focus.hasFocus) {
      _ring.forward();
    } else {
      _ring.reverse();
    }
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final enabled = widget.enabled;
    final textStyle = tokens.typography.bodyUi.copyWith(
      fontSize: MyungliTextField._fontSize,
      color: enabled ? colors.textPrimary : colors.disabledFg,
    );
    const radius = BorderRadius.all(Radius.circular(Radii.md));

    final field = ListenableBuilder(
      listenable: Listenable.merge([_focus, _controller]),
      builder: (context, _) {
        final showClear =
            enabled && _focus.hasFocus && _controller.text.isNotEmpty;
        return Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.s8),
                child: Semantics(
                  label: widget.label,
                  identifier: widget.identifier,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    enabled: enabled,
                    maxLength: widget.maxLength,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    buildCounter: (
                      context, {
                      required currentLength,
                      required isFocused,
                      required maxLength,
                    }) => null,
                    style: textStyle,
                    cursorColor: colors.actionPrimary,
                    textInputAction: TextInputAction.done,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    decoration: InputDecoration.collapsed(
                      hintText: widget.hint,
                      hintStyle: textStyle.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (showClear)
              _ClearButton(onClear: _clear)
            else
              const SizedBox(width: Space.s16),
          ],
        );
      },
    );

    final container = DecoratedBox(
      key: MyungliTextField.containerKey,
      decoration: BoxDecoration(
        // disabled는 명세 `states.disabled`: 바탕 `color.disabled.bg`,
        // 글자 `color.disabled.fg`.
        color: enabled ? colors.bgSheet : colors.disabledBg,
        borderRadius: radius,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: MyungliTextField._minHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: Space.s16),
          child: Center(heightFactor: 1, child: field),
        ),
      ),
    );

    // 글자 한 줄만 TextField의 눌림 영역이라, 칸 전체(padding·최소 높이 포함, 48 이상)를
    // 눌러도 포커스가 가도록 감쌉니다. 지우기 버튼과 TextField는 안쪽에서 먼저 받습니다.
    final tappable = enabled
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _focus.requestFocus,
            child: container,
          )
        : container;

    final Widget bordered;
    if (widget.error) {
      bordered = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(width: 2, color: colors.textPrimary),
        ),
        child: tappable,
      );
    } else if (!enabled) {
      bordered = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: colors.line),
        ),
        child: tappable,
      );
    } else {
      bordered = animate(
        InteractionPattern.focusRing,
        t: _ring,
        prefs: MotionPrefs.of(context),
        options: const PatternOptions(borderRadius: radius),
        child: tappable,
      );
    }

    final maxLength = widget.maxLength;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        bordered,
        if (maxLength != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.s4),
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                final length = _controller.text.characters.length;
                // 스크린리더에는 "2/10" 대신 "글자 수 2/10"로 읽힙니다.
                return Semantics(
                  container: true,
                  excludeSemantics: true,
                  label: AppLocalizations.of(context)
                      .textFieldCounter(length, maxLength),
                  child: Text(
                    '$length/$maxLength',
                    textAlign: TextAlign.end,
                    style: tokens.typography.captionMd.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// 지우기 아이콘(`x-circle` light 20). 눌림 영역은 48px이고 입력 초점을 빼앗지 않습니다.
class _ClearButton extends StatelessWidget {
  const new({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context).textFieldClear;
    return TextFieldTapRegion(
      child: Semantics(
        button: true,
        label: label,
        onTap: onClear,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onClear,
          child: SizedBox.square(
            key: MyungliTextField.clearKey,
            dimension: MyungliTextField._clearTarget,
            child: Center(
              child: Icon(
                _xCircle.light,
                size: MyungliTextField._clearIconSize,
                color: context.tokens.colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
