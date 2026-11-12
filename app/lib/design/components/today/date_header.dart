import 'package:flutter/material.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/components/sentence/vertical_hit_slop.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 날짜 머리(`date-header`, D108, V78): 날짜 줄과 그 아래 음력, 일진, 덕일 한 줄.
///
/// 오늘 화면(`today`)은 날짜, 음력, 일진, 덕일([virtues], 있는 날만)을 보이고 그날 시트
/// (`day-sheet`)는 날짜와 음력만 보입니다. 변형은 호출하는 쪽이 [iljin]과 [virtues]를 주느냐로
/// 정하며, 음력이나 일진이 없으면(server 값이 아직 없을 때) 그 칸만 빼고, 칸이 모두 없으면 줄과
/// 위 여백까지 그리지 않습니다. 칸은 쉼표나 기호 없이 [Space.s8] 간격으로만 나누고, 칸 하나는
/// 끊지 않고 다음 줄로 넘깁니다. 날짜, 음력, 일진은 누를 수 없는 표시입니다.
///
/// 덕일(D124 ⑤, V119)은 일진 뒤에 덕마다 `hanja-tag` `compact` 길 톤(`verdictTone.good`) 알약
/// 하나이고, 받은 순서대로 둡니다(계약 순서 천덕일, 월덕일은 값을 만드는 쪽이 맞춤). 알약은 누르면
/// [DateHeaderVirtue.onTap]이고 터치 높이는 위아래로 넓혀 44입니다. 덕일은 뼈를 두지 않습니다
/// ([skeleton]).
///
/// 알약이 맨 아래 줄이면 아래쪽 넓힘이 날짜 머리 경계 밖으로 나갑니다. 보통 상자는 자기 영역 밖
/// 눌림을 넘기지 않으므로, 날짜 머리를 감싸는 상자(예: slot 표시 `Semantics`, `SizedBox`)가
/// 아래 경계를 자르면 그 상자를 `HitSlopPassage(bottom: DateHeader.virtueHitSlop)`로 감쌉니다
/// (오늘 화면이 그렇게 함).
///
/// 그날 시트는 오른쪽 끝에 날의 성격 태그([trailing])를 둡니다(`parts.trailing`, V109).
/// 태그는 날짜와 음력 두 줄 묶음의 세로 가운데(음력이 없으면 날짜 줄 가운데)에 날짜 글자와
/// [trailingGap] 이상 떨어져 놓이고, 큰 글자 배율로 한 줄에 들어가지 않으면 날짜 머리 아래
/// [trailingGap]의 왼쪽 줄로 내려갑니다.
///
/// 스크린리더는 날짜, 음력, 일진을 한 덩어리로 읽고, 일진은 한글 독음만 읽습니다(한자는
/// 읽지 않음, 예: 경신일). 덕일 알약과 [trailing]은 그 뒤에 따로 초점이 가는 항목입니다.
class DateHeader extends StatelessWidget {
  /// 날짜 머리를 만듭니다.
  ///
  /// [solar]는 날짜와 요일 글자, [lunar]는 음력 글자, [iljin]은 한자를 품은 일진 글자
  /// (예: `癸未(계미)일`)이며 한자는 `font.family.hanja`로 그립니다. [trailing]은 그날
  /// 시트의 날의 성격 태그입니다. [virtues]는 오늘 화면의 덕일 알약(그릴 순서)입니다.
  const new({
    required this.solar,
    this.lunar,
    this.iljin,
    this.virtues = const [],
    this.trailing,
    super.key,
  });

  /// 명세 대조용 요약.
  static const ComponentSpec spec = ComponentSpec(
    'date-header',
    {'today', 'day-sheet'},
    {'loading'},
  );

  /// 날짜 줄 아래 음력, 일진 줄까지의 간격(`parts.meta.marginTop` `space.2`).
  static const double metaGap = Space.s2;

  /// 날짜 글자와 [trailing] 사이 최소 간격이자, 아래 줄로 내렸을 때의 위 간격
  /// (`variants.day-sheet.parts.trailing.gapStart` `space.12`).
  static const double trailingGap = Space.s12;

  /// 날짜와 음력(일진) 묶음을 찾는 테스트용 키.
  static const Key datesKey = ValueKey('date-header-dates');

  /// 뼈 폭 비율(`states.loading.skeleton` `width` 50%).
  static const double skeletonWidthFactor = 0.5;

  /// 음력과 일진 줄을 찾는 테스트용 키.
  static const Key metaKey = ValueKey('date-header-meta');

  /// 일진 글자를 찾는 테스트용 키.
  static const Key iljinKey = ValueKey('date-header-iljin');

  /// 덕일 알약이 meta 줄 경계 밖으로 넓히는 눌림 높이(위아래 하나씩). 알약 높이
  /// [HanjaTag.compactHeight]에서 터치 높이 [sentenceMinTarget]까지의 반입니다.
  static const double virtueHitSlop =
      (sentenceMinTarget - HanjaTag.compactHeight) / 2;

