import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/live_announcement.dart';
import 'package:myungli_diary/design/components/input/field_error_line.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/interaction/motion_prefs.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/text/line_height.dart';
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
  /// [maxLines]가 1보다 크면 여러 줄 칸입니다(최소 높이 52를 지키며 그 줄 수까지 늘어남).
  const new({
    required this.label,
    this.controller,
    this.hint,
    this.maxLength,
    this.error = false,
    this.enabled = true,
    this.leadingIcon,
    this.onChanged,
    this.onSubmitted,
    this.identifier,
    this.maxLines = 1,
    this.minLines = 1,
    this.email = false,
    this.showLabel = false,
    this.errorText,
    this.errorIdentifier,
    this.focusNode,
    super.key,
  }) : assert(
         maxLines >= 1 && maxLines <= maxLinesLimit,
         'maxLines는 1~$maxLinesLimit이어야 합니다.',
       ),
       assert(
         minLines >= 1 && minLines <= maxLines,
         'minLines는 1~maxLines이어야 합니다.',
       ),
       assert(!(email && maxLines > 1), 'email은 한 줄 칸입니다.');

  /// 명세 대조용 요약. 변형 `multiline`은 [maxLines]가 1보다 큰 칸입니다.
  static const ComponentSpec spec = ComponentSpec(
    'text-field',
    {'multiline', 'email'},
    {'focused', 'disabled', 'error'},
  );

  /// 칸 바탕(`bg.sheet`)을 그리는 상자를 찾는 테스트용 키.
  static const Key containerKey = ValueKey('text-field-container');

  /// 지우기 버튼을 찾는 테스트용 키.
  static const Key clearKey = ValueKey('text-field-clear');

  /// 칸 오류 줄을 찾는 테스트용 키.
  static const Key errorLineKey = ValueKey('text-field-error-line');

  /// 여러 줄 칸이 늘어나는 줄 수 상한.
  static const int maxLinesLimit = 6;

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

  /// 칸 앞에 놓는 꾸밈 아이콘(`city-search`의 `magnifying-glass`). 스크린리더는 읽지 않습니다.
  final AppGlyph? leadingIcon;

  /// 글자가 바뀔 때.
  final ValueChanged<String>? onChanged;

  /// 키보드의 완료를 눌렀을 때.
  final ValueChanged<String>? onSubmitted;

  /// IA 슬롯 id. 있으면 Semantics `identifier`로 붙입니다.
  final String? identifier;

  /// 늘어날 수 있는 줄 수(1~[maxLinesLimit]). 1이면 한 줄 칸이고 키보드 동작은 완료입니다.
  ///
  /// 1보다 크면 `multiline` 변형입니다. 한 줄 높이에서 시작해 글이 길어지면 이 줄 수까지
  /// 늘어나고, 그 뒤는 칸 안에서 스크롤합니다. 첫 줄과 지우기 아이콘은 한 줄 칸과 같은
  /// 높이입니다. 키보드는 여러 줄 입력이고 키보드 동작은 줄바꿈이라 [onSubmitted]는 불리지
  /// 않습니다(event-edit 메모 2000자).
  final int maxLines;

  /// 처음 높이의 줄 수(1~[maxLines]). `contact` 문의 내용처럼 긴 글을 받는 칸은 4줄로 엽니다
  /// (3.4.0). 1보다 크면 칸 안 안내도 두 줄까지 감습니다.
  final int minLines;

  /// `email` 변형(3.4.0): 메일 주소 키보드, 키보드 동작 완료, 자동 고침과 첫 글자 대문자 끔,
  /// 자동 채우기 메일.
  final bool email;

  /// 칸 위에 이름([label])을 늘 보입니다(`label` 부품, 3.4.0). `input-step` 밖에서 칸이 둘
  /// 이상인 화면이 씁니다. `type.label.md` `text.primary`, 칸과 사이 `space.8`, 한 줄입니다.
  final bool showLabel;

  /// 칸 오류 줄(`errorLine` 부품, 3.4.0). 있으면 칸은 [error] 상태이고 칸 아래 `space.8`에
  /// `input-step` 오류 줄과 같은 모양으로 그리며, 나타날 때 스크린리더가 polite로 읽습니다.
  /// `input-step` 안에서는 쓰지 않습니다(그 오류 줄을 씀).
  final String? errorText;

  /// 오류 줄의 IA 슬롯 id.
  final String? errorIdentifier;

  /// 바깥에서 초점을 옮길 때 쓰는 노드(예 오류 칸으로 초점 옮기기). 없으면 칸이 만듭니다.
  final FocusNode? focusNode;

  /// 오류 상태인지([error] 또는 [errorText]).
  bool get _hasError => error || errorText != null;

  bool get _multiline => maxLines > 1;

  @override
  State<MyungliTextField> createState() => _MyungliTextFieldState();
}

