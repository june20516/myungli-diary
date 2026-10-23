import 'package:flutter/material.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/offer_card.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/action/purchase_row.dart';
import 'package:myungli_diary/design/components/action/purchase_row_sample.dart';
import 'package:myungli_diary/design/components/action/settings_row.dart';
import 'package:myungli_diary/design/components/action/share_button.dart';
import 'package:myungli_diary/design/components/action/social_login_button.dart';
import 'package:myungli_diary/design/components/action/social_provider_text.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import '../support/golden.dart';

/// settings-row: 묶음 제목 + navigate·value·toggle(켬·끔)·disabled,
/// 아래 묶음 destructive 둘.
Widget _settingsRows() => Builder(
  builder: (context) {
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          title: ja ? '基本' : '기본',
          children: [
            SettingsRow(
              variant: SettingsRowVariant.navigate,
              label: ja ? '情報の修正' : '정보 수정',
              onTap: () {},
            ),
            SettingsRow(
              variant: SettingsRowVariant.value,
              label: ja ? '通知時刻' : '알림 시각',
              value: ja ? '午前8:00' : '오전 8:00',
              onTap: () {},
            ),
            SettingsRow(
              variant: SettingsRowVariant.toggle,
              label: ja ? '通知' : '알림',
              toggled: true,
              onToggle: (_) {},
            ),
            SettingsRow(
              variant: SettingsRowVariant.toggle,
              label: ja ? '通知' : '알림',
              onToggle: (_) {},
            ),
            SettingsRow(
              variant: SettingsRowVariant.navigate,
              label: ja ? '計算の基準' : '계산 기준',
            ),
          ],
        ),
        SettingsGroup(
          children: [
            SettingsRow(
              variant: SettingsRowVariant.destructive,
              label: ja ? 'ログアウト' : '로그아웃',
              onTap: () {},
            ),
            SettingsRow(
              variant: SettingsRowVariant.destructive,
              label: ja ? 'アカウント削除' : '계정 삭제',
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  },
);

/// 변형 3 × 상태(기본·disabled·loading). pressed는 움직이는 상태라 담지 않습니다.
Widget _buttons() => Builder(
  builder: (context) {
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    String label(PrimaryButtonVariant variant) => switch (variant) {
      PrimaryButtonVariant.filled => ja ? '次へ' : '다음',
      PrimaryButtonVariant.quiet => ja ? 'あとで' : '건너뛰기',
      PrimaryButtonVariant.destructive => ja ? '削除する' : '지우기',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s8,
      children: [
        for (final variant in PrimaryButtonVariant.values) ...[
          PrimaryButton(
            label: label(variant),
            variant: variant,
            onPressed: () {},
          ),
          PrimaryButton(
            label: label(variant),
            variant: variant,
            onPressed: null,
          ),
          PrimaryButton(
            label: label(variant),
            variant: variant,
            loading: true,
            animated: false,
            onPressed: () {},
          ),
        ],
      ],
    );
  },
);

/// 카카오·LINE·Google·Apple × 기본·loading·꺼짐. Apple·Google은 밝기에 따라 바뀝니다.
Widget _socialButtons() => Builder(
  builder: (context) {
    final l10n = AppLocalizations.of(context);
    // golden에는 플랫폼 시스템 글꼴이 없어 앱 글꼴로 대신합니다.
    final appFont = context.tokens.typography.labelLg.fontFamily;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s12,
      children: [
        for (final provider in SocialProvider.values) ...[
          SocialLoginButton(
            provider: provider,
            label: socialProviderLabel(l10n, provider),
            systemFontFamily: appFont,
            onPressed: () {},
          ),
          SocialLoginButton(
            provider: provider,
            label: socialProviderLabel(l10n, provider),
            systemFontFamily: appFont,
            loading: true,
            animated: false,
            onPressed: () {},
          ),
          SocialLoginButton(
            provider: provider,
            label: socialProviderLabel(l10n, provider),
            systemFontFamily: appFont,
            onPressed: null,
          ),
        ],
      ],
    );
  },
);

/// connected(login-methods) 네 제공자 + 마지막 하나(누를 수 없음)·disabled·loading.
Widget _socialConnected() => Builder(
  builder: (context) {
    final l10n = AppLocalizations.of(context);
    SocialLoginButton row(
      SocialProvider provider, {
      bool pressable = true,
      bool disabled = false,
      bool loading = false,
    }) => SocialLoginButton(
      provider: provider,
      label: socialProviderName(l10n, provider),
      connected: true,
      connectedLabel: l10n.loginMethodsRowConnected,
      unlinkHint: l10n.loginMethodsRowUnlink,
      disabled: disabled,
      loading: loading,
      animated: false,
      onPressed: pressable ? () {} : null,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s12,
      children: [
        for (final provider in SocialProvider.values) row(provider),
        row(SocialProvider.kakao, pressable: false),
        row(SocialProvider.line, disabled: true),
        row(SocialProvider.apple, loading: true),
      ],
    );
  },
);

/// offer-card: available·active·purchasing·offline. 문구는 ARB(`adFree*`)에서 읽고,
/// 가격 자리는 '—'입니다(공개 저장소라 가격 수치를 쓰지 않음). 구매 버튼 문구는 ARB에 아직 없어(임시 키는
/// 화면 task가 더함) golden에서만 고정 문구를 씁니다.
Widget _offerCards() => Builder(
  builder: (context) {
    final l10n = AppLocalizations.of(context);
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    OfferCard card(OfferCardState state) => OfferCard(
      state: state,
      head: l10n.adFreeOfferHead,
      price: l10n.adFreeOfferPrice('—'),
      buyLabel: ja ? '購入する' : '구매하기',
      historyLabel: l10n.adFreeHistoryCta,
      legalNotice: l10n.adFreeLegalNotice,
      statusLabel: l10n.purchaseStatusActive,
      remaining: l10n.adFreeStatusRemaining(ja ? '11月23日' : '11월 23일'),
      onBuy: () {},
      onHistory: () {},
      onLegal: () {},
      animated: false,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s12,
      children: [for (final state in OfferCardState.values) card(state)],
    );
  },
);

/// purchase-row: 사용 중, 대기, 만료, 환불, 기간 없음 한 묶음과 loading.
/// 견본은 앱 lib의 `purchaseRowSamples`(widgetbook과 공용)입니다.
Widget _purchaseRows() => Builder(
  builder: (context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s12,
      children: [
        PurchaseRowGroup(rows: purchaseRowSamples(l10n, locale)),
        const PurchaseRowGroup.loading(animated: false),
      ],
    );
  },
);

