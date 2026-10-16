import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/feedback/live_announcement.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/input/input_step.dart';
import 'package:myungli_diary/design/components/input/time_picker.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/onboarding/application/notify_ask_controller.dart';

/// IA `notify-ask`의 출구 대상. 허락·건너뛰기 모두 알림 허락 대기 플래그를 끄고 진입을 다시
/// 계산하는 이동이라 라우터 redirect가 `ad-consent`로 보냅니다. 화면이 직접 이동하지 않습니다.
const Set<String> notifyAskExits = {ScreenIds.adConsent};

/// 저장 실패 안내를 찾는 테스트용 키.
const Key notifyAskErrorKey = ValueKey('notify-ask.error');

/// 건너뛰기 버튼을 찾는 테스트용 키.
const Key notifyAskSkipKey = ValueKey(SlotIds.notifyAskCtaSkip);

/// 기본 알림 시각(08:00). 분은 5의 배수여야 합니다.
const TimeOfDay _defaultNotifyTime = TimeOfDay(hour: 8, minute: 0);

/// 아침 운세 알림 시각과 권한을 받습니다(D18 ⑨, 결정 A17).
///
/// 새 계정이 프로필을 저장한 뒤 진입 갈래(`notifyAskRequired`)의 첫 화면이라 돌아갈 곳이
/// 없어 뒤로 버튼을 두지 않습니다. 시각을 고르고 허락하면 권한을 요청해 기기를 등록하고,
/// 건너뛰어도 같은 곳으로 갑니다. 처리 중에는 두 버튼 모두 다시 받지 않습니다. 실패하면
/// 안내를 보이고 다시 누르거나 건너뛸 수 있습니다.
class NotifyAskScreen extends ConsumerStatefulWidget {
  /// notify-ask 화면을 만듭니다.
  const new({super.key});

  @override
  ConsumerState<NotifyAskScreen> createState() => _NotifyAskScreenState();
}

class _NotifyAskScreenState extends ConsumerState<NotifyAskScreen> {
  TimeOfDay _time = _defaultNotifyTime;

  bool _busy = false;

  /// 마지막 실패. null이면 안내가 없습니다.
  AppError? _failure;

  Future<void> _submit(
    Future<AppError?> Function(NotifyAskController controller) action,
  ) async {
    // 같은 프레임의 두 번째 누름도 막도록 상태를 바로 바꿉니다.
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final failure = await action(
      ref.read(notifyAskControllerProvider.notifier),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failure = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 처리 중에 controller가 버려지지 않게 화면이 붙들어 둡니다.
    ref.watch(notifyAskControllerProvider);
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final failure = _failure;
    final failureMessage = failure == null ? null : errorMessage(l10n, failure);
    return Semantics(
      identifier: ScreenIds.notifyAsk,
      child: Scaffold(
        key: const ValueKey(ScreenIds.notifyAsk),
        body: SafeArea(
          child: Column(
            children: [
              MyungliAppBar.inner(
                title: l10n.notifyAskBarTitle,
                titleIdentifier: SlotIds.notifyAskBarTitle,
                showBack: false,
              ),
              Expanded(
                child: InputStep(
                  screenId: ScreenIds.notifyAsk,
                  variant: InputStepVariant.standalone,
                  question: l10n.notifyAskQuestionHead,
                  input: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TimePicker(
                        variant: TimePickerVariant.notify,
                        value: _time,
                        onChanged: (value) => setState(() => _time = value),
                      ),
                      if (failureMessage != null) ...[
                        const SizedBox(height: Space.s16),
                        LiveAnnouncement(
                          key: notifyAskErrorKey,
                          label: failureMessage,
                          role: SemanticsRole.alert,
                          child: Text(
                            failureMessage,
                            style: tokens.typography.bodyUi.copyWith(
                              color: tokens.colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  help: l10n.notifyAskWhyBody,
                  helpIdentifier: SlotIds.notifyAskWhyBody,
                  actionLabel: l10n.notifyAskCtaAllow,
                  actionIdentifier: SlotIds.notifyAskCtaAllow,
                  actionLoading: _busy,
                  onAction: () => _submit((c) => c.allow(_time)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.s20,
                  0,
                  Space.s20,
                  Space.s8,
                ),
                child: PrimaryButton(
                  key: notifyAskSkipKey,
                  variant: PrimaryButtonVariant.quiet,
                  label: l10n.notifyAskCtaSkip,
                  identifier: SlotIds.notifyAskCtaSkip,
                  onPressed: _busy ? null : () => _submit((c) => c.skip()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
