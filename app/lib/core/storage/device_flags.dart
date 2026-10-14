import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/storage/app_database.dart';

/// 이 기기에서 광고 동의를 한 번 거쳤는지 나타내는 [DeviceFlags] 키.
const adConsentDoneKey = 'ad.consentDone';

/// 새 계정의 프로필을 만든 뒤 알림 허락(notify-ask)을 기다리는지 나타내는 [DeviceFlags] 키.
///
/// 프로필을 만들면 켜고, notify-ask가 허락하거나 건너뛰면 끕니다. 로그아웃하면 끕니다(A17).
const notifyAskPendingKey = 'onboarding.notifyAskPending';

/// 이 설치에서 앱을 한 번 실행했는지 나타내는 [DeviceFlags] 키.
///
/// 앱을 지우면 DB는 사라지지만 iOS Keychain의 값(refresh token)은 남습니다. 이 표시가
/// 없으면 다시 설치한 것으로 보고 보안 저장소의 이전 값을 버립니다. 로그아웃 정리는
/// 기기 플래그를 남기므로 이 표시도 남습니다.
const installedKey = 'app.installed';

/// 이 설치의 id(UUID v4)를 담는 [DeviceFlags] 키. 로그아웃해도 남습니다.
const installationIdKey = 'app.installationId';

const _trueValue = 'true';
const _falseValue = 'false';

/// 기기 단위 불리언 플래그 저장소. 계정과 무관합니다.
final class DeviceFlagsStore {
  /// [_database]의 `DeviceFlags` 테이블을 씁니다.
  const new(this._database);

  final AppDatabase _database;

  /// [key]의 값. 저장된 적 없으면 false입니다.
  Future<bool> readBool(String key) async =>
      await readString(key) == _trueValue;

  /// [key]의 문자열 값. 저장된 적 없으면 null입니다.
  Future<String?> readString(String key) async {
    final row = await (_database.select(
      _database.deviceFlags,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  /// [key]에 문자열 [value]를 씁니다. 같은 키면 덮어씁니다.
  Future<void> writeString(String key, {required String value}) => _database
      .into(_database.deviceFlags)
      .insertOnConflictUpdate(
        DeviceFlagsCompanion.insert(key: key, value: value),
      );

  /// [key]에 [value]를 씁니다. 같은 키면 덮어씁니다.
  Future<void> writeBool(String key, {required bool value}) =>
      writeString(key, value: value ? _trueValue : _falseValue);
}

/// 기기 플래그 저장소.
final deviceFlagsStoreProvider = Provider<DeviceFlagsStore>(
  (ref) => DeviceFlagsStore(ref.watch(appDatabaseProvider)),
);
