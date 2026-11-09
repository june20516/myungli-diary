import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';

/// 이미 보고한 사전 빈칸(용어 id: `tag.<키>`, `score_item.<id>`, `day_kind.*`,
/// `relation.*`, `ten_god_group.*` 등). 화면이 달라도 같은 빈칸을 거듭 보고하지 않게
/// 앱 실행 동안 한 번만 보고합니다(A112). 테스트는 새 컨테이너를 쓰거나 이 provider를
/// override해 비웁니다.
final reportedDictionaryGapsProvider = Provider<Set<String>>(
  (ref) => <String>{},
);

/// `ref.read`(`Ref`와 `WidgetRef` 모두)를 그대로 넘기기 위한 읽기 함수 모양.
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// [termIds] 가운데 아직 보고하지 않은 사전 빈칸을 용어 id만 담아 비치명으로 기록합니다
/// (D64, A112). 용어 id의 접두는 가정하지 않고 문자열 그대로 중복을 제거합니다.
///
/// 쓰는 쪽은 `reportDictionaryGaps(ref.read, ids)`처럼 부릅니다.
void reportDictionaryGaps(ProviderReader read, Iterable<String> termIds) {
  final reported = read(reportedDictionaryGapsProvider);
  for (final termId in termIds) {
    if (!reported.add(termId)) continue;
    read(crashReporterProvider).record(
      CrashSummary.from(MissingDictionaryEntry(termId)),
      StackTrace.current,
    );
  }
}
