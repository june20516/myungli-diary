import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/seep_presence.dart';
import 'package:myungli_diary/design/components/input/check_row.dart';
import 'package:myungli_diary/design/components/input/wheel.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// `time-picker` 변형.
enum TimePickerVariant {
  /// 출생 시간. 분은 1분 단위이고 '모름'과 시진 확인 줄이 있습니다.
  birth,

  /// 알림 시간·일정 시간. 분은 5분 단위이고 '모름'이 없습니다.
  notify,
}

/// 시간 입력 휠(`time-picker`). 오전·오후, 시(12시간), 분 휠 세 줄입니다.
///
/// [value]는 24시간 값입니다. 출생 시간은 벽시계 시각을 그대로 받습니다(보정 없음).
/// `notify`의 분 휠은 5분 단위(0, 5, … 55)이고 [value]의 분은 5의 배수여야 합니다(assert).
///
/// `birth`에서 [unknownLabel]과 [onUnknownChanged]가 있으면 '모름' 체크
/// ([CheckRow] inline)가 휠 아래 붙습니다. [unknown]이 켜지면 휠은
/// opacity 0.35·blur 1.5px로 흐려지고 끌 수 없으며,
/// [unknownNotice]가 `appear.seep`으로 나타나고 시진 확인 줄은 숨습니다.
/// [sijinConfirm]은 시진 확인 줄 글자입니다. null(한국 밖이거나 값을 못 받음)이면 그 자리를
/// 비워 두지 않습니다.
class TimePicker extends StatefulWidget {
  /// 시간 휠을 만듭니다.
  // assert가 [value]를 읽으므로 const 생성자가 아닙니다.
  new({
    required this.variant,
    required this.value,
    required this.onChanged,
    this.unknown = false,
    this.onUnknownChanged,
    this.unknownLabel,
    this.unknownNotice,
    this.sijinConfirm,
    this.identifier,
    this.unknownNoticeIdentifier,
    this.sijinConfirmIdentifier,
    super.key,
  }) : assert(
         variant == TimePickerVariant.birth || value.minute % 5 == 0,
         // 분 칸이 5분 단위라 5의 배수가 아닌 값은 표시와 값이 어긋납니다.
         // 알림 시각은 계약상 5분 단위입니다(`server/api/openapi.yaml`
         // `NotificationSetting.time` 패턴). 일정 등 다른 사용처도 5분 단위로
         // 맞춘 값을 넘겨야 합니다.
         'notify의 분은 5의 배수여야 합니다.',
       );

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'time-picker',
    {'birth', 'notify'},
    {'unknown', 'outsideKorea'},
  );

  /// 휠 묶음을 찾는 테스트용 키.
  static const Key wheelsKey = ValueKey('time-picker-wheels');

  /// 휠을 흐리게 만드는 투명도 층을 찾는 테스트용 키.
  static const Key wheelsDimKey = ValueKey('time-picker-wheels-dim');

  /// 오전·오후 휠을 찾는 테스트용 키.
  static const Key meridiemWheelKey = ValueKey('time-picker-meridiem');

  /// 시 휠을 찾는 테스트용 키.
  static const Key hourWheelKey = ValueKey('time-picker-hour');

  /// 분 휠을 찾는 테스트용 키.
  static const Key minuteWheelKey = ValueKey('time-picker-minute');

  /// 시진 확인 줄을 찾는 테스트용 키.
  static const Key sijinConfirmKey = ValueKey('time-picker-sijin-confirm');

  /// 모름 안내를 찾는 테스트용 키.
  static const Key unknownNoticeKey = ValueKey('time-picker-unknown-notice');

  /// `unknown` 휠 투명도(`states.unknown.parts.wheels.opacity`).
  static const double unknownOpacity = 0.35;

  /// `unknown` 휠 흐림(px, `states.unknown.parts.wheels.blur`).
  static const double unknownBlur = 1.5;

  /// 변형.
  final TimePickerVariant variant;

  /// 지금 시각(24시간 값).
  final TimeOfDay value;

  /// 휠을 돌려 시각이 바뀔 때.
  final ValueChanged<TimeOfDay> onChanged;

  /// '모름'이 켜졌는지. `notify`에서는 무시합니다.
  final bool unknown;

  /// '모름'을 켜고 끌 때.
  final ValueChanged<bool>? onUnknownChanged;

  /// '모름' 체크 글자.
  final String? unknownLabel;

  /// '모름'일 때 보일 안내.
  final String? unknownNotice;

  /// 시진 확인 줄 글자. null이면 그리지 않고 자리도 두지 않습니다.
  final String? sijinConfirm;

  /// IA 슬롯 id. '모름' 체크 줄의 Semantics `identifier`에 붙습니다.
  final String? identifier;

  /// IA 슬롯 id. 있으면 모름 안내 글자의 Key와 Semantics `identifier`가 됩니다.
  final String? unknownNoticeIdentifier;

  /// IA 슬롯 id. 있으면 시진 확인 줄 글자의 Key와 Semantics `identifier`가 됩니다.
  final String? sijinConfirmIdentifier;

  @override
  State<TimePicker> createState() => _TimePickerState();
}

