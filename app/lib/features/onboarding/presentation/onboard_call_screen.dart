import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/field_problems.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/platform/device_locale.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/input/input_step.dart';
import 'package:myungli_diary/design/components/input/text_field.dart';
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
class OnboardCallScreen extends ConsumerWidget {
  /// onboard-call 화면을 만듭니다.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final ready = !(profile?.isLoading ?? draft?.isLoading ?? false);
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
