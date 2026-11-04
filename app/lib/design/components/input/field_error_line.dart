import 'package:flutter/material.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 칸 오류 줄. 빨간색 없이 경고 표시(`mark.caution`) + `type.caption.lg` 본문색 글자입니다.
///
/// `input-step` 오류 줄과 `text-field` `errorLine`(3.4.0)이 같은 모양을 씁니다(앱 안 오류 표시를
/// 하나로 둠). 두 줄까지입니다.
class FieldErrorLine extends StatelessWidget {
  /// [text] 오류 줄을 만듭니다.
  const new({required this.text, super.key});

  /// 오류 문구.
  final String text;

  /// 오류 줄 최대 줄 수.
  static const int maxLines = 2;

  @override
  Widget build(BuildContext context) {
    final style = context.tokens.typography.captionLg.copyWith(
      color: context.tokens.colors.textPrimary,
    );
    // 경고 표시는 주변 글자 크기와 색(DefaultTextStyle)을 따르고, 첫 줄 높이에 맞춰 놓습니다.
    final lineHeight =
        MediaQuery.textScalerOf(context).scale(style.fontSize!) *
        (style.height ?? 1);
    return DefaultTextStyle(
      style: style,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: lineHeight,
            child: const Center(child: AppIcon.caution()),
          ),
          const SizedBox(width: Space.s8),
          Expanded(child: Text(text, maxLines: maxLines)),
        ],
      ),
    );
  }
}
