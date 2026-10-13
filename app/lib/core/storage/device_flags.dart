import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/storage/app_database.dart';

/// 이 기기에서 광고 동의를 한 번 거쳤는지 나타내는 [DeviceFlags] 키.
const adConsentDoneKey = 'ad.consentDone';

const _trueValue = 'true';
const _falseValue = 'false';

/// 기기 단위 불리언 플래그 저장소. 계정과 무관합니다.
final class DeviceFlagsStore {
  /// [_database]의 `DeviceFlags` 테이블을 씁니다.
  const new(this._database);

  final AppDatabase _database;

  /// [key]의 값. 저장된 적 없으면 false입니다.
  Future<bool> readBool(String key) async {
    final row = await (_database.select(
      _database.deviceFlags,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value == _trueValue;
  }

  /// [key]에 [value]를 씁니다. 같은 키면 덮어씁니다.
  Future<void> writeBool(String key, {required bool value}) => _database
      .into(_database.deviceFlags)
      .insertOnConflictUpdate(
        DeviceFlagsCompanion.insert(
          key: key,
          value: value ? _trueValue : _falseValue,
        ),
      );
}

/// 기기 플래그 저장소.
final deviceFlagsStoreProvider = Provider<DeviceFlagsStore>(
  (ref) => DeviceFlagsStore(ref.watch(appDatabaseProvider)),
);
