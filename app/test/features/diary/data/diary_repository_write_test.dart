import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/fake/scenario.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/features/diary/data/diary_repository.dart';

/// fake 시드의 2026-10-12 일기.
const _writtenId = '7b1c2a54-3d0e-4f6a-9b21-5e8f40c1a001';

Future<DiaryRepository> _repository(String scenarioId) async {
  final scenario = (await loadScenarios(rootBundle))
      .singleWhere((s) => s.id == scenarioId);
  return DiaryRepository(
    DefaultApi(
      Dio(BaseOptions(baseUrl: 'http://localhost:8080'))
        ..interceptors.add(
          FakeServerInterceptor(scenario: scenario, bundle: rootBundle),
        ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('page는 limit만큼 받고 nextCursor로 이어 받습니다', () async {
    final repository = await _repository('member');
    final first = await repository.page(limit: 3);
    expect(first.items.map((item) => item.date), [
      '2026-10-12',
      '2026-10-08',
      '2026-10-05',
    ]);
    final second = await repository.page(limit: 3, cursor: first.nextCursor);
    expect(second.items.map((item) => item.date), ['2026-10-02']);
    expect(second.nextCursor, isNull);
  });

  test('page는 태그로 거릅니다', () async {
    final repository = await _repository('member');
    final tagged = await repository.page(tag: 'clash');
    expect(tagged.items.map((item) => item.date), ['2026-10-02']);
  });

  test('find는 있으면 일기, 404면 null입니다', () async {
    final repository = await _repository('member');
    expect((await repository.find(_writtenId))!.date, '2026-10-12');
    expect(await repository.find('unknown'), isNull);
  });

  test('create는 쓴 일기를 돌려주고, 미래 날짜는 ProblemError입니다', () async {
    final repository = await _repository('member');
    final diary = await repository.create(
      CalendarDate(2026, 10, 13),
      '오늘 일기',
      idempotencyKey: 'key-1',
    );
    expect(diary.body, '오늘 일기');
    expect((await repository.find(diary.id))!.body, '오늘 일기');
    await expectLater(
      repository.create(
        CalendarDate(2026, 10, 14),
        '내일',
        idempotencyKey: 'key-2',
      ),
      throwsA(
        isA<ProblemError>().having((e) => e.code, 'code', 'diary.future_date'),
      ),
    );
  });

  test('delete 뒤 find는 null이고, 없는 일기 delete는 diary.not_found입니다', () async {
    final repository = await _repository('member');
    await repository.delete(_writtenId);
    expect(await repository.find(_writtenId), isNull);
    await expectLater(
      repository.delete(_writtenId),
      throwsA(
        isA<ProblemError>().having((e) => e.code, 'code', 'diary.not_found'),
      ),
    );
  });

  test('오프라인이면 OfflineError입니다', () async {
    final offline = await _repository('offline');
    await expectLater(offline.page(), throwsA(isA<OfflineError>()));
    await expectLater(
      offline.create(CalendarDate(2026, 10, 1), '본문', idempotencyKey: 'key'),
      throwsA(isA<OfflineError>()),
    );
  });
}
