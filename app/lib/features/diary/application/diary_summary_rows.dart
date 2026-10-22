import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/gen/model/diary_summary.dart';

/// 일기 한 편의 줄(`diary-row`)을 만드는 함수. [isLast]면 묶음의 마지막 줄이고, [tagLinked]가
/// false면 대표 태그 칩을 누를 수 없는 표시입니다.
typedef DiarySummaryRowBuilder = Widget Function(
  DiarySummary summary, {
  required bool isLast,
  required bool tagLinked,
});

/// 다른 feature(오늘·그날 시트)가 그날 쓴 일기 줄을 그릴 때 쓰는 builder(A69).
///
/// 기본값은 실패이고(조용히 빈 줄이 되지 않게) 조합 계층(`lib/app/diary_summary_rows.dart`)이
/// override로 실제 줄을 연결합니다(feature presentation끼리 import하지 않기 위해, spec §2).
final diarySummaryRowProvider = Provider<DiarySummaryRowBuilder>(
  (ref) =>
      (_, {required isLast, required tagLinked}) =>
          throw UnimplementedError('diarySummaryRowOverrides를 연결하세요'),
);
