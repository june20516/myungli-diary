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

  // 저장된 v1 덤프로 시작하는 틀입니다. v2를 만들 때 이전 → 다음 마이그레이션 검증에
  // 쓰고, 이 테스트만으로는 코드 스키마와 덤프의 일치를 보장하지 않습니다.
  test('v1 덤프가 열리고 현재 스키마와 일치한다', () async {
    final connection = await verifier.startAt(1);
    final database = AppDatabase.forExecutor(connection);
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 1);
    expect(await database.select(database.cachedResponses).get(), isEmpty);
    expect(await database.select(database.diaryDrafts).get(), isEmpty);
    expect(await database.select(database.onboardingInputs).get(), isEmpty);
    expect(await database.select(database.deviceFlags).get(), isEmpty);
  });

  test('코드가 만든 스키마가 저장된 v1 덤프와 일치한다', () async {
    final database = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, 1);
  });
}
