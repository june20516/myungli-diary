import 'package:flutter/material.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
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

/// 동작 카탈로그: primary-button(filled·quiet·destructive).
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
  ],
);
