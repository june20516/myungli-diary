import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/gen/model/profile_input.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';

import '../../support/app_harness.dart';

ProfileInput _input() => ProfileInput.fromJson({
  'honorific': '하늘',
  'language': 'ko',
  'currentTimezone': 'Asia/Seoul',
  'birth': {
    'calendar': 'solar',
    'date': {'year': 1990, 'month': 5, 'day': 15},
    'isLeapMonth': false,
    'time': {'status': 'known', 'value': '14:30'},
    'gender': 'female',
    'timezone': 'Asia/Seoul',
    'place': {'status': 'not_asked'},
  },
  'notification': {'status': 'not_asked'},
});

void main() {
  testWidgets('create 뒤 cached()는 응답 profile과 같고, 로그아웃 정리 뒤에는 null이다', (
    tester,
  ) async {
    final container = (await tester.runAsync(
      () => bootstrapForTest('member'),
    ))!;
    addTearDown(container.dispose);
    await tester.runAsync(() => container.read(entryStateProvider.future));
    final repository = container.read(profileRepositoryProvider);

    final created = (await tester.runAsync(() => repository.create(_input())))!;
    final cached = (await tester.runAsync(repository.cached))!;
    expect(cached, created.profile);
    expect(cached.honorific, '하늘');

    await tester.runAsync(
      () => container.read(appDatabaseProvider).clearSignedOutData(),
    );
    expect(await tester.runAsync(repository.cached), isNull);
  });
}