  /// 불러오는 중: 날짜 줄은 기기 날짜라 [solar]를 바로 그리고, server 값인 음력과 일진 줄만
  /// 뼈(한 줄, 50%)로 둡니다. [solar]를 주지 않으면 날짜 줄도 같은 높이 뼈입니다.
  ///
  /// [trailing]을 주면(그날 시트의 날의 성격 뼈) 본문과 같은 자리에 둡니다.
  static Widget skeleton({
    String? solar,
    Widget? trailing,
    int index = 0,
    bool animated = true,
  }) => Builder(
    builder: (context) {
      final typography = context.tokens.typography;
      final colors = context.tokens.colors;
      final dates = Column(
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
      return trailing == null ? dates : _withTrailing(dates, trailing);
    },
  );

  /// [dates] 오른쪽 끝에 [trailing]을 세로 가운데로 두고, 한 줄에 들어가지 않으면 아래
  /// [trailingGap]의 왼쪽 줄로 내립니다.
  static Widget _withTrailing(Widget dates, Widget trailing) => SizedBox(
    width: double.infinity,
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: trailingGap,
      runSpacing: trailingGap,
      children: [dates, trailing],
    ),
  );

  /// 날짜와 요일.
  final String solar;

  /// 음력. 없으면 그 칸만 뺍니다.
  final String? lunar;

  /// 한자를 품은 일진. 없으면(그날 시트) 그 칸만 뺍니다.
  final String? iljin;

  /// 덕일 알약(오늘 화면, 그릴 순서). 비면 칸째 없습니다.
  final List<DateHeaderVirtue> virtues;

  /// 오른쪽 끝 날의 성격 태그(그날 시트). 없으면 날짜 묶음만입니다.
  final Widget? trailing;

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
    final hasVirtues = virtues.isNotEmpty;
    final hasMeta = lunar != null || iljin != null || hasVirtues;
    final metaStyle = tokens.typography.captionLg.copyWith(
      color: colors.textSecondary,
    );
    final spoken = [solar, ?lunar, if (iljin != null) spokenIljinOf(iljin)];
    Widget meta = Wrap(
      key: metaKey,
      spacing: Space.s8,
      // 알약(22)이 글줄보다 높아 줄 높이가 22가 되고, 글자는 그 가운데입니다.
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (lunar != null)
          ExcludeSemantics(child: Text(lunar, style: metaStyle)),
        if (iljin != null)
          ExcludeSemantics(
            child: Text.rich(
              key: iljinKey,
              TextSpan(
                style: metaStyle,
                children: hanjaSpansOf(
                  iljin,
                  metaStyle.copyWith(
                    fontFamily: tokens.typography.hanjaPillar.fontFamily,
                    fontFamilyFallback:
                        tokens.typography.hanjaPillar.fontFamilyFallback,
                  ),
                ),
              ),
            ),
          ),
        for (final virtue in virtues)
          HanjaTag(
            glyph: virtue.glyph,
            label: virtue.label,
            tone: HanjaTagTone.good,
            size: HanjaTagSize.compact,
            variant: virtue.selected
                ? HanjaTagVariant.selected
                : HanjaTagVariant.normal,
            onTap: virtue.onTap,
          ),
      ],
    );
    if (hasVirtues) {
      // 알약의 위쪽 넓힘이 줄 경계에서 막히지 않게 합니다(위는 날짜 줄 자리).
      meta = HitSlopPassage(top: virtueHitSlop, child: meta);
    }
    // 머리 덩어리 하나(header)가 날짜, 음력, 일진을 읽고, 덕일 알약은 그 안의 따로 초점이 가는
    // 버튼이라 덩어리 뒤에 읽힙니다(`a11y.virtueLabel`).
    Widget dates = Semantics(
      key: datesKey,
      container: true,
      header: true,
      label: spoken.join(', '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Text(
              solar,
              style: tokens.typography.subtitle.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
          if (hasMeta) ...[const SizedBox(height: metaGap), meta],
        ],
      ),
    );
    if (hasVirtues) {
      // 알약이 맨 아래 줄이면 아래쪽 넓힘이 머리 경계에서 막히지 않게 합니다.
      dates = HitSlopPassage(bottom: virtueHitSlop, child: dates);
    }
    final trailing = this.trailing;
    return trailing == null ? dates : _withTrailing(dates, trailing);
  }
}

/// 날짜 머리 덕일 알약 하나(`parts.virtue`, `hanja-tag` `compact` 길 톤).
@immutable
final class DateHeaderVirtue {
  /// 덕일 알약 값을 만듭니다.
  const new({
    required this.glyph,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  /// 원 안 한자(`glyphs.virtueDay`의 德).
  final String glyph;

  /// 덕 이름(ARB `todayDateVirtueCheondeok`, `todayDateVirtueWoldeok`).
  /// 스크린리더 이름입니다.
  final String label;

  /// 그 덕의 풀이 시트가 열린 동안 true(`selected` 테두리).
  final bool selected;

  /// 눌렀을 때(그 덕의 `explain-sheet`). null이면 누를 수 없는 표시입니다.
  final VoidCallback? onTap;
}
