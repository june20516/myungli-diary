import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/fake/scenario.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/diary.dart';
import 'package:myungli_diary/core/api/gen/model/diary_body_input.dart';
import 'package:myungli_diary/core/api/gen/model/diary_input.dart';

Future<Scenario> _scenarioOf(String id) async =>
    (await loadScenarios(rootBundle)).singleWhere((s) => s.id == id);

DefaultApi _apiOf(Scenario scenario) => DefaultApi(
  Dio(BaseOptions(baseUrl: 'http://localhost:8080'))
    ..interceptors.add(
      FakeServerInterceptor(scenario: scenario, bundle: rootBundle),
    ),
);

Future<ProblemError> _problemOf(Future<Object?> Function() call) async {
  try {
    await call();
  } on DioException catch (e) {
    final error = appErrorFrom(e);
    if (error is ProblemError) {
      return error;
    }
    throw StateError('problem 응답이 아닙니다: $error');
  }
  throw StateError('오류가 나야 합니다.');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('fake 일기 저장소(서버)', () {
    late DefaultApi api;

    setUp(() async {
      api = _apiOf(await _scenarioOf('member'));
    });

    Future<Diary> create(String date, String body, {String? key}) async =>
        (await api.createDiary(
          diaryInput: DiaryInput(date: date, body: body),
          idempotencyKey: key,
        )).data!;

    test('처음 목록은 listDiaries fixture이고 그 일기 getDiary는 200입니다', () async {
      final list = (await api.listDiaries()).data!;
      expect(list.items.map((item) => item.date), [
        '2026-10-12',
        '2026-10-08',
        '2026-10-05',
        '2026-10-02',
      ]);
      expect((await api.getDiary(id: list.items.first.id)).statusCode, 200);
      final missing = await _problemOf(
        () => api.getDiary(id: '00000000-0000-4000-8000-000000000000'),
      );
      expect((missing.status, missing.code), (404, 'diary.not_found'));
    });

    test('쓰면 201이고 목록·보기·태그 거르기에 바로 보입니다', () async {
      final response = await api.createDiary(
        diaryInput: DiaryInput(date: '2026-10-13', body: '오늘 일기'),
      );
      expect(response.statusCode, 201);
      final created = response.data!;
      expect(created.tags.all, ['cheoneul_gwiin', 'yongsin_day']);
      expect(created.guideQuestion, isNotNull);
      expect((await api.getDiary(id: created.id)).data!.body, '오늘 일기');
      final tagged = (await api.listDiaries(tag: 'yongsin_day')).data!;
      expect(tagged.items.single.id, created.id);
    });

    test('같은 날 두 편은 작성 순으로 목록에 나옵니다', () async {
      final first = await create('2026-10-13', '첫째');
      final second = await create('2026-10-13', '둘째');
      expect(second.tags.all, first.tags.all);
      final list = (await api.listDiaries(
        from: '2026-10-13',
        to: '2026-10-13',
      )).data!;
      expect(list.items.map((item) => item.id), [first.id, second.id]);
      expect(list.items.map((item) => item.createdAt).toList(), [
        first.createdAt,
        second.createdAt,
      ]);
    });

    test('10편째 뒤 createDiary는 422 diary.day_full입니다', () async {
      for (var n = 0; n < 10; n++) {
        await create('2026-10-13', '$n번째');
      }
      final problem = await _problemOf(() => create('2026-10-13', '열한째'));
      expect((problem.status, problem.code), (422, 'diary.day_full'));
      expect(problem.fieldErrors.single.pointer, '/date');
      // 다른 날은 영향이 없습니다.
      expect((await create('2026-10-12', '다른 날')).date, '2026-10-12');
    });

    test('같은 Idempotency-Key 재전송은 같은 일기를 돌려주고 늘지 않습니다', () async {
      final first = await create('2026-10-13', '일기', key: 'k1');
      final again = await create('2026-10-13', '일기', key: 'k1');
      expect(again.id, first.id);
      final list = (await api.listDiaries(
        from: '2026-10-13',
        to: '2026-10-13',
      )).data!;
      expect(list.items, hasLength(1));
      final mismatch = await _problemOf(
        () => create('2026-10-13', '다른 본문', key: 'k1'),
      );
      expect(mismatch.code, 'idempotency.mismatch');
    });

    test('지운 일기 getDiary는 404입니다', () async {
      final id = (await api.listDiaries()).data!.items.first.id;
      final deleted = await api.deleteDiary(id: id);
      expect(deleted.statusCode, 204);
      final gone = await _problemOf(() => api.getDiary(id: id));
      expect(gone.code, 'diary.not_found');
      final again = await _problemOf(() => api.deleteDiary(id: id));
      expect(again.code, 'diary.not_found');
    });

    test('updateDiary는 본문만 바꾸고 tags·createdAt은 그대로입니다', () async {
      final created = await create('2026-10-13', '처음');
      final updated = (await api.updateDiary(
        id: created.id,
        diaryBodyInput: DiaryBodyInput(body: '고침'),
      )).data!;
      expect(updated.body, '고침');
      expect(updated.tags.all, created.tags.all);
      expect(updated.createdAt, created.createdAt);
      expect(updated.id, created.id);
    });

    test('오늘 뒤 날짜 createDiary는 422 diary.future_date입니다', () async {
      final problem = await _problemOf(() => create('2026-10-14', '내일'));
      expect((problem.status, problem.code), (422, 'diary.future_date'));
    });

    test('restoreDiary는 대역이 구현하지 않아 501입니다', () async {
      final problem = await _problemOf(
        () => api.restoreDiary(id: '00000000-0000-4000-8000-000000000000'),
      );
      expect(problem.status, 501);
    });

    test('diary-written 시나리오는 getDiary fixture의 전체 일기로 시작합니다', () async {
      final written = _apiOf(await _scenarioOf('diary-written'));
      const id = '7b1c2a54-3d0e-4f6a-9b21-5e8f40c1a005';
      final diary = (await written.getDiary(id: id)).data!;
      expect(diary.body, '회의에서 먼저 말을 꺼냈더니 생각보다 반응이 좋았다.');
    });

    test('diary-written 같은 날 둘째 편은 전체 일기의 날짜 기록을 씁니다', () async {
      final written = _apiOf(await _scenarioOf('diary-written'));
      final full = (await written.getDiary(
        id: '7b1c2a54-3d0e-4f6a-9b21-5e8f40c1a005',
      )).data!;
      final second = (await written.createDiary(
        diaryInput: DiaryInput(date: '2026-10-13', body: '둘째'),
      )).data!;
      expect(second.tags.all, full.tags.all);
      expect(second.guideQuestion, isNotNull);
      expect(
        second.guideQuestion!.segments.first.text,
        full.guideQuestion!.segments.first.text,
      );
    });

    test('diary-day-full 시나리오는 오늘 일기 10편으로 시작합니다', () async {
      final full = _apiOf(await _scenarioOf('diary-day-full'));
      final list = (await full.listDiaries(
        from: '2026-10-13',
        to: '2026-10-13',
      )).data!;
      expect(list.items, hasLength(10));
      final problem = await _problemOf(
        () => full.createDiary(
          diaryInput: DiaryInput(date: '2026-10-13', body: '열한째'),
        ),
      );
      expect(problem.code, 'diary.day_full');
    });

    test('쪽 넘김은 한 날짜가 두 쪽에 나뉘어도 순서를 지킵니다', () async {
      final full = _apiOf(await _scenarioOf('diary-day-full'));
      final first = (await full.listDiaries(limit: 6)).data!;
      expect(first.nextCursor, isNotNull);
      final second = (await full.listDiaries(
        limit: 6,
        cursor: first.nextCursor,
      )).data!;
      final all = [...first.items, ...second.items];
      expect(
        all.map((item) => item.createdAt).toList(),
        [for (final item in all) item.createdAt]..sort(),
      );
      expect(all.map((item) => item.id).toSet(), hasLength(all.length));
    });
  });
}
