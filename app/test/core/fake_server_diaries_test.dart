import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/fake/scenario.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
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

    test('처음 목록은 listDiaries fixture이고 그 날 getDiary는 200입니다', () async {
      final list = (await api.listDiaries()).data!;
      expect(list.items.map((item) => item.date), [
        '2026-10-12',
        '2026-10-08',
        '2026-10-05',
        '2026-10-02',
      ]);
      expect((await api.getDiary(date: '2026-10-12')).statusCode, 200);
      final missing = await _problemOf(() => api.getDiary(date: '2026-10-13'));
      expect((missing.status, missing.code), (404, 'diary.not_found'));
    });

    test('쓰면 201, 고치면 200이고 목록·보기에 바로 보입니다', () async {
      final created = await api.putDiary(
        date: '2026-10-13',
        diaryInput: DiaryInput(body: '오늘 일기'),
      );
      expect(created.statusCode, 201);
      expect(created.data!.tags.all, ['cheoneul_gwiin', 'yongsin_day']);
      expect(created.data!.guideQuestion, isNotNull);

      final updated = await api.putDiary(
        date: '2026-10-13',
        diaryInput: DiaryInput(body: '고친 일기'),
      );
      expect(updated.statusCode, 200);
      expect((await api.getDiary(date: '2026-10-13')).data!.body, '고친 일기');
      final tagged = (await api.listDiaries(tag: 'yongsin_day')).data!;
      expect(tagged.items.single.date, '2026-10-13');
    });

    test('지우면 204이고 다시 보면 404입니다', () async {
      final deleted = await api.deleteDiary(date: '2026-10-12');
      expect(deleted.statusCode, 204);
      final gone = await _problemOf(() => api.getDiary(date: '2026-10-12'));
      expect(gone.code, 'diary.not_found');
    });

    test('미래 날짜는 422 diary.future_date입니다', () async {
      final problem = await _problemOf(
        () => api.putDiary(
          date: '2026-10-14',
          diaryInput: DiaryInput(body: '내일'),
        ),
      );
      expect((problem.status, problem.code), (422, 'diary.future_date'));
    });

    test('diary-written 시나리오는 getDiary fixture의 전체 일기로 시작합니다', () async {
      final written = _apiOf(await _scenarioOf('diary-written'));
      final diary = (await written.getDiary(date: '2026-10-13')).data!;
      expect(diary.body, '회의에서 먼저 말을 꺼냈더니 생각보다 반응이 좋았다.');
    });
  });
}