class _MyungliTextFieldState extends State<MyungliTextField>
    with SingleTickerProviderStateMixin {
  FocusNode? _ownFocus;

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());
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
    final oldFocus = oldWidget.focusNode ?? _ownFocus;
    if (widget.focusNode != oldWidget.focusNode) {
      oldFocus?.removeListener(_onFocusChanged);
      if (widget.focusNode != null) {
        _ownFocus?.dispose();
        _ownFocus = null;
      }
      _focus.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _ownFocus?.dispose();
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

    // 한 줄 칸의 글줄은 최소 높이(52) 가운데이고, 글자가 커지면 위아래 `space.8`로 칸이
    // 늘어납니다. 여러 줄 칸도 첫 줄과 지우기를 그 높이에 두고 아래로 늘어납니다
    // (`clear.align: first-line`).
    final multiline = widget._multiline;
    final lineHeight = lineHeightOf(
      textStyle,
      MediaQuery.textScalerOf(context),
    );
    final firstLineCenter = math.max(
      MyungliTextField._minHeight / 2,
      Space.s8 + lineHeight / 2,
    );
    final textPadding = EdgeInsets.symmetric(
      vertical: multiline ? firstLineCenter - lineHeight / 2 : Space.s8,
    );

    final field = ListenableBuilder(
      listenable: Listenable.merge([_focus, _controller]),
      builder: (context, _) {
        final showClear =
            enabled && _focus.hasFocus && _controller.text.isNotEmpty;
        final leading = widget.leadingIcon;
        return Row(
          crossAxisAlignment: multiline
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            if (leading != null)
              Padding(
                padding: EdgeInsetsDirectional.only(
                  // 여러 줄 칸에서도 아이콘은 첫 줄 가운데입니다.
                  top: multiline
                      ? firstLineCenter - AppIconSize.inline.logical / 2
                      : 0,
                  end: Space.s12,
                ),
                child: ExcludeSemantics(
                  child: AppIcon(
                    leading,
                    size: AppIconSize.inline,
                    color: enabled ? colors.textSecondary : colors.disabledFg,
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: textPadding,
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
                    minLines: widget.minLines,
                    maxLines: widget.maxLines,
                    keyboardType: widget.email
                        ? TextInputType.emailAddress
                        : (multiline ? TextInputType.multiline : null),
                    autocorrect: !widget.email,
                    enableSuggestions: !widget.email,
                    autofillHints: widget.email
                        ? const [AutofillHints.email]
                        : null,
                    textInputAction: multiline
                        ? TextInputAction.newline
                        : TextInputAction.done,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    decoration: InputDecoration.collapsed(
                      hintText: widget.hint,
                      hintMaxLines: multiline ? 2 : 1,
                      hintStyle: textStyle.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (showClear)
              Padding(
                padding: EdgeInsets.only(
                  top: multiline
                      ? firstLineCenter - MyungliTextField._clearTarget / 2
                      : 0,
                ),
                child: _ClearButton(onClear: _clear),
              )
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
    if (widget._hasError) {
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
    final errorText = widget.errorText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showLabel)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s8),
            // 스크린리더는 칸 라벨로 읽으므로 이 글자는 따로 읽지 않습니다.
            child: ExcludeSemantics(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.typography.labelMd.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
        bordered,
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.s8),
            child: LiveAnnouncement(
              label: errorText,
              role: SemanticsRole.status,
              identifier: widget.errorIdentifier,
              child: FieldErrorLine(
                key: MyungliTextField.errorLineKey,
                text: errorText,
              ),
            ),
          ),
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
