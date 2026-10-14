import 'package:flutter/material.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
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

/// 동작 카탈로그: primary-button(filled·quiet·destructive), social-login-button
/// (kakao·apple), share-button(icon·soft).
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
  ],
);
