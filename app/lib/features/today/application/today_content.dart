import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderFamily;
import 'package:myungli_diary/core/api/gen/model/daily.dart';
import 'package:myungli_diary/core/api/gen/model/diary_summary.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/features/diary/application/diary_providers.dart';
import 'package:myungli_diary/features/glossary/application/dictionary_gaps.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';
import 'package:myungli_diary/features/today/application/today_presentation.dart';

/// 오늘 화면이 그리는 데 필요한 값 묶음.
final class TodayContent {
  /// 오늘 응답 [view], 이름 사전 [names], 오늘 쓴 일기 [diaries]입니다.
  const new({required this.view, required this.names, required this.diaries});

  /// 오늘 응답과 캐시 여부.
  final DailyView view;

  /// 값 이름 사전.
  final GlossaryNames names;

  /// 오늘 쓴 일기 요약(server 순서, 같은 날은 작성 순). 받지 못했으면 빈 목록입니다.
  final List<DiarySummary> diaries;
}

/// 값이 없고 다시 받는 중도 아닌 실패인지.
bool _failed(AsyncValue<Object?> value) =>
    !value.hasValue && value.hasError && !value.isLoading;

/// 세 비동기 값을 오늘 화면 한 값으로 묶습니다.
///
/// * 오늘 응답과 이름 사전이 모두 있어야 그립니다(결정 A27). 오늘 일기 목록도 기다려, 처음부터
///   쓴 날이면 도장이 찍히는 움직임 없이 `after`로 그립니다(실패하면 빈 목록이라 늘 끝납니다,
///   A69).
/// * 응답 날짜가 [today]와 다르면(화면을 연 채 자정을 넘겨 다시 받는 중) 어제 풀이를 오늘로
///   보이지 않고 불러오는 중으로 둡니다(spec §4.5). 다시 받기가 실패했으면 오류입니다.
/// * 값이 생긴 뒤의 갱신·오류 표시(오프라인 배너 등)는 오늘 응답의 상태를 그대로 따릅니다.
AsyncValue<TodayContent> todayContentOf({
  required CalendarDate today,
  required AsyncValue<DailyView> daily,
  required AsyncValue<GlossaryNames> glossary,
  required AsyncValue<List<DiarySummary>> diaries,
}) {
  final view = daily.value;
  if (view != null && view.date != today) {
    if (daily.hasError && !daily.isLoading) {
      return AsyncError(daily.error!, daily.stackTrace ?? StackTrace.empty);
    }
    return const AsyncLoading();
  }
  if (_failed(daily)) {
    return AsyncError(daily.error!, daily.stackTrace ?? StackTrace.empty);
  }
  if (_failed(glossary)) {
    return AsyncError(glossary.error!, glossary.stackTrace ?? StackTrace.empty);
  }
  final names = glossary.value;
  final written = diaries.value;
  if (names == null || written == null) {
    return const AsyncLoading();
  }
  return daily.whenData(
    (view) => TodayContent(view: view, names: names, diaries: written),
  );
}

/// 오늘 화면 값. 오늘 응답·이름 사전·오늘 쓴 일기·"오늘"을 한 곳에서 묶습니다.
///
/// 값이 생기면 사전이나 한자 글자표에 없어 그리지 못한 대표 태그와 이름 없는 십성 묶음을
/// 보고합니다([todayDictionaryGapsOf], 같은 빈칸은 앱 실행 동안 한 번).
final todayContentProvider = Provider<AsyncValue<TodayContent>>((ref) {
  final today = ref.watch(todayProvider);
  final content = todayContentOf(
    today: today,
    daily: ref.watch(dailyControllerProvider),
    glossary: ref.watch(glossaryProvider),
    diaries: ref.watch(diariesOnProvider(today)),
  );
  final value = content.value;
  if (value != null) {
    _reportUnnamedTags(ref, value);
  }
  return content;
});

/// 오늘 화면이 그리지 못한 용어 id(`<범주>.<값>`): 대표 태그([skippedFeaturedTagKeysOf])와
/// 사전에 이름이 없는 십성 묶음(`ten_god_group.<값>`).
List<String> todayDictionaryGapsOf(Daily daily, GlossaryNames names) {
  final group = daily.dayStemTenGodGroup;
  return [
    for (final key in skippedFeaturedTagKeysOf(daily, names)) 'tag.$key',
    if (group != null && names.valueName('ten_god_group', group.value) == null)
      'ten_god_group.${group.value}',
  ];
}

/// [content]에서 그리지 못한 용어를 용어 id만 담아 보고합니다(D64, A112).
void _reportUnnamedTags(Ref ref, TodayContent content) {
  reportDictionaryGaps(
    ref.read,
    todayDictionaryGapsOf(content.view.daily, content.names),
  );
}

/// 프로필 시간대 벽시계의 지금 분([nowMinuteProvider], 시와 분만 읽음). 분 흐름의 첫 값이 오기
/// 전에는 시계에서 바로 읽어, 오늘 화면 첫 그림부터 밤 칩과 띠가 맞습니다.
///
/// 시간 칩 시트의 24시간 띠가 이 값으로 지금 줄을 1분마다 옮깁니다(`timeBand.now.update`).
final todayWallMinuteProvider = Provider<DateTime>((ref) {
  final ticked = ref.watch(nowMinuteProvider).value;
  if (ticked != null) return ticked;
  final local = localTimeIn(
    ref.watch(clockProvider).nowUtc(),
    ref.watch(profileTimezoneProvider),
  );
  return DateTime.utc(
    local.year,
    local.month,
    local.day,
    local.hour,
    local.minute,
  );
});

/// 지금이 낮 구간 시작 순간 [dayStart]([dayStartOf], 그날 진시 시작, #1064) 전인지
/// ([isBeforeDayStart]). 경계를 지날 때만 값이 바뀌어 오늘 화면이 그때 밤 칩 값과 때 낱말을 함께
/// 바꿉니다(D122 ⑦, V116). 날짜 바뀜([todayProvider])처럼 시계 흐름을 구독합니다.
final ProviderFamily<bool, DateTime> beforeDayStartProvider = Provider
    .autoDispose
    .family<bool, DateTime>(
      (ref, dayStart) => isBeforeDayStart(
        ref.watch(todayWallMinuteProvider),
        dayStart: dayStart,
        timezone: ref.watch(profileTimezoneProvider),
      ),
    );
