import 'package:flutter/material.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 날짜 머리(`date-header`, D108, V78): 날짜 줄과 그 아래 음력, 일진 한 줄.
///
/// 오늘 화면(`today`)은 날짜, 음력, 일진을 모두 보이고 그날 시트(`day-sheet`)는 날짜와 음력만
/// 보입니다. 변형은 호출하는 쪽이 [iljin]을 주느냐로 정하며, 음력이나 일진이 없으면(server
/// 값이 아직 없을 때) 그 칸만 빼고, 두 칸이 모두 없으면 줄과 위 여백까지 그리지 않습니다.
/// 두 칸은 쉼표나 기호 없이 [Space.s8] 간격으로만 나누고, 칸 하나는 끊지 않고 다음 줄로
/// 넘깁니다. 누를 수 없는 표시라 눌림이 없습니다.
///
/// 스크린리더는 날짜, 음력, 일진을 한 덩어리로 읽고, 일진은 한글 독음만 읽습니다(한자는
/// 읽지 않음, 예: 경신일).
class DateHeader extends StatelessWidget {
  /// 날짜 머리를 만듭니다.
  ///
  /// [solar]는 날짜와 요일 글자, [lunar]는 음력 글자, [iljin]은 한자를 품은 일진 글자
  /// (예: `癸未(계미)일`)이며 한자는 `font.family.hanja`로 그립니다.
  const new({required this.solar, this.lunar, this.iljin, super.key});

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'date-header',
    {'today', 'day-sheet'},
    {'loading'},
  );

  /// 날짜 줄 아래 음력, 일진 줄까지의 간격(`parts.meta.marginTop` `space.2`).
  static const double metaGap = Space.s2;

  /// 뼈 폭 비율(`states.loading.skeleton` `width` 50%).
  static const double skeletonWidthFactor = 0.5;

  /// 음력과 일진 줄을 찾는 테스트용 키.
  static const Key metaKey = ValueKey('date-header-meta');

  /// 일진 글자를 찾는 테스트용 키.
  static const Key iljinKey = ValueKey('date-header-iljin');

  /// 불러오는 중: 날짜 줄은 기기 날짜라 [solar]를 바로 그리고, server 값인 음력과 일진 줄만
  /// 뼈(한 줄, 50%)로 둡니다. [solar]를 주지 않으면 날짜 줄도 같은 높이 뼈입니다.
  static Widget skeleton({
    String? solar,
    int index = 0,
    bool animated = true,
  }) => Builder(
    builder: (context) {
      final typography = context.tokens.typography;
      final colors = context.tokens.colors;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (solar != null)
            Text(
              solar,
              style: typography.subtitle.copyWith(color: colors.textPrimary),
            )
          else
            SkeletonTextLines(
              style: typography.subtitle,
              widthFactor: skeletonWidthFactor,
              index: index,
              animated: animated,
            ),
          const SizedBox(height: metaGap),
          SkeletonTextLines(
            style: typography.captionLg,
            widthFactor: skeletonWidthFactor,
            index: index + 1,
            animated: animated,
          ),
        ],
      );
    },
  );

  /// 날짜와 요일.
  final String solar;

  /// 음력. 없으면 그 칸만 뺍니다.
  final String? lunar;

  /// 한자를 품은 일진. 없으면(그날 시트) 그 칸만 뺍니다.
  final String? iljin;

  static final RegExp _hanjaRun = RegExp(
    '[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]+',
  );

  /// [text]에서 한자 덩어리를 `font.family.hanja`로 바꾼 조각을 만듭니다.
  static List<InlineSpan> hanjaSpansOf(String text, TextStyle hanjaStyle) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _hanjaRun.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      spans.add(TextSpan(text: match.group(0), style: hanjaStyle));
      cursor = match.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return spans;
  }

  /// 스크린리더가 읽는 일진: 한자와 괄호를 빼고 한글 독음만 남깁니다(`癸未(계미)일` → `계미일`).
  static String spokenIljinOf(String iljin) =>
      iljin.replaceAll(_hanjaRun, '').replaceAll(RegExp('[()]'), '').trim();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final lunar = this.lunar;
    final iljin = this.iljin;
    final hasMeta = lunar != null || iljin != null;
    final metaStyle = tokens.typography.captionLg.copyWith(
      color: colors.textSecondary,
    );
    final spoken = [solar, ?lunar, if (iljin != null) spokenIljinOf(iljin)];
    return Semantics(
      container: true,
      header: true,
      label: spoken.join(', '),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              solar,
              style: tokens.typography.subtitle.copyWith(
                color: colors.textPrimary,
              ),
            ),
            if (hasMeta) ...[
              const SizedBox(height: metaGap),
              Wrap(
                key: metaKey,
                spacing: Space.s8,
                children: [
                  if (lunar != null) Text(lunar, style: metaStyle),
                  if (iljin != null)
                    Text.rich(
                      key: iljinKey,
                      TextSpan(
                        style: metaStyle,
                        children: hanjaSpansOf(
                          iljin,
                          metaStyle.copyWith(
                            fontFamily:
                                tokens.typography.hanjaPillar.fontFamily,
                            fontFamilyFallback: tokens
                                .typography
                                .hanjaPillar
                                .fontFamilyFallback,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
