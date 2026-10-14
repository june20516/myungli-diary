import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/gen/model/birth_hour.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/api/gen/model/branch.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/input/date_picker.dart';
import 'package:myungli_diary/design/components/input/input_step.dart';
import 'package:myungli_diary/design/components/input/time_picker.dart';
import 'package:myungli_diary/features/onboarding/application/birth_hour_providers.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/features/onboarding/presentation/onboard_birth_screen.dart';
import 'package:myungli_diary/features/onboarding/presentation/onboarding_step_mode.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';

/// IA `onboard-time`의 출구 대상. 온보딩은 `onboard-gender`, 수정 모드는 `profile-edit`
/// (값을 `pop`으로 돌려주므로 화면이 직접 이동하지 않습니다).
const Set<String> onboardTimeExits = {
  ScreenIds.onboardGender,
  ScreenIds.profileEdit,
};

/// IA `onboard-time`이 직접 처리하는 상태.
const Set<String> onboardTimeHandledStates = {'time-unknown'};

/// 값이 없을 때 휠이 시작하는 시각.
const TimeOfDay _defaultTime = TimeOfDay(hour: 12, minute: 0);

/// 휠이 멈춘 것으로 보고 시진을 물어보기까지 기다리는 시간. 휠을 돌리는 동안에는 요청하지 않습니다.
const Duration _confirmDebounce = Duration(milliseconds: 500);

