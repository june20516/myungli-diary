import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/core/api/gen/model/profile_patch.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';

/// 기기 시간대가 프로필 사본과 다르면 server에 알립니다.
///
/// UTC offset이 아니라 IANA 이름으로 비교합니다. offset이 같은 다른 지역으로 옮겨도
/// 프로필 시간대는 바뀌어야 하기 때문입니다.
final class TimezoneSync {
  /// `ref`로 진입·사본·기기 시간대를 읽습니다.
  new(this._ref);

  final Ref _ref;
  var _syncing = false;

  /// 진입이 `ready`일 때만, 사본이 없거나 기기 시간대와 다르면 `PATCH`합니다.
  ///
  /// 실패는 삼키고 `CrashSummary`만 남깁니다. 사본이 그대로라 다음 호출에서 다시 보냅니다.
  Future<void> syncIfChanged() async {
    if (_syncing || _ref.read(entryProvider) != EntryState.ready) {
      return;
    }
    _syncing = true;
    try {
      final repository = _ref.read(profileRepositoryProvider);
      final profile = await repository.cached();
      final device = await _ref.read(deviceTimezoneProvider).current();
      // 사본이 없으면(재설치·다른 기기 로그인) server의 시간대가 옛것일 수 있어
      // 기기 시간대를 한 번 보내고 응답을 사본으로 삼습니다.
      if (device == profile?.currentTimezone) {
        return;
      }
      await repository.update(ProfilePatch(currentTimezone: device));
    } on Object catch (error, stack) {
      _ref.read(crashReporterProvider).record(CrashSummary.from(error), stack);
    } finally {
      _syncing = false;
    }
  }
}

/// 기기 시간대 동기화.
final timezoneSyncProvider = Provider<TimezoneSync>(TimezoneSync.new);
