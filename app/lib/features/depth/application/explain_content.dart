import 'package:flutter/widgets.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
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
  /// [title] 아래에 [body] 문장을 보입니다.
  const new({required this.title, required this.body});

  /// 시트 제목(칩 이름).
  final String title;

  /// 설명 문장(콘텐츠 문장, 용어 조각 포함 가능).
  final RenderedText body;
}
