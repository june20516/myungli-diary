import 'package:flutter/material.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/today/date_header.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 큰 날짜 블록(`date-block`, 일기 쓰기 맨 위, V82).
///
/// 일 숫자를 크게(44 700 고정폭) 두고, 옆 `space.12`에 두 줄 묶음: 월과 요일
/// (`type.label.lg`), 그 아래 `space.2`에 일진(`type.caption.md`
/// `text.secondary`, 한자는 `font.family.hanja`). 두 줄 묶음은 숫자와 세로
/// 가운데입니다. 누를 수 없는 표시이고, 스크린리더는 머리 하나로 "월 일 요일,
/// 일진 독음"을 읽습니다(한자는 읽지 않음).
class DateBlock extends StatelessWidget {
  /// 날짜 블록을 만듭니다.
  ///
  /// [day]는 일 숫자 글자(`diary-edit.date.day`), [monthWeekday]는 월과 요일 글자
  /// (`diary-edit.date.month`)이고 둘 다 기기 값이라 늘 보입니다. [iljin]은 한자를 품은 일진
  /// 글자(`diary-edit.date.iljin`, 예 `癸未(계미)일`)이고 없으면 그 줄을 그리지 않습니다.
  /// [iljinLoading]이면 일진 자리에 글줄 뼈 하나(64)를 둡니다.
  const new({
    required this.day,
    required this.monthWeekday,
    this.iljin,
    this.iljinLoading = false,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec('date-block', {}, {
    'loading',
  });

  /// 일 숫자 크기. 계약 `diary.json` `date-block.parts.day.fontSize`.
  static const double dayFontSize = 44;

  /// 일진 뼈 폭. 계약 `date-block.states.loading.skeleton` `iljin.width`.
  static const double iljinSkeletonWidth = 64;

  /// 숫자와 두 줄 묶음 사이(`parts.container.gap`).
  static const double gap = Space.s12;

  /// 월과 요일 아래 일진까지(`parts.iljin.marginTop`).
  static const double iljinGap = Space.s2;

  /// 일진 글자를 찾는 테스트용 키.
  static const Key iljinKey = ValueKey('date-block-iljin');

  /// 일 숫자 글자.
  final String day;

  /// 월과 요일 글자.
  final String monthWeekday;

  /// 한자를 품은 일진 글자. 없으면 그 줄을 그리지 않습니다.
  final String? iljin;

  /// 일진을 불러오는 중인지.
  final bool iljinLoading;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = tokens.colors;
    final typography = tokens.typography;
    final iljin = this.iljin;
    final iljinStyle = typography.captionMd.copyWith(
      color: colors.textSecondary,
    );
    final spoken = [
      '$monthWeekday $day',
      if (iljin != null) DateHeader.spokenIljinOf(iljin),
    ];
    return Semantics(
      container: true,
      header: true,
      label: spoken.join(', '),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              day,
              style: TextStyle(
                fontFamily: typography.bodyUi.fontFamily,
                fontFamilyFallback: typography.bodyUi.fontFamilyFallback,
                fontSize: dayFontSize,
                fontWeight: FontWeight.w700,
                height: 1,
                color: colors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: gap),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    monthWeekday,
                    style: typography.labelLg.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  if (iljin != null) ...[
                    const SizedBox(height: iljinGap),
                    Text.rich(
                      key: iljinKey,
                      TextSpan(
                        style: iljinStyle,
                        children: DateHeader.hanjaSpansOf(
                          iljin,
                          iljinStyle.copyWith(
                            fontFamily: typography.hanjaPillar.fontFamily,
                            fontFamilyFallback:
                                typography.hanjaPillar.fontFamilyFallback,
                          ),
                        ),
                      ),
                    ),
                  ] else if (iljinLoading) ...[
                    const SizedBox(height: iljinGap),
                    SizedBox(
                      width: iljinSkeletonWidth,
                      child: SkeletonTextLines(
                        style: typography.captionMd,
                        widthFactor: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
