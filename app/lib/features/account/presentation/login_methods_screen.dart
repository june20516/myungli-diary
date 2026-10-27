import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/action/social_login_button.dart';
import 'package:myungli_diary/design/components/feedback/dialog.dart';
import 'package:myungli_diary/design/components/feedback/live_announcement.dart';
import 'package:myungli_diary/design/components/feedback/screen_state_view.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/interaction/single_open_guard.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/account/application/login_methods_controller.dart';
import 'package:myungli_diary/features/auth/model/login_provider_order.dart';

/// 붙이기·떼기 중 어느 쪽 안내를 보일지.
enum _Failure { link, unlink }

/// 로그인 수단(`login-methods`, 결정 D85 ③, V39·V44).
///
/// 위에서 아래로 app-bar, 소개 문장, `social-login-button` 네 줄(순서는 로그인 화면과 같은
/// `loginProviderOrder`), 가로선, 합치기 입구(`primary-button` `quiet`)입니다.
///
/// * 연결된 줄은 `connected`이고 누르면 떼기 확인 창이 열립니다. 연결이 하나뿐이면 그 줄은
///   누를 수 없고 줄 아래에 안내가 붙습니다.
/// * 연결 안 된 줄은 그 제공자 로그인 버튼이고 누르면 붙이기를 시작합니다. 이미 다른 계정에
///   연결된 인증 수단이면 안내 창만 띄우고 이 화면에 남습니다(합치기로 넘어가지 않음).
/// * 붙이기·떼기를 끝내지 못하면 소개 아래에 안내를 보입니다(인증 창을 닫음 포함).
/// * 합치기 입구는 연결 수와 관계없이 늘 보이고, `account-merge`에서 돌아오면 목록을 다시 읽습니다.
/// * 한 줄이 처리 중이면 다른 줄과 합치기 입구는 꺼집니다.
class LoginMethodsScreen extends ConsumerStatefulWidget {
  /// login-methods 화면을 만듭니다.
  const new({super.key});

  /// 합치기 입구 버튼을 찾는 테스트용 키.
  static const Key mergeCtaKey = ValueKey(SlotIds.loginMethodsMergeCta);

  /// 합치기 입구 위 가로선을 찾는 테스트용 키.
  static const Key mergeDividerKey = ValueKey('login-methods.merge.divider');

  /// 오류 안내를 찾는 테스트용 키.
  static const Key errorKey = ValueKey(SlotIds.loginMethodsErrorBody);

  @override
  ConsumerState<LoginMethodsScreen> createState() => _LoginMethodsScreenState();
}

