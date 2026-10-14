import 'package:flutter/material.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

import '../support/golden.dart';

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

void main() {
  goldenTest('primary-button: filled·quiet·destructive × 기본·disabled·loading', (
    tester,
  ) async {
    await goldenMatrix(tester, 'action_primary_button', _buttons);
  });
}
