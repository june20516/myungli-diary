import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/platform/device_locale.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/input/input_step.dart';
import 'package:myungli_diary/design/components/input/segmented.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_completer.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_finish.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/features/onboarding/presentation/onboarding_navigation.dart';
import 'package:myungli_diary/features/onboarding/presentation/onboarding_step_mode.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';

/// IA `onboard-gender`의 출구 대상. 온보딩은 `preview`(한국 기기)·`birthplace`(한국 밖),
/// 로그인한 새 계정은 프로필을 저장하고 `notify-ask`(D68), 수정 모드는 `profile-edit`
/// (값을 `pop`으로 돌려주므로 화면이 직접 이동하지 않습니다).
const Set<String> onboardGenderExits = {
  ScreenIds.preview,
  ScreenIds.birthplace,
  ScreenIds.notifyAsk,
  ScreenIds.profileEdit,
};

/// 온보딩 넷째 단계: 대운 방향 계산에 쓸 성별을 받습니다(D18).
///
/// 한국 기기는 `preview`, 한국 밖은 `birthplace`로 이어지고, 로그인했고 프로필이 없는 계정
/// ([finishesWithoutPreviewProvider])은 미리보기를 건너뛰어 마무리 동작
/// ([onboardingFinishProvider])을 부릅니다. 저장이 입력 오류(422)면 `onboard-call`로 돌아가
/// 고치게 합니다. 수정 모드(`?mode=edit`)에서는
/// 저장 버튼이 [BirthGenderEnum]을 `pop`으로 돌려줍니다.
class OnboardGenderScreen extends ConsumerWidget {
  /// onboard-gender 화면을 만듭니다.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeState = GoRouterState.of(context);
    final mode = onboardingStepModeOf(routeState);
    final edit = mode == OnboardingStepMode.edit;
    // 수정 모드는 extra, 없으면 프로필 사본에서 시작하고 초안은 보지 않습니다(A19).
    final profile = edit ? ref.watch(cachedProfileProvider) : null;
    final draft = edit ? null : ref.watch(onboardingDraftProvider);
    final BirthGenderEnum? initial;
    if (edit) {
      initial = routeState.extra is BirthGenderEnum
          ? routeState.extra! as BirthGenderEnum
          : profile?.value?.birth.gender;
    } else {
      initial = draft?.value?.gender;
    }
    final ready = !(profile?.isLoading ?? draft?.isLoading ?? false);
    return Semantics(
      identifier: ScreenIds.onboardGender,
      child: Scaffold(
        key: const ValueKey(ScreenIds.onboardGender),
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
                    ? _GenderForm(mode: mode, initial: initial)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenderForm extends ConsumerStatefulWidget {
  const new({required this.mode, required this.initial});

  final OnboardingStepMode mode;
  final BirthGenderEnum? initial;

  @override
  ConsumerState<_GenderForm> createState() => _GenderFormState();
}

class _GenderFormState extends ConsumerState<_GenderForm> {
  late BirthGenderEnum? _selected = widget.initial;
  bool _saving = false;

  Future<void> _submit() async {
    final gender = _selected;
    if (_saving || gender == null) return;
    if (widget.mode == OnboardingStepMode.edit) {
      context.pop(gender);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(onboardingDraftProvider.notifier)
          .update((d) => d.copyWith(gender: gender));
      if (!mounted) return;
      await _next();
    } on OnboardingInputRejected catch (rejected) {
      // 입력 오류는 첫 단계(onboard-call)부터 고칩니다(약관 동의 직후 저장과 같은 동작).
      if (!mounted) return;
      returnToOnboardCallWith(context, ref, rejected.error);
    } on Object catch (error) {
      // 마무리 동작(프로필 저장·진입 갱신)이 실패해도 미처리 비동기 오류로 남기지 않고
      // 안내합니다. 입력은 남아 있어 다시 누를 수 있습니다.
      if (!mounted) return;
      showMyungliToast(
        context,
        errorMessage(AppLocalizations.of(context), onboardingErrorOf(error)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 한국 밖은 출생지, 프로필이 없는 계정이면 저장으로 마무리, 아니면 미리보기로 갑니다.
  Future<void> _next() {
    if (!ref.read(deviceRegionIsKoreaProvider)) {
      return context.push<void>(pathOf(ScreenIds.birthplace));
    }
    if (ref.read(finishesWithoutPreviewProvider)) {
      return ref.read(onboardingFinishProvider)();
    }
    return context.push<void>(pathOf(ScreenIds.preview));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final edit = widget.mode == OnboardingStepMode.edit;
    return InputStep(
      screenId: ScreenIds.onboardGender,
      variant: edit ? InputStepVariant.standalone : InputStepVariant.onboarding,
      step: edit ? null : 4,
      stepCount: edit ? null : ref.watch(onboardingStepCountProvider),
      question: l10n.onboardGenderQuestionHead,
      input: Segmented<BirthGenderEnum?>(
        items: [
          SegmentedItem(BirthGenderEnum.female, l10n.genderFemale),
          SegmentedItem(BirthGenderEnum.male, l10n.genderMale),
        ],
        selected: _selected,
        onChanged: _saving
            ? null
            : (value) => setState(() => _selected = value),
        label: l10n.onboardGenderQuestionHead,
      ),
      help: l10n.onboardGenderWhyBody,
      helpIdentifier: SlotIds.onboardGenderWhyBody,
      actionLabel: edit ? l10n.onboardingSave : l10n.onboardingNext,
      actionLoading: _saving,
      onAction: _selected == null ? null : _submit,
    );
  }
}
