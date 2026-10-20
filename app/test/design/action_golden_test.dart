import 'package:flutter/material.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/action/settings_row.dart';
import 'package:myungli_diary/design/components/action/share_button.dart';
import 'package:myungli_diary/design/components/action/social_login_button.dart';
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

/// 카카오(위)·Apple(아래) × 기본·loading·꺼짐. Apple은 밝기에 따라 검정·흰색입니다.
Widget _socialButtons() => Builder(
  builder: (context) {
    final ja = Localizations.localeOf(context).languageCode == 'ja';
    final kakao = ja ? 'カカオでログイン' : '카카오 로그인';
    final apple = ja ? 'Appleでサインイン' : 'Apple로 로그인';
    // golden에는 플랫폼 시스템 글꼴이 없어 앱 글꼴로 대신합니다.
    final appFont = context.tokens.typography.labelLg.fontFamily;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.s12,
      children: [
        SocialLoginButton(
          provider: SocialProvider.kakao,
          label: kakao,
          onPressed: () {},
        ),
        SocialLoginButton(
          provider: SocialProvider.apple,
          label: apple,
          systemFontFamily: appFont,
          onPressed: () {},
        ),
        SocialLoginButton(
          provider: SocialProvider.kakao,
          label: kakao,
          loading: true,
          animated: false,
          onPressed: () {},
        ),
        SocialLoginButton(
          provider: SocialProvider.apple,
          label: apple,
          systemFontFamily: appFont,
          loading: true,
          animated: false,
          onPressed: () {},
        ),
        SocialLoginButton(
          provider: SocialProvider.kakao,
          label: kakao,
          onPressed: null,
        ),
        SocialLoginButton(
          provider: SocialProvider.apple,
          label: apple,
          systemFontFamily: appFont,
          onPressed: null,
        ),
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

  goldenTest('social-login-button: 카카오·Apple × 기본·loading·꺼짐', (tester) async {
    await goldenMatrix(
      tester,
      'action_social_login_button',
      _socialButtons,
      settle: (tester) => tester.pumpAndSettle(),
    );
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
