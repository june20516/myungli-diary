import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:myungli_diary/features/diary/application/diary_summary_rows.dart';
import 'package:myungli_diary/features/diary/presentation/diary_page_list.dart';

/// 일기 줄 builder(`diary/application`)에 실제 줄([DiarySummaryRow])을 연결하는 override.
///
/// 오늘 화면과 그날 시트가 일기 줄을 그리므로, 그날 시트 본문과 같은 이유로 조립 지점인 app이
/// 잇습니다(spec §2).
final List<Override> diarySummaryRowOverrides = [
  diarySummaryRowProvider.overrideWithValue(
    (summary, {required isLast}) =>
        DiarySummaryRow(summary: summary, isLast: isLast),
  ),
];