/// 저장된 출생 시각을 휠 값으로 바꿉니다. 모름이거나 값이 없으면 null입니다.
TimeOfDay? timeOfBirthTime(BirthTime? time) {
  final value = time?.value;
  if (time?.status != BirthTimeStatusEnum.known || value == null) return null;
  final parts = value.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

/// 휠 값 [time]을 계약 모델로 바꿉니다. [unknown]이면 시각을 담지 않습니다.
BirthTime birthTimeOf(TimeOfDay time, {required bool unknown}) => unknown
    ? BirthTime(status: BirthTimeStatusEnum.unknown)
    : BirthTime(status: BirthTimeStatusEnum.known, value: _hhmm(time));

String _hhmm(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

String _branchName(AppLocalizations l10n, Branch branch) => switch (branch) {
  Branch.ja => l10n.branchJa,
  Branch.chuk => l10n.branchChuk,
  Branch.in_ => l10n.branchIn,
  Branch.myo => l10n.branchMyo,
  Branch.jin => l10n.branchJin,
  Branch.sa => l10n.branchSa,
  Branch.o => l10n.branchO,
  Branch.mi => l10n.branchMi,
  Branch.shin => l10n.branchShin,
  Branch.yu => l10n.branchYu,
  Branch.sul => l10n.branchSul,
  Branch.hae => l10n.branchHae,
};

/// 시진 확인 줄 글자(`onboard-time.hour.confirm`). server는 지지와 시각 범위만 주므로
/// app이 ARB 틀에 넣어 씁니다(A20 ③, IA v2에서 ui 슬롯이 됨 D68).
String sijinConfirmText(AppLocalizations l10n, BirthHour hour) =>
    l10n.onboardTimeHourConfirm(
      _branchName(l10n, hour.branch),
      hour.start,
      hour.end,
    );

/// 온보딩 셋째 단계: 태어난 시간(모름 포함)을 받습니다(D18).
///
/// 기기 지역이 한국이면 휠이 멈춘 뒤 시진 확인 줄이 붙습니다(D58). 수정 모드(`?mode=edit`)에서는
/// 저장 버튼이 [BirthTime]을 `pop`으로 돌려줍니다.
class OnboardTimeScreen extends ConsumerWidget {
  /// onboard-time 화면을 만듭니다.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeState = GoRouterState.of(context);
    final mode = onboardingStepModeOf(routeState);
    final edit = mode == OnboardingStepMode.edit;
    // 수정 모드는 extra, 없으면 프로필 사본에서 시작하고 초안은 보지 않습니다(A19).
    final profile = edit ? ref.watch(cachedProfileProvider) : null;
    final draft = edit ? null : ref.watch(onboardingDraftProvider);
    final BirthTime? initial;
    final BirthDateValue? date;
    if (edit) {
      initial = routeState.extra is BirthTime
          ? routeState.extra! as BirthTime
          : profile?.value?.birth.time;
      date = birthDateValueOfProfile(profile?.value);
    } else {
      initial = draft?.value?.time;
      date = birthDateValueOfDraft(draft?.value);
    }
    final ready = !(profile?.isLoading ?? draft?.isLoading ?? false);
    return Semantics(
      identifier: ScreenIds.onboardTime,
      child: Scaffold(
        key: const ValueKey(ScreenIds.onboardTime),
        body: SafeArea(
          child: Column(
            children: [
              MyungliAppBar.inner(
                // 스택 바닥(갈래의 첫 화면, 딥링크·복원)이면 돌아갈 곳이 없어 숨깁니다.
                title: '',
                showBack: MyungliAppBar.canGoBack(context),
              ),
              Expanded(
                child: ready
                    ? _TimeForm(mode: mode, initial: initial, date: date)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeForm extends ConsumerStatefulWidget {
  const new({required this.mode, required this.initial, required this.date});

  final OnboardingStepMode mode;
  final BirthTime? initial;

  /// 시진 확인에 보낼 생일. 아직 모르면 null이라 확인 줄이 없습니다.
  final BirthDateValue? date;

  @override
  ConsumerState<_TimeForm> createState() => _TimeFormState();
}

class _TimeFormState extends ConsumerState<_TimeForm> {
  late TimeOfDay _value = timeOfBirthTime(widget.initial) ?? _defaultTime;
  late bool _unknown = widget.initial?.status == BirthTimeStatusEnum.unknown;

  /// 휠이 멈춘 것으로 본 시각. 열릴 때의 시각(기본 12:00 또는 저장된 값)도 바로 묻습니다.
  late TimeOfDay _settled = _value;

  /// 휠을 움직이기 직전에 보이던 시진. 휠이 움직이거나 새 값을 기다리는 동안 그대로 보여
  /// 줄이 흔들리지 않게 합니다.
  BirthHour? _held;
  Timer? _debounce;
  bool _saving = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// 지금 보이는(받아 둔) 시진을 [_held]에 담습니다. 아직 받는 중이면 앞서 담은 값을 둡니다.
  void _holdShown() {
    final date = widget.date;
    if (_unknown || date == null || _settled != _value) return;
    final result = ref.read(
      birthHourProvider((date: date, time: _hhmm(_settled))),
    );
    if (!result.isLoading) _held = result.value;
  }

  void _onTimeChanged(TimeOfDay value) {
    _holdShown();
    setState(() => _value = value);
    _debounce?.cancel();
    _debounce = Timer(_confirmDebounce, () {
      if (mounted) setState(() => _settled = _value);
    });
  }

  Future<void> _submit() async {
    if (_saving) return;
    final time = birthTimeOf(_value, unknown: _unknown);
    if (widget.mode == OnboardingStepMode.edit) {
      context.pop(time);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(onboardingDraftProvider.notifier)
          .update((d) => d.copyWith(time: time));
      if (!mounted) return;
      await context.push<void>(pathOf(ScreenIds.onboardGender));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 시진 확인 줄 글자. 모름이거나 생일을 모르거나 값을 못 받았으면 null입니다.
  /// 휠이 움직이는 중이거나 새 값을 기다리는 동안에는 [_held]의 이전 줄을 그대로 둡니다.
  String? _confirmText(AppLocalizations l10n) {
    final date = widget.date;
    if (_unknown || date == null) return null;
    var hour = _held;
    if (_settled == _value) {
      final result = ref.watch(
        birthHourProvider((date: date, time: _hhmm(_settled))),
      );
      if (!result.isLoading) hour = result.value;
    }
    return hour == null ? null : sijinConfirmText(l10n, hour);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final edit = widget.mode == OnboardingStepMode.edit;
    return InputStep(
      screenId: ScreenIds.onboardTime,
      variant: edit ? InputStepVariant.standalone : InputStepVariant.onboarding,
      step: edit ? null : 3,
      stepCount: edit ? null : ref.watch(onboardingStepCountProvider),
      question: l10n.onboardTimeQuestionHead,
      input: TimePicker(
        variant: TimePickerVariant.birth,
        value: _value,
        onChanged: _onTimeChanged,
        unknown: _unknown,
        onUnknownChanged: (value) => setState(() => _unknown = value),
        unknownLabel: l10n.timeUnknownLabel,
        unknownNotice: l10n.onboardTimeUnknownNote,
        sijinConfirm: _confirmText(l10n),
        unknownNoticeIdentifier: SlotIds.onboardTimeUnknownNote,
        sijinConfirmIdentifier: SlotIds.onboardTimeHourConfirm,
      ),
      actionLabel: edit ? l10n.onboardingSave : l10n.onboardingNext,
      actionLoading: _saving,
      onAction: _submit,
    );
  }
}
