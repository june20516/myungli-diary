import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:myungli_diary/features/calendar/application/day_sheets.dart';
import 'package:myungli_diary/features/calendar/presentation/day_sheet_body.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/depth/presentation/evidence_sheet.dart';
import 'package:myungli_diary/features/depth/presentation/explain_sheet.dart';
import 'package:myungli_diary/features/depth/presentation/share_preview_sheet.dart';

/// 깊이 시트(풀이·근거·공유 미리보기) 본문을 시트 서비스(`depth/application`)에 연결하는 override.
///
/// 서비스가 시트 화면(presentation)을 알지 않도록 조립 지점인 app이 잇습니다(spec §2,
/// `profileTimezoneOverrides`와 같은 방식).
final List<Override> depthSheetBodyOverrides = [
  explainBodyProvider.overrideWithValue(
    (termId, sourceSlotId) =>
        ExplainSheet(termId: termId, sourceSlotId: sourceSlotId),
  ),
  evidenceBodyProvider.overrideWithValue(
    (slotId) => EvidenceSheet(slotId: slotId),
  ),
  shareBodyProvider.overrideWithValue(SharePreviewSheet.new),
];

/// 그날 시트(`day-sheet`) 본문을 시트 서비스(`calendar/application`)에 연결하는 override.
///
/// 오늘 화면(today)도 그날 시트를 열므로, 깊이 시트와 같은 이유로 조립 지점인 app이 잇습니다.
final List<Override> daySheetBodyOverrides = [
  daySheetBodyProvider.overrideWithValue((date) => DaySheetBody(date: date)),
];
