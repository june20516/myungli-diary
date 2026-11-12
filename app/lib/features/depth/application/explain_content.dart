import 'package:flutter/widgets.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/depth/application/term_origin.dart';

/// 풀이 시트(`explain-sheet`)가 보여 줄 내용. 시트를 여는 쪽이 무엇을 풀이할지만 고르고,
/// 그리는 방식은 시트가 정합니다(결정 V62, V71).
sealed class ExplainContent {
  const new();
}

/// 사전의 용어 뜻(`term-token` 풀이). 제목은 용어 이름(`type.title`), 한자와 뜻은 사전에서,
/// 오늘 그런 이유와 근거 진입점은 [origin]이 있을 때만 붙습니다.
final class ExplainTerm extends ExplainContent {
  /// [termId] 용어의 풀이.
  const new(this.termId, {this.origin, this.evidenceSubject});

  /// 용어 id(`<범주>.<값>`).
  final String termId;

  /// 용어가 눌린 슬롯과 그 응답. null이면 근거 진입점도 오늘 그런 이유도 없습니다.
  final TermOrigin? origin;

  /// 근거 진입점 아이콘의 스크린리더 항목 이름. null이면 용어 이름입니다.
  final String? evidenceSubject;
}

/// 사전이 아닌 UI 문구 풀이(12운성 띠 머리 칩의 설명 등). 제목은 `type.subtitle`입니다.
final class ExplainUiText extends ExplainContent {
  /// [title] 아래에 [body]를 보이고, [attachment]가 있으면 본문 아래 `space.12`에 붙입니다.
  const new({required this.title, required this.body, this.attachment});

  /// 시트 제목(누른 항목의 이름).
  final String title;

  /// 설명 문구(ARB 문구).
  final String body;

  /// 본문 아래에 붙일 위젯(`stage-strip` 등).
  final Widget? attachment;
}

/// 행운 칩(`lucky-card`)의 설명. 제목은 `type.subtitle`입니다.
final class ExplainLucky extends ExplainContent {
  /// [title] 아래에 [body] 문장을 보입니다. [attachment]가 있으면 본문 아래 [attachmentGap]에
  /// 붙이고, [origin]이 있으면 맨 끝에 그 카드의 근거 진입점을 둡니다(`explain.evidenceLink`, V118).
  const new({
    required this.title,
    required this.body,
    this.attachment,
    this.attachmentGap = Space.s12,
    this.origin,
  });

  /// 시트 제목(칩 이름).
  final String title;

  /// 설명 문장(콘텐츠 문장, 용어 조각 포함 가능).
  final RenderedText body;

  /// 본문 아래에 붙일 위젯(시간 시트의 24시간 띠 `timeBand`).
  final Widget? attachment;

  /// 본문과 [attachment] 사이.
  final double attachmentGap;

  /// 근거 진입점이 열 카드 문장과 그 응답. null이면 근거 진입점이 없습니다(방향, 숫자 시트).
  final TermOrigin? origin;
}

/// 색이 둘인 날 행운 색 시트(`lucky-card` `colorPairSheet`, D119 ②, D123, V114)의
/// 내용. 알약의 어느 칸을 눌러도 이 내용 하나입니다. 제목은 항목 이름(행운 색), 그 아래
/// [intro] 한 줄, 그리고 색마다 구역([sections], 첫째 색 다음 둘째 색)이 구분선 사이로
/// 이어집니다.
final class ExplainLuckyColorPair extends ExplainContent {
  /// [title] 아래 [intro]와 [sections]를 보입니다.
  const new({required this.title, required this.intro, required this.sections});

  /// 시트 제목(항목 이름 "행운 색").
  final String title;

  /// 추천 색이 둘이라는 한 줄(`todayLuckyColorPairIntro`).
  final String intro;

  /// 색마다 구역(첫째 색, 둘째 색 순서).
  final List<ExplainColorSection> sections;
}

/// 색이 둘인 날 행운 색 시트의 색 하나(`colorPairSheet.section`).
@immutable
final class ExplainColorSection {
  /// 색 하나의 구역을 만듭니다.
  const new({
    required this.element,
    required this.name,
    required this.body,
    required this.bodySlotId,
    required this.origin,
  });

  /// 견본 색의 오행.
  final FiveElement element;

  /// 색 이름(머리 글자이자 근거 진입점의 항목 이름).
  final String name;

  /// 그 색 카드의 풀이 문장.
  final RenderedText body;

  /// [body]가 채우는 IA 슬롯(`today.lucky-color.body`,
  /// `today.lucky-color.second.body`).
  final String bodySlotId;

  /// 그 색 카드 문장의 근거 출처(카드 id, A134). 근거 진입점이 이 근거를 엽니다(D123 ②).
  final TermOrigin origin;
}
