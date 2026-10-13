import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/lock_veil.dart';
import 'package:myungli_diary/design/elements/seal.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/elements/term_mark.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../../support/fonts.dart';
import '../../support/golden.dart';

const AppGlyph _heart = AppGlyph(
  light: PhosphorIconsLight.heart,
  regular: PhosphorIconsRegular.heart,
);

/// 요소를 한 칸에 모아 보는 golden. 요소는 글자 크기 2.0에서도 줄바꿈으로 흐릅니다.
Widget _elements() {
  return const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Seal(size: SealSize.paper, child: Text('13')),
          Seal(
            size: SealSize.row,
            variant: SealVariant.soft,
            child: Text('13'),
          ),
          Seal(
            size: SealSize.cell,
            variant: SealVariant.outline,
            child: Text('13'),
          ),
          Seal(
            size: SealSize.row,
            child: AppIcon(_heart, size: AppIconSize.inline),
          ),
        ],
      ),
      SizedBox(height: 12),
      Wrap(
        spacing: 12,
        children: [
          AppIcon(_heart),
          AppIcon(_heart, weight: AppIconWeight.regular),
          AppIcon.caution(),
        ],
      ),
      SizedBox(height: 12),
      Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '오늘은 '),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: TermMark('식신'),
            ),
            TextSpan(text: '이 힘을 얻는 날입니다.'),
          ],
        ),
      ),
      SizedBox(height: 12),
      SkeletonBone(width: 200, height: 16, borderRadius: 4, animated: false),
      SizedBox(height: 12),
      LockVeil(title: '판정 근거', semanticLabel: '판정 근거, 잠김'),
    ],
  );
}

void main() {
  setUpAll(() async {
    await loadBundledFonts();
    await loadPhosphorFonts();
  });

  goldenTest('요소 모음', (tester) async {
    await goldenMatrix(tester, 'elements', _elements);
  });

  goldenTest('고정 칸은 글자 크기 2.0에서 1.3에 멈춥니다', (tester) async {
    await goldenMatrix(
      tester,
      'elements_fixed_cell',
      () => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: const Seal(size: SealSize.cell, child: Text('13')),
      ),
      fixedCells: true,
    );
  });
}
