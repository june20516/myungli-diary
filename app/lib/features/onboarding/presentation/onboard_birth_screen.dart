import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/platform/device_locale.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/input/date_picker.dart';
import 'package:myungli_diary/design/components/input/input_step.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/features/onboarding/data/onboarding_draft.dart';
import 'package:myungli_diary/features/onboarding/presentation/onboarding_step_mode.dart';

/// IA `onboard-birth`의 출구 대상. 온보딩은 `onboard-time`, 수정 모드는 `profile-edit`
/// (값을 `pop`으로 돌려주므로 화면이 직접 이동하지 않습니다).
const Set<String> onboardBirthExits = {
  ScreenIds.onboardTime,
  ScreenIds.profileEdit,
};

/// IA `onboard-birth`가 직접 처리하는 상태.
const Set<String> onboardBirthHandledStates = {'out-of-range'};

/// 값이 없을 때 휠이 시작하는 생일.
const BirthDateValue _defaultBirth = BirthDateValue(
  calendar: BirthCalendar.solar,
  year: 1990,
  month: 3,
  day: 15,
);

BirthDateValue? _birthOfDraft(OnboardingDraft? draft) {
  final date = draft?.date;
  final calendar = draft?.calendar;
  if (date == null || calendar == null) return null;
  return BirthDateValue(
    calendar: calendar == CalendarType.lunar
        ? BirthCalendar.lunar
        : BirthCalendar.solar,
    year: date.year,
    month: date.month,
    day: date.day,
    isLeapMonth: draft!.isLeapMonth,
  );
}

/// 온보딩 둘째 단계: 생일(양력·음력, 윤달)을 받습니다(D18·D41).
///
/// 수정 모드(`?mode=edit`)에서는 저장 버튼이 [BirthDateValue]를 `pop`으로 돌려줍니다.
class OnboardBirthScreen extends ConsumerWidget {
  /// onboard-birth 화면을 만듭니다.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeState = GoRouterState.of(context);
    final mode = onboardingStepModeOf(routeState);
    final draft = ref.watch(onboardingDraftProvider);
    final BirthDateValue? initial;
    if (mode == OnboardingStepMode.edit) {
      initial = routeState.extra is BirthDateValue
          ? routeState.extra! as BirthDateValue
          : null;
    } else {
      initial = _birthOfDraft(draft.value);
    }
    final ready = mode == OnboardingStepMode.edit || !draft.isLoading;
    return Semantics(
      identifier: ScreenIds.onboardBirth,
      child: Scaffold(
        key: const ValueKey(ScreenIds.onboardBirth),
        body: SafeArea(
          child: Column(
            children: [
              const MyungliAppBar.inner(title: ''),
              Expanded(
                child: ready
                    ? _BirthForm(mode: mode, initial: initial ?? _defaultBirth)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BirthForm extends ConsumerStatefulWidget {
  const new({required this.mode, required this.initial});

  final OnboardingStepMode mode;
  final BirthDateValue initial;

  @override
  ConsumerState<_BirthForm> createState() => _BirthFormState();
}

class _BirthFormState extends ConsumerState<_BirthForm> {
  late BirthDateValue _value = widget.initial;
  bool _saving = false;

  Future<void> _submit() async {
    if (_saving || !_value.isWithinSupportedRange) return;
    final value = _value;
    if (widget.mode == OnboardingStepMode.edit) {
      context.pop(value);
      return;
    }
    setState(() => _saving = true);
    try {
      final lunar = value.calendar == BirthCalendar.lunar;
      await ref
          .read(onboardingDraftProvider.notifier)
          .update(
            (d) => d.copyWith(
              calendar: lunar ? CalendarType.lunar : CalendarType.solar,
              date: LunarOrSolarDate(
                year: value.year,
                month: value.month,
                day: value.day,
              ),
              isLeapMonth: lunar && value.isLeapMonth,
            ),
          );
      if (!mounted) return;
      await context.push<void>(pathOf(ScreenIds.onboardTime));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final edit = widget.mode == OnboardingStepMode.edit;
    final inRange = _value.isWithinSupportedRange;
    return InputStep(
      screenId: ScreenIds.onboardBirth,
      variant: edit ? InputStepVariant.standalone : InputStepVariant.onboarding,
      step: edit ? null : 2,
      stepCount: edit ? null : ref.watch(onboardingStepCountProvider),
      question: l10n.onboardBirthQuestionHead,
      input: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BirthDatePicker(
            value: _value,
            onChanged: (value) => setState(() => _value = value),
            calendarLabelSolar: l10n.calendarSolar,
            calendarLabelLunar: l10n.calendarLunar,
            leapMonthLabel: l10n.leapMonth,
          ),
          const SizedBox(height: Space.s12),
          Semantics(
            identifier: SlotIds.onboardBirthCalendarHint,
            child: Text(
              l10n.onboardBirthCalendarHint,
              key: const ValueKey(SlotIds.onboardBirthCalendarHint),
              style: tokens.typography.captionLg.copyWith(
                color: tokens.colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
      // 한국 출생으로 가정한다는 안내는 출생지를 묻지 않는 한국 기기에서만 보입니다(D29).
      help: ref.watch(deviceRegionIsKoreaProvider)
          ? l10n.onboardBirthBasisNote
          : null,
      helpIdentifier: SlotIds.onboardBirthBasisNote,
      error: inRange ? null : l10n.onboardBirthErrorRange,
      errorIdentifier: SlotIds.onboardBirthErrorRange,
      actionLabel: edit ? l10n.onboardingSave : l10n.onboardingNext,
      actionLoading: _saving,
      onAction: _submit,
    );
  }
}
