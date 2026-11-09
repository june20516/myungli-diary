import 'package:flutter/material.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/components/sentence/vertical_hit_slop.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

const AppGlyph _caretRight = AppGlyph(
  light: PhosphorIconsLight.caretRight,
  regular: PhosphorIconsRegular.caretRight,
);

/// [SectionHeader] 오른쪽 자리(`section-header.parts.trailing`). 하나만 둡니다.
sealed class SectionHeaderTrailing {
  const new();
}

/// 꺾쇠 링크(`link`): 섹션 내용을 더 보는 다른 화면으로 이동합니다.
final class SectionHeaderLink extends SectionHeaderTrailing {
  /// [label] 뒤에 `caret-right`를 붙여 그립니다.
  const new({required this.label, required this.onTap});

  /// 링크 글자(스크린리더도 그대로 읽음).
  final String label;

  /// 눌렀을 때(화면 이동, `page.push`).
  final VoidCallback onTap;
}

/// 아이콘 동작(`action`) 더하기 같은 아이콘 하나.
final class SectionHeaderAction extends SectionHeaderTrailing {
  /// 24 Light 아이콘 [icon]을 44 터치 영역에 둡니다.
  const new({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.identifier,
  });

  /// 아이콘.
  final AppGlyph icon;

  /// IA 슬롯 id(예: `day-sheet.event.add`). 있으면 Semantics `identifier`로 붙입니다.
  final String? identifier;

  /// 동작 이름(스크린리더).
  final String semanticLabel;

  /// 눌렀을 때.
  final VoidCallback onTap;
}

/// 좋아요 버튼처럼 이미 눌림과 의미를 가진 위젯(`reaction-button`)을 그대로 놓습니다.
final class SectionHeaderActionWidget extends SectionHeaderTrailing {
  /// [child]를 제목 줄 오른쪽 끝에 놓습니다.
  const new(this.child);

  /// 오른쪽 자리에 놓을 위젯.
  final Widget child;
}

/// 섹션 제목(`section-header`, V59, V69): 굵은 라벨, 선택 설명 줄, 오른쪽 자리 하나.
///
/// 시작선은 카드 바깥 가장자리이고, 좌우 여백(화면 `space.20`, 시트 안 `space.24`)은 이 위젯이
/// 놓이는 부모의 내용 여백이 줍니다. 이 위젯은 자체 여백을 두지 않습니다.
/// 제목이 줄바꿈되어도 오른쪽 자리는 제 크기를 지키고 제목이 남는 폭에서 내려갑니다.
class SectionHeader extends StatelessWidget {
  /// 섹션 제목 [title]과 선택 [description], [trailing]으로 만듭니다.
  const new({
    required this.title,
    this.description,
    this.trailing,
    this.titleIdentifier,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'section-header',
    {'plain', 'link', 'action'},
    {'pressed'},
  );

  /// 제목과 내용 사이 간격(`section-header.parts.contentGap`). 이 위젯 아래에 두는 쪽이 씁니다.
  static const double contentGap = Space.s12;

  /// 섹션과 섹션 사이 간격(`section-header.parts.sectionGap`).
  static const double sectionGap = Space.s32;

  /// 오른쪽 자리 터치 최소 크기(`action.minTarget`).
  static const double minTarget = 44;

  /// 제목 글자.
  final String title;

  /// 설명 줄(선택).
  final String? description;

  /// 오른쪽 자리(선택).
  final SectionHeaderTrailing? trailing;

  /// 제목의 IA 슬롯 id.
  final String? titleIdentifier;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final trailing = this.trailing;
    final titleText = Semantics(
      identifier: titleIdentifier,
      header: true,
      child: Text(
        title,
        style: tokens.typography.labelLg.copyWith(
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: titleText),
              if (trailing is SectionHeaderActionWidget)
                // 좋아요 같은 위젯은 제 폭을 지킵니다(자르지 않음).
                trailing.child
              else if (trailing is SectionHeaderAction)
                // 터치가 배치 밖으로 넓어지려면 위 상자가 줄이지 않아야 합니다(그림은 24).
                _buildTrailing(context, trailing)
              else if (trailing != null)
                // 오른쪽 자리가 폭 절반을 넘으면 줄바꿈해 제목 자리를 지킵니다.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth / 2,
                  ),
                  child: _buildTrailing(context, trailing),
                ),
            ],
          ),
          if (description != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.s2),
              child: Text(
                description!,
                style: tokens.typography.captionMd.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrailing(BuildContext context, SectionHeaderTrailing trailing) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    return switch (trailing) {
      SectionHeaderLink(:final label, :final onTap) => () {
        final style = tokens.typography.labelMd.copyWith(
          color: colors.actionPrimary,
        );
        return VerticalHitSlop(
          child: PressInkTarget(
            semanticLabel: label,
            link: true,
            onTap: onTap,
            inkColor: colors.actionPrimary,
            borderRadius: BorderRadius.circular(Radii.sm),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: Space.s8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text(label, style: style)),
                  const SizedBox(width: Space.s2),
                  AppIcon(
                    _caretRight,
                    size: AppIconSize.adjacentText(style.fontSize ?? 13),
                    color: colors.actionPrimary,
                    scalesWithText: true,
                  ),
                ],
              ),
            ),
          ),
        );
      }(),
      SectionHeaderAction(
        :final icon,
        :final semanticLabel,
        :final onTap,
        :final identifier,
      ) =>
        // 그림 24의 오른쪽 끝을 끝선에 맞추고 터치 44는 왼쪽으로만 넓힙니다(오른쪽 밖은 부모 경계).
        VerticalHitSlop(
          minWidth: minTarget,
          widenLeftOnly: true,
          child: PressInkTarget(
            semanticLabel: semanticLabel,
            identifier: identifier,
            onTap: onTap,
            borderRadius: BorderRadius.circular(Radii.full),
            child: AppIcon(icon, color: colors.textPrimary),
          ),
        ),
      SectionHeaderActionWidget(:final child) => child,
    };
  }
}
