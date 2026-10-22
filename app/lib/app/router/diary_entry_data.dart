import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/gen/model/diary_summary.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/design/components/diary/diary_row.dart';

/// 일기 요약 [summary]의 entry 줄 값. 줄을 누르면 그 일기의 `diary-view`입니다(A67).
///
/// 오늘·그날 시트·일기 목록 묶음 카드가 같은 줄 값을 씁니다.
DiaryEntryData diaryEntryDataOf(BuildContext context, DiarySummary summary) =>
    DiaryEntryData(
      createdAt: summary.createdAt,
      excerpt: summary.excerpt,
      onTap: () =>
          context.push<void>(diaryPathOf(ScreenIds.diaryView, summary.id)),
    );

/// [summaries]의 entry 줄 값들(받은 순서 그대로).
List<DiaryEntryData> diaryEntriesDataOf(
  BuildContext context,
  List<DiarySummary> summaries,
) => [for (final summary in summaries) diaryEntryDataOf(context, summary)];
