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
import 'package:myungli_diary/features/onboarding/application/onboarding_finish.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/features/onboarding/presentation/onboarding_navigation.dart';
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
/// * 프로필 저장이 입력 오류였으면(약관 동의 직후, 또는 로그인한 채 마친 온보딩) 그 안내를
///   보이고 입력을 보여 줍니다. 호칭 오류(`name.*`, 필드 `/honorific`)는 입력 칸 아래 오류
///   줄로, 그 밖은 toast로 보입니다. 화면이 떠 있는 동안 새 안내가 와도(뒤 단계에서 돌아옴) 같습니다.
/// * 아니면, 진입이 `profileRequired`이고 입력이 완전하면(미리보기·동의 뒤 프로필 저장 전에
///   앱이 꺼짐) 같은 질문을 다시 묻지 않고 프로필을 저장합니다. 이동은 진입 갱신이 정합니다.
class OnboardCallScreen extends ConsumerStatefulWidget {
  /// onboard-call 화면을 만듭니다.
  const new({super.key});

  @override
  ConsumerState<OnboardCallScreen> createState() => _OnboardCallScreenState();
}

/// [error]가 호칭 입력 칸에 붙는 오류인지. 필드 위치가 `/honorific`이거나 code가 `name.*`입니다.
bool isHonorificProblem(AppError error) =>
    fieldProblemAt(error, profilePointers.honorific) != null ||
    (error is ProblemError && error.code.startsWith('name.'));

/// 호칭 칸 오류 줄의 문구. 필드 오류의 code에 문구가 있으면 그것을, 없으면 전체 오류 문구입니다.
String honorificProblemMessage(AppLocalizations l10n, AppError error) {
  final fieldCode = fieldProblemAt(error, profilePointers.honorific)?.code;
  final fieldMessage = fieldCode == null ? null : problemMessages[fieldCode];
  return fieldMessage?.call(l10n) ?? errorMessage(l10n, error);
}

class _OnboardCallScreenState extends ConsumerState<OnboardCallScreen> {
  bool _entryChecked = false;

  /// 입력으로 프로필을 저장하는 중이면 true. 그동안 질문을 그리지 않습니다.
  bool _resuming = false;

  /// 호칭 칸에 붙인 server 오류. 사용자가 호칭을 고치면 지웁니다.
  AppError? _honorificProblem;

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
        _takeRejection();
      } else if (_resuming) {
        unawaited(_resume());
      }
    });
  }

  /// 남은 입력 오류 안내를 꺼내 보입니다.
  void _takeRejection() {
    if (!mounted) return;
    final rejection = ref
        .read(onboardingRejectionNoticeProvider.notifier)
        .take();
    if (rejection != null) _showRejection(rejection);
  }

  Future<void> _resume() async {
    final completer = ref.read(onboardingCompleterProvider);
    try {
      if (await completer.isReady()) {
        await completer.complete();
      }
    } on OnboardingInputRejected catch (rejected) {
      _showRejection(rejected.error);
    } on Object catch (error) {
      // 실패하면 질문을 보여 이어서 고치거나 다시 저장할 수 있게 합니다.
      _showError(onboardingErrorOf(error));
    } finally {
      if (mounted) setState(() => _resuming = false);
    }
  }

  /// 입력 오류: 호칭 오류는 칸 아래 오류 줄로, 그 밖은 toast로 보입니다.
  void _showRejection(AppError error) {
    if (!mounted) return;
    if (isHonorificProblem(error)) {
      setState(() => _honorificProblem = error);
      return;
    }
    _showError(error);
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
    if (!edit) {
      // 뒤 단계(성별·출생지)의 저장이 입력 오류면 안내를 남기고 이 화면으로 돌아옵니다.
      // 안내를 비우는 일은 provider 알림이 끝난 뒤에 합니다.
      ref.listen<AppError?>(onboardingRejectionNoticeProvider, (_, next) {
        if (next != null) scheduleMicrotask(_takeRejection);
      });
    }
    final problem = _honorificProblem;
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
              MyungliAppBar.inner(
                // 스택 바닥(갈래의 첫 화면, 딥링크·복원)이면 돌아갈 곳이 없어 숨깁니다.
                title: AppLocalizations.of(context).onboardCallBarTitle,
                titleIdentifier: SlotIds.onboardCallBarTitle,
                showBack: MyungliAppBar.canGoBack(context),
              ),
              Expanded(
                child: ready
                    ? _CallForm(
                        mode: mode,
                        initial: initial ?? '',
                        error: problem == null
                            ? null
                            : honorificProblemMessage(
                                AppLocalizations.of(context),
                                problem,
                              ),
                        onEdited: () {
                          if (_honorificProblem != null) {
                            setState(() => _honorificProblem = null);
                          }
                        },
                      )
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
  const new({
    required this.mode,
    required this.initial,
    required this.error,
    required this.onEdited,
  });

  final OnboardingStepMode mode;
  final String initial;

  /// 호칭 칸 오류 줄 문구(server 422). 있으면 칸이 오류 모양이고 다음 버튼이 꺼집니다.
  final String? error;

  /// 사용자가 호칭 글자를 바꿨을 때. 오류 줄을 지웁니다.
  final VoidCallback onEdited;

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

  /// 마지막으로 본 글자. 커서·선택만 바뀐 알림은 고친 것으로 치지 않습니다.
  late String _lastText = widget.initial;

  void _onTextChanged() {
    if (_controller.text != _lastText) {
      _lastText = _controller.text;
      widget.onEdited();
    }
    setState(() {});
  }

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
      final draft = await ref
          .read(onboardingDraftProvider.notifier)
          .update((d) => d.copyWith(honorific: honorific));
      if (!mounted) return;
      // 로그인했고 프로필이 없는 계정의 입력이 이미 완전하면(앞선 저장이 실패함) 다음이 곧
      // 다시 저장입니다. 이동은 저장 뒤 진입 갱신이 정합니다.
      final finishes =
          ref.read(finishesWithoutPreviewProvider) &&
          draft.isCompleteFor(
            deviceRegionIsKorea: ref.read(deviceRegionIsKoreaProvider),
          );
      if (!finishes) {
        await context.push<void>(pathOf(ScreenIds.onboardBirth));
        return;
      }
      try {
        await ref.read(onboardingFinishProvider)();
      } on OnboardingInputRejected catch (rejected) {
        // 이 화면에 머물며 화면 상태가 안내를 꺼내 칸이나 toast로 보입니다.
        if (!mounted) return;
        returnToOnboardCallWith(context, ref, rejected.error);
      } on Object catch (error) {
        // 저장이 실패해도 미처리 비동기 오류로 남기지 않고 안내합니다. 입력은 남습니다.
        if (!mounted) return;
        showMyungliToast(
          context,
          errorMessage(AppLocalizations.of(context), onboardingErrorOf(error)),
        );
      }
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
        error: widget.error != null,
        hint: l10n.onboardCallInputHint,
        maxLength: honorificMaxLength(ref.watch(appLanguageProvider)),
        identifier: SlotIds.onboardCallInputHint,
        onSubmitted: (_) => _submit(),
      ),
      help: l10n.onboardCallNoteBody,
      helpIdentifier: SlotIds.onboardCallNoteBody,
      // IA에 이 화면의 오류 슬롯이 없어 오류 줄 identifier는 두지 않습니다.
      error: widget.error,
      actionLabel: edit ? l10n.onboardingSave : l10n.onboardingNext,
      actionLoading: _saving,
      onAction: _honorific.isEmpty ? null : _submit,
    );
  }
}
