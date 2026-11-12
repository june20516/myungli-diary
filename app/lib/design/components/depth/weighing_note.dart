import 'package:flutter/material.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/text/line_height.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

/// 흉한 신살 마무리 한 줄(`explain-sheet` `weighingNote`, D124 ⑦, 결정 V120).
///
/// 뜻 바로 아래 [marginTop]에 뉴트럴 상자(`fill.soft`, `radius.md`, 안쪽 `space.12`)를 두고,
/// 앞에 `check` Regular(옆 글자 단계, `action.primary`, 첫 줄 글줄 가운데, 간격 `space.8`)와
/// 글자(`type.caption.lg` `text.secondary`)를 둡니다. 글자는 자르지 않고 줄바꿈으로 모두
/// 보입니다(writing `ui.shinsal.weighing` `a11y.truncation` "잘리지 않게"). 누를 수 없고
/// 잠기지 않으며, 아이콘은 장식이라 스크린리더는 글자만 읽습니다. 어느 시트에 둘지는 놓는 쪽이 정합니다
/// (풀이 시트와 사주 기운 시트의 뜻 아래만, 근거 시트와 원국 개인 해석에는 두지 않음).
class WeighingNote extends StatelessWidget {
  /// [text](원고 `shinsalWeighingNote`)를 담은 마무리 상자를 만듭니다.
  const new({required this.text, super.key});

  /// 뜻과 상자 사이. 계약 `weighingNote.marginTop`(`space.12`).
  static const double marginTop = Space.s12;

  /// 상자 안쪽 여백. 계약 `weighingNote.box.padding`(`space.12`).
  static const double padding = Space.s12;

  /// 상자 모서리. 계약 `weighingNote.box.radius`(`radius.md`).
  static const double radius = Radii.md;

  /// 아이콘과 글자 사이. 계약 `weighingNote.icon.gap`(`space.8`).
  static const double iconGap = Space.s8;

  /// 계약 `weighingNote.text.maxLines`. 배율 1.0에서 원고 글자 수 상한을 잰 줄 수이고
  /// (`lengths.md` `ui.shinsal.weighing`), 그리기는 줄 수를 막지 않습니다. 큰 글자 배율에서는
  /// 줄이 늘어나 문장 끝까지 보입니다(A137 ④, design 확인 #1072).
  static const int maxLines = 2;

  /// 앞 아이콘. 계약 `weighingNote.icon`(`check`, `regular`).
  static const AppGlyph glyph = AppGlyph(
    light: PhosphorIconsLight.check,
    regular: PhosphorIconsRegular.check,
  );

  /// 아이콘 굵기. 계약 `weighingNote.icon.weight`.
  static const AppIconWeight iconWeight = AppIconWeight.regular;

  /// 상자를 찾는 테스트용 키. IA 밖 슬롯(`ui.shinsal.weighing`)이라 IA id가 없습니다.
  static const Key boxKey = ValueKey('explain-sheet-weighing-note');

  /// 마무리 문장.
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final style = tokens.typography.captionLg.copyWith(
      color: tokens.colors.textSecondary,
    );
    final lineHeight = lineHeightOf(style, MediaQuery.textScalerOf(context));
    return Padding(
      padding: const EdgeInsets.only(top: marginTop),
      child: DecoratedBox(
        key: boxKey,
        decoration: BoxDecoration(
          color: tokens.colors.fillSoft,
          borderRadius: const BorderRadius.all(Radius.circular(radius)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(padding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: iconGap,
            children: [
              // 첫 줄 글줄 높이 안에서 가운데에 둡니다.
              ExcludeSemantics(
                child: SizedBox(
                  height: lineHeight,
                  child: Center(
                    widthFactor: 1,
                    child: AppIcon(
                      glyph,
                      size: AppIconSize.adjacentText(style.fontSize ?? 13),
                      weight: iconWeight,
                      color: tokens.colors.actionPrimary,
                      scalesWithText: true,
                    ),
                  ),
                ),
              ),
              Expanded(child: Text(text, style: style)),
            ],
          ),
        ),
      ),
    );
  }
}
