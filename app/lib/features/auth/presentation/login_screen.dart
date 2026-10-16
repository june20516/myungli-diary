import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/error_messages.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/platform/social_auth.dart';
import 'package:myungli_diary/design/components/action/social_login_button.dart';
import 'package:myungli_diary/design/components/feedback/dialog.dart';
import 'package:myungli_diary/design/components/feedback/live_announcement.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/frame/onboarding_page_layout.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/auth/application/login_controller.dart';

/// IA `login`의 출구 대상. 모두 진입 상태가 바뀌는 이동이라 화면은 직접 이동하지 않고
/// 로그인 뒤 진입 갱신으로 라우터 redirect가 보냅니다.
const Set<String> loginExits = {
  ScreenIds.consent,
  ScreenIds.today,
  ScreenIds.adConsent,
};

/// IA `login`이 직접 처리하는 상태. 로그인 실패와 취소를 버튼 위 안내로 그립니다.
const Set<String> loginHandledStates = {'error'};

/// 오류 상태 안내를 찾는 테스트용 키.
const Key loginErrorKey = ValueKey('login.error');

/// 소셜 로그인(D55, D50). 카카오 위, Apple 아래이고 두 버튼은 같은 크기입니다.
///
/// 슬롯이 모두 `ui`(ARB 문자열)라 `SentenceBlock` 대신 같은 글자 역할의 [Text]로 그립니다.
/// 한 버튼이 처리 중이면 두 버튼 모두 다시 받지 않습니다. 실패하거나 취소하면 버튼 위에
/// 안내를 보이고, 다시 누르면 새 nonce로 처음부터 다시 로그인합니다.
class LoginScreen extends ConsumerStatefulWidget {
  /// login 화면을 만듭니다.
  const new({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  /// 처리 중인 제공자. null이면 처리 중이 아닙니다.
  SocialProvider? _busy;

  /// 마지막 시도의 실패·취소. null이면 안내가 없습니다.
  LoginOutcome? _failure;

  Future<void> _signIn(SocialProvider provider) async {
    // 같은 프레임의 두 번째 누름도 막도록 상태를 바로 바꿉니다.
    if (_busy != null) return;
    setState(() {
      _busy = provider;
      _failure = null;
    });
    final controller = ref.read(loginControllerProvider.notifier);
    final outcome = switch (provider) {
      SocialProvider.kakao => await controller.signInWithKakao(
        showDiscardNotice: _showDiscardNotice,
      ),
      SocialProvider.apple => await controller.signInWithApple(
        showDiscardNotice: _showDiscardNotice,
      ),
    };
    if (!mounted) return;
    setState(() {
      _busy = null;
      _failure = outcome is LoginSucceeded ? null : outcome;
    });
  }

  /// 사주가 저장된 계정이라 방금 입력을 쓰지 않는다는 안내(`dialog` `notice`).
  /// 확인·바깥 누르기·뒤로 가기 모두 읽었다는 뜻이고, 닫히면 로그인이 이어집니다.
  Future<void> _showDiscardNotice() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    await showMyungliNotice(
      context,
      body: l10n.loginDiscardNotice,
      identifier: SlotIds.loginDiscardNotice,
      confirm: l10n.actionConfirm,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 처리 중에 controller가 버려지지 않게 화면이 붙들어 둡니다.
    ref.watch(loginControllerProvider);
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final failure = _failure;
    final failureMessage = failure == null
        ? null
        : _failureMessage(l10n, failure);
    return Semantics(
      identifier: ScreenIds.login,
      child: Scaffold(
        key: const ValueKey(ScreenIds.login),
        body: SafeArea(
          child: Column(
            children: [
              MyungliAppBar.inner(
                // 스택 바닥(갈래의 첫 화면, 딥링크·복원)이면 돌아갈 곳이 없어 숨깁니다.
                title: '',
                showBack: MyungliAppBar.canGoBack(context),
              ),
              Expanded(
                child: OnboardingPageLayout(
                  body: [
                    Semantics(
                      identifier: SlotIds.loginTitleHead,
                      header: true,
                      child: Text(
                        l10n.loginTitleHead,
                        key: const ValueKey(SlotIds.loginTitleHead),
                        style: tokens.typography.title.copyWith(
                          color: tokens.colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.s12),
                    Semantics(
                      identifier: SlotIds.loginTitleBody,
                      child: Text(
                        l10n.loginTitleBody,
                        key: const ValueKey(SlotIds.loginTitleBody),
                        style: tokens.typography.bodyUi.copyWith(
                          color: tokens.colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                  actions: [
                    if (failureMessage != null) ...[
                      LiveAnnouncement(
                        key: loginErrorKey,
                        label: failureMessage,
                        role: SemanticsRole.alert,
                        child: Text(
                          failureMessage,
                          style: tokens.typography.bodyUi.copyWith(
                            color: tokens.colors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.s16),
                    ],
                    _button(SocialProvider.kakao, l10n.loginKakaoLabel),
                    const SizedBox(height: Space.s12),
                    _button(SocialProvider.apple, l10n.loginAppleLabel),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _button(SocialProvider provider, String label) {
    final busy = _busy;
    return SocialLoginButton(
      provider: provider,
      label: label,
      loading: busy == provider,
      // 다른 버튼이 처리 중이면 꺼 둡니다.
      onPressed: busy == null || busy == provider
          ? () => _signIn(provider)
          : null,
    );
  }
}

/// 실패·취소 결과의 안내 문구.
String _failureMessage(AppLocalizations l10n, LoginOutcome outcome) =>
    switch (outcome) {
      LoginCancelled() => l10n.loginCancelled,
      LoginFailed(:final error) => errorMessage(l10n, error),
      AppleWebFailed(:final error) => _appleWebMessage(l10n, error),
      LoginSucceeded() => throw StateError('성공은 안내하지 않습니다.'),
    };

String _appleWebMessage(AppLocalizations l10n, AppleWebError error) =>
    switch (error) {
      AppleWebError.stateMismatch => l10n.appleWebErrorStateMismatch,
      AppleWebError.userCancelled => l10n.appleWebErrorCancelled,
      AppleWebError.providerUnavailable => l10n.errorAuthProviderUnavailable,
      AppleWebError.tokenInvalid => l10n.errorAuthProviderTokenInvalid,
      AppleWebError.invalidRequest ||
      AppleWebError.serverError ||
      AppleWebError.unknown => l10n.appleWebErrorOther,
    };
