import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';

/// 이미 보고한 점수 항목 사전 빈칸(용어 id). 화면을 다시 그려도 같은 빈칸을 거듭 보고하지 않게
/// 앱 실행 동안 한 번만 보고합니다(A112).
final reportedScoreItemGapsProvider = Provider<Set<String>>(
  (ref) => <String>{},
);

/// [termIds] 가운데 아직 보고하지 않은 사전 빈칸을 비치명으로 기록합니다.
void reportScoreItemGaps(WidgetRef ref, Iterable<String> termIds) {
  final reported = ref.read(reportedScoreItemGapsProvider);
  for (final termId in termIds) {
    if (!reported.add(termId)) continue;
    ref
        .read(crashReporterProvider)
        .record(
          CrashSummary.from(MissingDictionaryEntry(termId)),
          StackTrace.current,
        );
  }
}
