import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/storage/secure_store.dart';

void main() {
  test('iOS Keychain 값은 이 기기 전용이라 백업으로 새 기기에 옮겨지지 않습니다', () {
    final options = defaultSecureStorage.iOptions;
    expect(
      options.accessibility,
      KeychainAccessibility.first_unlock_this_device,
    );
    expect(options.synchronizable, isFalse, reason: 'iCloud Keychain 동기화 금지');
  });
}
