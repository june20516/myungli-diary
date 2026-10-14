import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/field_problems.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/platform/device_locale.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/input/input_step.dart';
import 'package:myungli_diary/design/components/input/text_field.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_completer.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/features/onboarding/presentation/onboarding_step_mode.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';

/// IA `onboard-call`의 출구 대상. 온보딩은 `onboard-birth`, 수정 모드는 `profile-edit`
/// (값을 `pop`으로 돌려주므로 화면이 직접 이동하지 않습니다).
const Set<String> onboardCallExits = {
  ScreenIds.onboardBirth,
  ScreenIds.profileEdit,
};

/// 온보딩 첫 단계: 앱이 사용자를 부를 말(호칭)을 받습니다(D36).
///
/// 수정 모드(`?mode=edit`)에서는 저장 버튼이 호칭 [String]을 `pop`으로 돌려줍니다.
///
/// 온보딩 모드로 열릴 때 한 번 확인합니다(Review Focus 1·2).
/// * 약관 동의 직후 프로필 저장이 입력 오류였으면 그 안내를 toast로 보이고 입력을 보여 줍니다.
/// * 아니면, 진입이 `profileRequired`이고 입력이 완전하면(미리보기·동의 뒤 프로필 저장 전에
///   앱이 꺼짐) 같은 질문을 다시 묻지 않고 프로필을 저장합니다. 이동은 진입 갱신이 정합니다.
class OnboardCallScreen extends ConsumerStatefulWidget {
  /// onboard-call 화면을 만듭니다.
  const new({super.key});

  @override
  ConsumerState<OnboardCallScreen> createState() => _OnboardCallScreenState();
}

class _OnboardCallScreenState extends ConsumerState<OnboardCallScreen> {
  bool _entryChecked = false;

  /// 입력으로 프로필을 저장하는 중이면 true. 그동안 질문을 그리지 않습니다.
  bool _resuming = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entryChecked) return;
    _entryChecked = true;
    if (onboardingStepModeOf(GoRouterState.of(context)) ==
        OnboardingStepMode.onboarding) {
      _checkOnEntry();
    }
  }

  void _checkOnEntry() {
    // 첫 build 전에는 provider를 바꿀 수 없어, 무엇을 할지만 정하고 첫 프레임 뒤에 합니다.
    final hasRejection = ref.read(onboardingRejectionNoticeProvider) != null;
    _resuming =
        !hasRejection && ref.read(entryProvider) == EntryState.profileRequired;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (hasRejection) {
        final rejection = ref
            .read(onboardingRejectionNoticeProvider.notifier)
            .take();
        if (rejection != null) _showError(rejection);
      } else if (_resuming) {
        unawaited(_resume());
      }
    });
  }

  Future<void> _resume() async {
    final completer = ref.read(onboardingCompleterProvider);
    try {
      if (await completer.isReady()) {
        await completer.complete();
      }
    } on Object catch (error) {
      // 실패하면 질문을 보여 이어서 고치거나 다시 저장할 수 있게 합니다.
      _showError(onboardingErrorOf(error));
    } finally {
      if (mounted) setState(() => _resuming = false);
    }
  }

  void _showError(AppError error) {
    if (!mounted) return;
    showMyungliToast(
      context,
      errorMessage(AppLocalizations.of(context), error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final routeState = GoRouterState.of(context);
    final mode = onboardingStepModeOf(routeState);
    final edit = mode == OnboardingStepMode.edit;
    // 수정 모드는 extra, 없으면 프로필 사본에서 시작하고 초안은 보지 않습니다(A19).
    final profile = edit ? ref.watch(cachedProfileProvider) : null;
    final draft = edit ? null : ref.watch(onboardingDraftProvider);
    final String? initial;
    if (edit) {
      initial = routeState.extra is String
          ? routeState.extra! as String
          : profile?.value?.honorific;
    } else {
      initial = draft?.value?.honorific;
    }
    final ready =
        !_resuming && !(profile?.isLoading ?? draft?.isLoading ?? false);
    return Semantics(
      identifier: ScreenIds.onboardCall,
      child: Scaffold(
        key: const ValueKey(ScreenIds.onboardCall),
        body: SafeArea(
          child: Column(
            children: [
              const MyungliAppBar.inner(title: ''),
              Expanded(
                child: ready
                    ? _CallForm(mode: mode, initial: initial ?? '')
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallForm extends ConsumerStatefulWidget {
  const new({required this.mode, required this.initial});

  final OnboardingStepMode mode;
  final String initial;

  @override
  ConsumerState<_CallForm> createState() => _CallFormState();
}

class _CallFormState extends ConsumerState<_CallForm> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  )..addListener(_onTextChanged);
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  String get _honorific => _controller.text.trim();

  Future<void> _submit() async {
    if (_saving || _honorific.isEmpty) return;
    final honorific = _honorific;
    if (widget.mode == OnboardingStepMode.edit) {
      context.pop(honorific);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(onboardingDraftProvider.notifier)
          .update((d) => d.copyWith(honorific: honorific));
      if (!mounted) return;
      await context.push<void>(pathOf(ScreenIds.onboardBirth));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final edit = widget.mode == OnboardingStepMode.edit;
    return InputStep(
      screenId: ScreenIds.onboardCall,
      variant: edit ? InputStepVariant.standalone : InputStepVariant.onboarding,
      step: edit ? null : 1,
      stepCount: edit ? null : ref.watch(onboardingStepCountProvider),
      question: l10n.onboardCallQuestionHead,
      input: MyungliTextField(
        // 질문은 InputStep의 form 노드가 읽으므로 칸 이름은 목적만 말하고, 예시는 hint로만 둡니다.
        label: l10n.onboardCallInputLabel,
        controller: _controller,
        hint: l10n.onboardCallInputHint,
        maxLength: honorificMaxLength(ref.watch(appLanguageProvider)),
        identifier: SlotIds.onboardCallInputHint,
        onSubmitted: (_) => _submit(),
      ),
      help: l10n.onboardCallNoteBody,
      helpIdentifier: SlotIds.onboardCallNoteBody,
      actionLabel: edit ? l10n.onboardingSave : l10n.onboardingNext,
      actionLoading: _saving,
      onAction: _honorific.isEmpty ? null : _submit,
    );
  }
}