class _LoginMethodsScreenState extends ConsumerState<LoginMethodsScreen>
    with SingleOpenGuard<LoginMethodsScreen> {
  /// 처리 중인 제공자. null이면 처리 중이 아닙니다.
  SocialProvider? _busy;

  /// 마지막 시도의 실패. null이면 안내가 없습니다.
  _Failure? _failure;

  LoginMethodsController get _controller =>
      ref.read(loginMethodsControllerProvider.notifier);

  /// 처리 중이 아닐 때만 [action]을 시작하고, 끝나면 처리 중을 풉니다.
  Future<void> _run(
    SocialProvider provider,
    Future<_Failure?> Function() action,
  ) async {
    // 같은 프레임의 두 번째 누름도 막도록 상태를 바로 바꿉니다.
    if (_busy != null) return;
    setState(() {
      _busy = provider;
      _failure = null;
    });
    final failure = await action();
    if (!mounted) return;
    setState(() {
      _busy = null;
      _failure = failure;
    });
  }

  Future<void> _link(SocialProvider provider) async {
    LinkAttempt? outcome;
    await _run(provider, () async {
      outcome = await _controller.link(provider);
      return outcome is LinkFailed ? _Failure.link : null;
    });
    // 처리 중 표시(숨쉬는 줄)를 푼 뒤에 안내합니다.
    if (outcome is LinkInUse && mounted) {
      await _showInUse();
    }
  }

  /// 붙이려는 인증 수단이 다른 계정에 연결돼 있다는 안내(`dialog` `notice`).
  Future<void> _showInUse() async {
    final l10n = AppLocalizations.of(context);
    await showMyungliNotice(
      context,
      body: l10n.loginMethodsInUseBody,
      identifier: SlotIds.loginMethodsInUseBody,
      confirm: l10n.actionConfirm,
    );
  }

  Future<void> _unlink(SocialProvider provider) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showMyungliDialog(
      context,
      variant: DialogVariant.destructive,
      title: l10n.loginMethodsUnlinkConfirm(_providerName(l10n, provider)),
      body: l10n.loginMethodsUnlinkConfirmBody,
      confirm: l10n.loginMethodsUnlinkConfirmUnlink,
      cancel: l10n.loginMethodsUnlinkConfirmCancel,
      identifier: SlotIds.loginMethodsUnlinkConfirm,
    );
    if (!confirmed || !mounted) return;
    await _run(provider, () async {
      final outcome = await _controller.unlink(provider);
      return outcome is UnlinkFailed ? _Failure.unlink : null;
    });
  }

  /// 계정 합치기로 가고, 돌아오면 목록을 다시 읽습니다.
  void _openMerge() => guardOpen(() async {
    await context.push<void>(pathOf(ScreenIds.accountMerge));
    if (mounted) {
      await _controller.refresh();
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final methods = ref.watch(loginMethodsControllerProvider);
    return Semantics(
      identifier: ScreenIds.loginMethods,
      child: Scaffold(
        key: const ValueKey(ScreenIds.loginMethods),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MyungliAppBar.inner(
                title: l10n.loginMethodsBarTitle,
                titleIdentifier: SlotIds.loginMethodsBarTitle,
                showBack: MyungliAppBar.canGoBack(context),
              ),
              Expanded(
                child: ScreenStateView<List<SocialProvider>>(
                  value: methods,
                  onRetry: () => ref.invalidate(loginMethodsControllerProvider),
                  data: _content,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(List<SocialProvider> linked) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final order = loginProviderOrder(Localizations.localeOf(context));
    final failure = _failure;
    final failureMessage = switch (failure) {
      _Failure.link => l10n.loginMethodsErrorBodyLink,
      _Failure.unlink => l10n.loginMethodsErrorBodyUnlink,
      null => null,
    };
    final busy = _busy;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        Space.s20,
        Space.s12,
        Space.s20,
        Space.s24 + bottom,
      ),
      children: [
        Semantics(
          identifier: SlotIds.loginMethodsIntroBody,
          child: Text(
            l10n.loginMethodsIntroBody,
            style: tokens.typography.bodyUi.copyWith(
              color: tokens.colors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: Space.s20),
        if (failureMessage != null) ...[
          LiveAnnouncement(
            key: LoginMethodsScreen.errorKey,
            identifier: SlotIds.loginMethodsErrorBody,
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
        for (final (index, provider) in order.indexed) ...[
          if (index > 0) const SizedBox(height: Space.s12),
          _row(l10n, provider, linked: linked, busy: busy),
          if (linked.length == 1 && linked.single == provider) ...[
            const SizedBox(height: Space.s8),
            Semantics(
              identifier: SlotIds.loginMethodsLastNotice,
              child: Text(
                l10n.loginMethodsLastNotice,
                style: tokens.typography.bodyUi.copyWith(
                  color: tokens.colors.textSecondary,
                ),
              ),
            ),
          ],
        ],
        const SizedBox(height: Space.s32),
        Container(
          key: LoginMethodsScreen.mergeDividerKey,
          height: 1,
          color: tokens.colors.line,
        ),
        const SizedBox(height: Space.s16),
        PrimaryButton(
          key: LoginMethodsScreen.mergeCtaKey,
          variant: PrimaryButtonVariant.quiet,
          label: l10n.loginMethodsMergeCta,
          identifier: SlotIds.loginMethodsMergeCta,
          onPressed: busy == null ? _openMerge : null,
        ),
      ],
    );
  }

  Widget _row(
    AppLocalizations l10n,
    SocialProvider provider, {
    required List<SocialProvider> linked,
    required SocialProvider? busy,
  }) {
    final connected = linked.contains(provider);
    final idle = busy == null;
    return SocialLoginButton(
      provider: provider,
      loading: busy == provider,
      // 다른 줄이 처리 중이면 흐리게 꺼 둡니다.
      disabled: !idle && busy != provider,
      connected: connected,
      connectedLabel: connected ? l10n.loginMethodsRowConnected : null,
      label: connected
          ? _providerName(l10n, provider)
          : _loginLabel(l10n, provider),
      onPressed: switch ((connected, idle)) {
        (true, true) when linked.length > 1 => () => _unlink(provider),
        (false, true) => () => _link(provider),
        _ => null,
      },
    );
  }
}

/// 제공자 이름("카카오").
String _providerName(AppLocalizations l10n, SocialProvider provider) =>
    switch (provider) {
      SocialProvider.kakao => l10n.loginProviderKakao,
      SocialProvider.line => l10n.loginProviderLine,
      SocialProvider.google => l10n.loginProviderGoogle,
      SocialProvider.apple => l10n.loginProviderApple,
    };

/// 연결 안 된 줄의 로그인 버튼 문구(로그인 화면과 같은 제공자 공식 문구).
String _loginLabel(AppLocalizations l10n, SocialProvider provider) =>
    switch (provider) {
      SocialProvider.kakao => l10n.loginKakaoLabel,
      SocialProvider.line => l10n.loginLineLabel,
      SocialProvider.google => l10n.loginGoogleLabel,
      SocialProvider.apple => l10n.loginAppleLabel,
    };
