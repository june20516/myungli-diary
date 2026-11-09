import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/fake/scenario.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/diary_input.dart';

Future<DefaultApi> _apiOf(String scenarioId) async {
  final scenario = (await loadScenarios(rootBundle))
      .singleWhere((s) => s.id == scenarioId);
  return DefaultApi(
    Dio(BaseOptions(baseUrl: 'http://localhost:8080'))
      ..interceptors.add(
        FakeServerInterceptor(scenario: scenario, bundle: rootBundle),
      ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('getDiaryStats는 fixture 파일이 아니라 저장소의 살아 있는 일기로 셉니다', () async {
    final api = await _apiOf('member');
    final before = (await api.getDiaryStats()).data!;

    final created = (await api.createDiary(
      diaryInput: DiaryInput(date: '2026-10-13', body: '오늘의 일기'),
    )).data!;
    final after = (await api.getDiaryStats()).data!;
    expect(after.entryCount, before.entryCount + 1);

    await api.deleteDiary(id: created.id);
    expect((await api.getDiaryStats()).data!.entryCount, before.entryCount);
  });
}
