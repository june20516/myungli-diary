import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/device_flags.dart';

void main() {
  late AppDatabase database;
  late DeviceFlagsStore store;

  setUp(() {
    database = AppDatabase.forExecutor(NativeDatabase.memory());
    store = DeviceFlagsStore(database);
  });

  tearDown(() => database.close());

  test('writeString 뒤 readString으로 읽고, 없는 키는 null이다', () async {
    expect(await store.readString('k'), isNull);
    await store.writeString('k', value: 'v');
    expect(await store.readString('k'), 'v');
    await store.writeString('k', value: 'w');
    expect(await store.readString('k'), 'w');
  });

  test('로그아웃 정리 뒤에도 문자열 값이 남는다', () async {
    await store.writeString('k', value: 'v');
    await database.clearSignedOutData();
    expect(await store.readString('k'), 'v');
  });
}
