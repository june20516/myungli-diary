import 'package:flutter/material.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/lock_veil.dart';
import 'package:myungli_diary/design/elements/seal.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/elements/status_tag.dart';
import 'package:myungli_diary/design/elements/term_mark.dart';
import 'package:myungli_diary_widgetbook/stage.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';
import 'package:widgetbook/widgetbook.dart';

const AppGlyph _heart = AppGlyph(
  light: PhosphorIconsLight.heart,
  regular: PhosphorIconsRegular.heart,
);

/// 요소 카탈로그: seal, icon, skeleton.bone, term, lock.veil, tag.status.
final WidgetbookFolder elementsDirectory = WidgetbookFolder(
  name: '요소',
  children: [
    WidgetbookComponent(
      name: 'seal',
      useCases: [
        WidgetbookUseCase(
          name: '변형과 크기',
          builder: (context) => const Stage(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
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
                Seal(size: SealSize.card, variant: SealVariant.soft),
              ],
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'icon',
      useCases: [
        WidgetbookUseCase(
          name: 'Light · Regular · 경고',
          builder: (context) => const Stage(
            child: Wrap(
              spacing: 16,
              children: [
                AppIcon(_heart),
                AppIcon(_heart, weight: AppIconWeight.regular),
                AppIcon.caution(),
              ],
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'skeleton.bone',
      useCases: [
        WidgetbookUseCase(
          name: '먹 숨쉬기',
          builder: (context) => const Stage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBone(width: 220, height: 16, borderRadius: 4),
                SizedBox(height: 8),
                SkeletonBone(width: 160, height: 16, borderRadius: 4, index: 1),
                SizedBox(height: 8),
                SkeletonBone(width: 100, height: 16, borderRadius: 4, index: 2),
              ],
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'term',
      useCases: [
        WidgetbookUseCase(
          name: '문장 안',
          builder: (context) => const Stage(
            child: Text.rich(
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
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'lock.veil',
      useCases: [
        WidgetbookUseCase(
          name: '길이 힌트 없음(두 줄)',
          builder: (context) => const Stage(
            child: SizedBox(
              width: 300,
              child: LockVeil(title: '판정 근거', semanticLabel: '판정 근거, 잠김'),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: '길이 힌트 60자',
          builder: (context) => const Stage(
            child: SizedBox(
              width: 300,
              child: LockVeil(
                title: '판정 근거',
                semanticLabel: '판정 근거, 잠김',
                lengthHint: 60,
              ),
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'tag.status',
      useCases: [
        WidgetbookUseCase(
          name: '진행 중·다음·지금·올해',
          builder: (context) => const Stage(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusTag('진행 중'),
                StatusTag('다음'),
                StatusTag('지금'),
                StatusTag('올해'),
              ],
            ),
          ),
        ),
      ],
    ),
  ],
);
