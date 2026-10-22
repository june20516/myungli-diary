import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/fake/scenario.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/diary_summary.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/features/diary/application/diary_providers.dart';

/// 모든 요청을 [type] 오류로 끊습니다.
final class _Failing extends Interceptor {
  new(this.type);

  final DioExceptionType type;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.reject(DioException(requestOptions: options, type: type));
  }
}

Future<(ProviderContainer, FakeCrashReporter)> _container({
  DioExceptionType? failWith,
}) async {
  final scenario = (await loadScenarios(rootBundle))
      .singleWhere((s) => s.id == 'member');
  final crash = FakeCrashReporter();
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'))
    ..interceptors.add(
      failWith == null
          ? FakeServerInterceptor(scenario: scenario, bundle: rootBundle)
          : _Failing(failWith),
    );
  final container = ProviderContainer(
    overrides: [
      restClientProvider.overrideWithValue(DefaultApi(dio)),
      crashReporterProvider.overrideWithValue(crash),
    ],
  );
  addTearDown(container.dispose);
  return (container, crash);
}

/// autoDispose가 기다리는 도중 버리지 않도록 구독을 유지한 채 받습니다.
Future<List<DiarySummary>> _load(ProviderContainer container) {
  final provider = diariesOnProvider(CalendarDate(2026, 10, 12));
  container.listen(provider, (_, _) {});
  return container.read(provider.future);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('diariesOnProvider', () {
    test('성공하면 server 순서 그대로 그날 일기 요약입니다', () async {
      final (container, crash) = await _container();
      final list = await _load(container);
      expect(list.map((item) => item.date), ['2026-10-12']);
      expect(crash.errors, isEmpty);
    });

    test('연결이 없으면 빈 목록이고 보고하지 않습니다', () async {
      final (container, crash) = await _container(
        failWith: DioExceptionType.connectionError,
      );
      final list = await _load(container);
      expect(list, isEmpty);
      expect(crash.errors, isEmpty);
    });

    test('예상하지 못한 오류는 빈 목록이고 crash 요약을 한 번 남깁니다', () async {
      final (container, crash) = await _container(
        failWith: DioExceptionType.unknown,
      );
      final list = await _load(container);
      expect(list, isEmpty);
      expect(crash.errors, hasLength(1));
    });
  });
}
