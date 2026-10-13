import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 비밀 값(refresh token 등)을 저장하는 키-값 저장소입니다.
abstract interface class SecureStore {
  /// [key]의 값을 읽습니다. 없으면 null입니다.
  Future<String?> read(String key);

  /// [key]에 [value]를 씁니다.
  Future<void> write(String key, String value);

  /// [key]를 지웁니다.
  Future<void> delete(String key);
}

/// 앱이 쓰는 기기 보안 저장소 설정.
///
/// iOS Keychain 값은 `first_unlock_this_device`입니다. 이 기기 전용이라 암호화 백업·
/// 기기 이전으로 새 기기에 옮겨지지 않고(Android 백업 끔과 대칭), 첫 잠금 해제 뒤에는
/// 백그라운드에서도 읽을 수 있습니다. iCloud Keychain 동기화는 하지 않습니다.
const FlutterSecureStorage defaultSecureStorage = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);

/// 기기 보안 저장소(iOS Keychain, Android Keystore) 구현입니다.
final class FlutterSecureStore implements SecureStore {
  /// 저장소를 만듭니다. 테스트에서는 storage를 바꿔 끼웁니다.
  const new([this._storage = defaultSecureStorage]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// 메모리 구현. 테스트와 미리보기에서 씁니다.
final class MemorySecureStore implements SecureStore {
  /// 비어 있는 저장소를 만듭니다.
  new();

  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}
