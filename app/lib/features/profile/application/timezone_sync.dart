import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/core/api/gen/model/profile_patch.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/cache_first.dart';
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
  Future<void> _inFlight = Future.value();

  /// 부른 시점에 진행 중인 동기화가 끝나면 완료되는 Future. 테스트가 기다립니다.
  ///
  /// 그 시점의 스냅샷이라 이후에 시작한 새 동기화는 따라가지 않습니다.
  Future<void> get idle => _inFlight;

  /// 진입이 `ready`일 때만, 사본이 없거나 기기 시간대와 다르면 `PATCH`합니다.
  ///
  /// 이미 진행 중이거나 진입이 `ready`가 아니면 새로 시작하지 않고, 진행 중이던(없으면
  /// 이미 끝난) Future를 그대로 돌려줍니다.
  ///
  /// 실패는 삼킵니다. 사본이 그대로라 다음 호출에서 다시 보냅니다. 연결 오류(오프라인·
  /// 시간 초과)는 고칠 일이 아니므로 보고하지 않고, 그 밖의 실패만 `CrashSummary`로 남깁니다.
  Future<void> syncIfChanged() {
    if (_syncing || _ref.read(entryProvider) != EntryState.ready) {
      return _inFlight;
    }
    _syncing = true;
    return _inFlight = _sync();
  }

  Future<void> _sync() async {
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
      if (!isConnectivityError(error)) {
        _ref
            .read(crashReporterProvider)
            .record(CrashSummary.from(error), stack);
      }
    } finally {
      _syncing = false;
    }
  }
}

/// 기기 시간대 동기화.
final timezoneSyncProvider = Provider<TimezoneSync>(TimezoneSync.new);
