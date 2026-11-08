import 'package:flutter/foundation.dart';

/// 색 규칙 시트 점수 항목 표의 한 줄: 항목 id와 점수(엔진 spec §8 점수표).
@immutable
final class ScoreRuleRow {
  /// [id] 항목의 [score]를 담습니다.
  const new(this.id, this.score);

  /// 점수 항목 id(용어 사전 `score_item` 값, 한자 글자표 키).
  final String id;

  /// 더하거나 뺀 점수(0이 아님).
  final int score;
}

/// 점수 항목 상수.
abstract final class ScoreItemMeta {
  /// 용어 사전 범주 이름. 항목 이름은 `Glossary.values['score_item'][id]`입니다.
  static const String glossaryCategory = 'score_item';

  /// 색 규칙 시트의 일곱 줄(A116). 더함 먼저, 뺌 다음의 표 순서이고 점수 0 항목은 없습니다.
  static const List<ScoreRuleRow> rule = [
    ScoreRuleRow('yongsin_day', 2),
    ScoreRuleRow('gwiin_day', 2),
    ScoreRuleRow('hap', 1),
    ScoreRuleRow('gisin_day', -1),
    ScoreRuleRow('chung_day_or_month', -2),
    ScoreRuleRow('chung_other', -1),
    ScoreRuleRow('hyeong', -1),
  ];
}
