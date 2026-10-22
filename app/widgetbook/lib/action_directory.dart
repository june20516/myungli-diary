import 'package:flutter/material.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/action/settings_row.dart';
import 'package:myungli_diary/design/components/action/share_button.dart';
import 'package:myungli_diary/design/components/action/social_login_button.dart';
import 'package:myungli_diary_widgetbook/stage.dart';
import 'package:widgetbook/widgetbook.dart';

Widget _button(
  PrimaryButtonVariant variant, {
  required String label,
  bool disabled = false,
  bool loading = false,
}) => SizedBox(
  width: 360,
  child: PrimaryButton(
    label: label,
    variant: variant,
    loading: loading,
    onPressed: disabled ? null : () {},
  ),
);

WidgetbookComponent _variant(PrimaryButtonVariant variant, String label) =>
    WidgetbookComponent(
      name: variant.name,
      useCases: [
        WidgetbookUseCase(
          name: '기본',
          builder: (context) => Stage(child: _button(variant, label: label)),
        ),
        WidgetbookUseCase(
          name: 'disabled',
          builder: (context) =>
              Stage(child: _button(variant, label: label, disabled: true)),
        ),
        WidgetbookUseCase(
          name: 'loading',
          builder: (context) =>
              Stage(child: _button(variant, label: label, loading: true)),
        ),
      ],
    );

WidgetbookComponent _social(SocialProvider provider, String label) =>
    WidgetbookComponent(
      name: provider.name,
      useCases: [
        for (final (name, loading, enabled) in [
          ('기본', false, true),
          ('loading', true, true),
          ('꺼짐', false, false),
        ])
          WidgetbookUseCase(
            name: name,
            builder: (context) => Stage(
              child: SizedBox(
                width: 360,
                child: SocialLoginButton(
                  provider: provider,
                  label: label,
                  loading: loading,
                  onPressed: enabled ? () {} : null,
                ),
              ),
            ),
          ),
        WidgetbookUseCase(
          name: 'connected(login-methods)',
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            final knobs = context.knobs;
            final lastOne = knobs.boolean(label: '마지막 하나(누를 수 없음)');
            return Stage(
              child: SizedBox(
                width: 360,
                child: SocialLoginButton(
                  provider: provider,
                  label: _providerName(l10n, provider),
                  connected: true,
                  connectedLabel: l10n.loginMethodsRowConnected,
                  unlinkHint: l10n.loginMethodsRowUnlink,
                  disabled: knobs.boolean(label: 'disabled(다른 버튼 처리 중)'),
                  loading: knobs.boolean(label: 'loading(떼는 중)'),
                  onPressed: lastOne ? null : () {},
                ),
              ),
            );
          },
        ),
      ],
    );

/// 제공자 이름(`ui.login-methods.row`).
String _providerName(AppLocalizations l10n, SocialProvider provider) =>
    switch (provider) {
      SocialProvider.kakao => l10n.loginProviderKakao,
      SocialProvider.line => l10n.loginProviderLine,
      SocialProvider.google => l10n.loginProviderGoogle,
      SocialProvider.apple => l10n.loginProviderApple,
    };

WidgetbookComponent _share(ShareButtonVariant variant) => WidgetbookComponent(
  name: variant.name,
  useCases: [
    WidgetbookUseCase(
      name: '기본',
      builder: (context) => Stage(
        child: ShareButton(variant: variant, label: '공유', onPressed: () {}),
      ),
    ),
  ],
);

/// 눌러서 켜고 끄는 설정 줄 묶음(navigate·value·toggle·destructive·disabled).
class _SettingsRowsDemo extends StatefulWidget {
  const new();

  @override
  State<_SettingsRowsDemo> createState() => _SettingsRowsDemoState();
}

class _SettingsRowsDemoState extends State<_SettingsRowsDemo> {
  bool _on = true;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 360,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsGroup(
          title: '기본',
          children: [
            SettingsRow(
              variant: SettingsRowVariant.navigate,
              label: '정보 수정',
              onTap: () {},
            ),
            SettingsRow(
              variant: SettingsRowVariant.value,
              label: '알림 시각',
              value: '오전 8:00',
              onTap: () {},
            ),
            SettingsRow(
              variant: SettingsRowVariant.toggle,
              label: '알림',
              toggled: _on,
              onToggle: (value) => setState(() => _on = value),
            ),
            const SettingsRow(
              variant: SettingsRowVariant.navigate,
              label: '계산 기준',
            ),
          ],
        ),
        SettingsGroup(
          children: [
            SettingsRow(
              variant: SettingsRowVariant.destructive,
              label: '로그아웃',
              onTap: () {},
            ),
          ],
        ),
      ],
    ),
  );
}

/// 동작 카탈로그: primary-button(filled·quiet·destructive), social-login-button
/// (kakao·line·google·apple, connected), share-button(icon·soft),
/// settings-row(묶음).
final WidgetbookFolder actionDirectory = WidgetbookFolder(
  name: '동작',
  children: [
    WidgetbookFolder(
      name: 'primary-button',
      children: [
        _variant(PrimaryButtonVariant.filled, '다음'),
        _variant(PrimaryButtonVariant.quiet, '건너뛰기'),
        _variant(PrimaryButtonVariant.destructive, '지우기'),
      ],
    ),
    WidgetbookFolder(
      name: 'social-login-button',
      children: [
        _social(SocialProvider.kakao, '카카오 로그인'),
        _social(SocialProvider.line, 'LINE으로 로그인'),
        _social(SocialProvider.google, 'Google 계정으로 로그인'),
        _social(SocialProvider.apple, 'Apple로 로그인'),
      ],
    ),
    WidgetbookFolder(
      name: 'share-button',
      children: [
        _share(ShareButtonVariant.icon),
        _share(ShareButtonVariant.soft),
      ],
    ),
    WidgetbookComponent(
      name: 'settings-row',
      useCases: [
        WidgetbookUseCase(
          name: '묶음',
          builder: (context) => const Stage(child: _SettingsRowsDemo()),
        ),
      ],
    ),
  ],
);
