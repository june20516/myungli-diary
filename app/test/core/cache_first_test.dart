import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/storage/cache_first.dart';

void main() {
  test('캐시를 먼저 알리고 server 값으로 바꾸며 새 값을 쓴다', () async {
    final events = <String>[];

    final result = await loadCacheFirst<String>(
      readCache: () async => 'cached',
      onCached: (value) => events.add('shown $value'),
      fetch: () async {
        events.add('fetch');
        return 'fresh';
      },
      writeCache: (value) async => events.add('write $value'),
    );

    expect(events, ['shown cached', 'fetch', 'write fresh']);
    expect(result.value, 'fresh');
    expect(result.stale, isFalse);
  });

  test('캐시가 없으면 알리지 않고 server 값만 쓴다', () async {
    final shown = <String>[];

    final result = await loadCacheFirst<String>(
      readCache: () async => null,
      onCached: shown.add,
      fetch: () async => 'fresh',
    );

    expect(shown, isEmpty);
    expect(result, (value: 'fresh', stale: false));
  });

  test('readCache가 없으면 캐시를 보지 않는다', () async {
    final shown = <String>[];

    final result = await loadCacheFirst<String>(
      onCached: shown.add,
      fetch: () async => 'fresh',
    );

    expect(shown, isEmpty);
    expect(result.value, 'fresh');
  });

  for (final error in const <AppError>[OfflineError(), TimeoutError()]) {
    test('${error.runtimeType}이고 캐시가 있으면 stale 캐시이고 쓰지 않는다', () async {
      final written = <String>[];

      final result = await loadCacheFirst<String>(
        readCache: () async => 'cached',
        fetch: () async => throw error,
        writeCache: (value) async => written.add(value),
      );

      expect(result, (value: 'cached', stale: true));
      expect(written, isEmpty);
    });
  }

  test('연결 오류여도 캐시가 없으면 그 오류를 던진다', () async {
    await expectLater(
      loadCacheFirst<String>(
        readCache: () async => null,
        fetch: () async => throw const OfflineError(),
      ),
      throwsA(isA<OfflineError>()),
    );
  });

  test('server가 오류로 답하면 캐시가 있어도 그 오류를 던진다', () async {
    const problem = ProblemError(
      code: 'service.unavailable',
      status: 503,
      fieldErrors: [],
      traceId: 't',
    );

    await expectLater(
      loadCacheFirst<String>(
        readCache: () async => 'cached',
        fetch: () async => throw problem,
      ),
      throwsA(same(problem)),
    );
  });
}
