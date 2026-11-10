import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/storage/app_database.dart';

import 'drift_schema/schema.dart';

// 스키마를 올릴 때: `dart run drift_dev schema dump`로 새 버전을 저장하고
// `schema generate`를 다시 돌린 뒤, 이전 버전 → 다음 버전 테스트를 이 틀에 덧붙인다.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  // 이관은 늘 지금 코드의 판까지 한 번에 갑니다(중간 판 덤프와는 대조하지 않음).
  test('v3 덤프에서 v4로 올리면 v4 덤프와 일치한다', () async {
    final connection = await verifier.startAt(3);
    final database = AppDatabase.forExecutor(connection);
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 4);
    expect(await database.select(database.diaryDrafts).get(), isEmpty);
  });

  test('v2 덤프에서 v4로 올리면 v4 덤프와 일치한다', () async {
    final connection = await verifier.startAt(2);
    final database = AppDatabase.forExecutor(connection);
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 4);
    expect(await database.select(database.diaryDrafts).get(), isEmpty);
  });

  test('v1 덤프에서 v4로 올리면 v4 덤프와 일치한다', () async {
    final connection = await verifier.startAt(1);
    final database = AppDatabase.forExecutor(connection);
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 4);
    expect(await database.select(database.cachedResponses).get(), isEmpty);
    expect(await database.select(database.diaryDrafts).get(), isEmpty);
    expect(await database.select(database.onboardingInputs).get(), isEmpty);
    expect(await database.select(database.deviceFlags).get(), isEmpty);
  });

  test('코드가 만든 스키마가 저장된 v4 덤프와 일치한다', () async {
    final database = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 4);
  });
}
