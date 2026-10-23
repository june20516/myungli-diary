import 'package:flutter/material.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/offer_card.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/action/settings_row.dart';
import 'package:myungli_diary/design/components/action/share_button.dart';
import 'package:myungli_diary/design/components/action/social_login_button.dart';
import 'package:myungli_diary/design/components/action/social_provider_text.dart';
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

WidgetbookComponent _social(SocialProvider provider) => WidgetbookComponent(
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
              label: socialProviderLabel(
                AppLocalizations.of(context),
                provider,
              ),
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
              label: socialProviderName(l10n, provider),
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

WidgetbookUseCase _offerCard(OfferCardState state) => WidgetbookUseCase(
  name: state.name,
  builder: (context) {
    final l10n = AppLocalizations.of(context);
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    return Stage(
      child: SizedBox(
        width: 360,
        child: OfferCard(
          state: state,
          head: l10n.adFreeOfferHead,
          // 공개 저장소라 가격 수치를 쓰지 않습니다.
          price: l10n.adFreeOfferPrice('—'),
          // 구매 버튼 문구는 아직 ARB에 없어(임시 키는 화면 task가 더함) 여기서만 고정 문구입니다.
          buyLabel: ja ? '購入する' : '구매하기',
          historyLabel: l10n.adFreeHistoryCta,
          legalNotice: l10n.adFreeLegalNotice,
          statusLabel: l10n.purchaseStatusActive,
          remaining: l10n.adFreeStatusRemaining(ja ? '11月23日' : '11월 23일'),
          onBuy: () {},
          onHistory: () {},
          onLegal: () {},
        ),
      ),
    );
  },
);

/// 동작 카탈로그: primary-button(filled·quiet·destructive), social-login-button
/// (kakao·line·google·apple, connected), offer-card(네 상태),
/// share-button(icon·soft),
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
        for (final provider in SocialProvider.values) _social(provider),
      ],
    ),
    WidgetbookComponent(
      name: 'offer-card',
      useCases: [for (final state in OfferCardState.values) _offerCard(state)],
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
