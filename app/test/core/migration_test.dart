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

  test('v1 덤프에서 v2로 올리면 v2 덤프와 일치한다', () async {
    final connection = await verifier.startAt(1);
    final database = AppDatabase.forExecutor(connection);
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 2);
    expect(await database.select(database.cachedResponses).get(), isEmpty);
    expect(await database.select(database.diaryDrafts).get(), isEmpty);
    expect(await database.select(database.onboardingInputs).get(), isEmpty);
    expect(await database.select(database.deviceFlags).get(), isEmpty);
  });

  test('코드가 만든 스키마가 저장된 v2 덤프와 일치한다', () async {
    final database = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 2);
  });
}