class _TimePickerState extends State<TimePicker> {
  /// 시진 확인 줄이 사라지는 동안에도 마지막 글자를 보여 주려고 기억합니다.
  String? _lastSijin;

  bool get _birth => widget.variant == TimePickerVariant.birth;
  bool get _unknown => _birth && widget.unknown;
  int get _minuteStep => _birth ? 1 : 5;
  int get _minuteCount => 60 ~/ _minuteStep;

  int get _meridiemIndex => widget.value.hour >= 12 ? 1 : 0;
  // 12시간제 칸 순서는 12, 1, 2, … 11 입니다.
  int get _hourIndex => widget.value.hour % 12;
  int get _minuteIndex =>
      (widget.value.minute / _minuteStep).round().clamp(0, _minuteCount - 1);

  void _emit({int? meridiem, int? hour, int? minute}) {
    final hour24 = (meridiem ?? _meridiemIndex) * 12 + (hour ?? _hourIndex);
    final minuteValue = minute == null
        ? widget.value.minute
        : minute * _minuteStep;
    widget.onChanged(TimeOfDay(hour: hour24, minute: minuteValue));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.tokens.colors;
    final textStyle = context.tokens.typography.captionLg.copyWith(
      color: colors.textSecondary,
    );

    final confirm = widget.sijinConfirm;
    if (confirm != null) _lastSijin = confirm;
    final showConfirm = _birth && !_unknown && confirm != null;
    final showNotice = _unknown && widget.unknownNotice != null;

    Widget wheels = SizedBox(
      key: TimePicker.wheelsKey,
      child: WheelGroup(
        wheels: [
          Wheel(
            key: TimePicker.meridiemWheelKey,
            itemCount: 2,
            selectedIndex: _meridiemIndex,
            itemLabel: (i) => i == 0 ? l10n.timePickerAm : l10n.timePickerPm,
            onSelectedIndexChanged: (i) => _emit(meridiem: i),
            semanticLabel: l10n.timePickerMeridiemLabel,
            enabled: !_unknown,
          ),
          Wheel(
            key: TimePicker.hourWheelKey,
            itemCount: 12,
            selectedIndex: _hourIndex,
            itemLabel: (i) => l10n.timePickerHourItem(i == 0 ? 12 : i),
            onSelectedIndexChanged: (i) => _emit(hour: i),
            semanticLabel: l10n.timePickerHourLabel,
            enabled: !_unknown,
          ),
          Wheel(
            key: TimePicker.minuteWheelKey,
            itemCount: _minuteCount,
            selectedIndex: _minuteIndex,
            itemLabel: (i) => l10n.timePickerMinuteItem(
              (i * _minuteStep).toString().padLeft(2, '0'),
            ),
            onSelectedIndexChanged: (i) => _emit(minute: i),
            semanticLabel: l10n.timePickerMinuteLabel,
            enabled: !_unknown,
          ),
        ],
      ),
    );
    // '모름'이면 휠이 흐려집니다(opacity 0.35, blur 1.5px). 흐림은 휠 자신에게만 겁니다.
    if (_unknown) {
      wheels = ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: TimePicker.unknownBlur,
          sigmaY: TimePicker.unknownBlur,
        ),
        child: Opacity(
          key: TimePicker.wheelsDimKey,
          opacity: TimePicker.unknownOpacity,
          child: wheels,
        ),
      );
    }

    final unknownLabel = widget.unknownLabel;
    final onUnknownChanged = widget.onUnknownChanged;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        wheels,
        if (_birth && unknownLabel != null && onUnknownChanged != null)
          CheckRow(
            variant: CheckRowVariant.inline,
            label: unknownLabel,
            checked: widget.unknown,
            onChanged: onUnknownChanged,
            identifier: widget.identifier,
          ),
        // 안내와 시진 확인 줄은 서로 다른 때에만 보이고, 없을 때는 자리를 차지하지 않습니다.
        SeepPresence(
          present: showNotice,
          child: Padding(
            padding: const EdgeInsets.only(top: Space.s8),
            child: Semantics(
              identifier: widget.unknownNoticeIdentifier,
              child: Text(
                key: widget.unknownNoticeIdentifier == null
                    ? TimePicker.unknownNoticeKey
                    : ValueKey<String>(widget.unknownNoticeIdentifier!),
                widget.unknownNotice ?? '',
                style: textStyle,
              ),
            ),
          ),
        ),
        // 값이 바뀌면(휠이 멈추면) 새 글자로 다시 나타납니다.
        SeepPresence(
          key: ValueKey(showConfirm ? confirm : _lastSijin),
          present: showConfirm,
          child: Padding(
            padding: const EdgeInsets.only(top: Space.s8),
            child: Semantics(
              identifier: widget.sijinConfirmIdentifier,
              child: Text(
                key: widget.sijinConfirmIdentifier == null
                    ? TimePicker.sijinConfirmKey
                    : ValueKey<String>(widget.sijinConfirmIdentifier!),
                _lastSijin ?? '',
                style: textStyle,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