/// share-button: icon(앱 바 동작)·soft(본문 안 입구).
Widget _shareButtons() => Builder(
  builder: (context) {
    final label = Localizations.localeOf(context).languageCode == 'ja'
        ? '共有'
        : '공유';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Space.s12,
      children: [
        ShareButton(
          variant: ShareButtonVariant.icon,
          label: label,
          onPressed: () {},
        ),
        ShareButton(
          variant: ShareButtonVariant.soft,
          label: label,
          onPressed: () {},
        ),
      ],
    );
  },
);

void main() {
  goldenTest('primary-button: filled·quiet·destructive × 기본·disabled·loading', (
    tester,
  ) async {
    await goldenMatrix(tester, 'action_primary_button', _buttons);
  });

  goldenTest('social-login-button: 카카오·LINE·Google·Apple × 기본·loading·꺼짐', (
    tester,
  ) async {
    await goldenMatrix(
      tester,
      'action_social_login_button',
      _socialButtons,
      settle: (tester) => tester.pumpAndSettle(),
    );
  });

  goldenTest('social-login-button: connected 네 제공자·마지막 하나·disabled·loading', (
    tester,
  ) async {
    await goldenMatrix(
      tester,
      'action_social_login_connected',
      _socialConnected,
      settle: (tester) => tester.pumpAndSettle(),
    );
  });

  goldenTest('offer-card: available·active·purchasing·offline', (tester) async {
    await goldenMatrix(tester, 'action_offer_card', _offerCards);
  });

  goldenTest('purchase-row: 상태 넷, 기간 없음, loading', (tester) async {
    await goldenMatrix(tester, 'action_purchase_row', _purchaseRows);
  });

  goldenTest('share-button: icon·soft', (tester) async {
    await goldenMatrix(tester, 'action_share_button', _shareButtons);
  });

  goldenTest('settings-row: navigate·value·toggle·disabled·destructive, 묶음', (
    tester,
  ) async {
    await goldenMatrix(tester, 'action_settings_row', _settingsRows);
  });
}
