import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show ApplyInterceptor, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/language.dart';
import 'package:myungli_diary/core/api/gen/model/profile.dart';
import 'package:myungli_diary/core/platform/device_locale.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/glossary/data/glossary_repository.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';

import '../../support/app_harness.dart';
import '../../support/database_spies.dart';
import '../../support/profile_sync_harness.dart' show seoulProfile;

const Map<String, Object> _body = {
  'seedVersion': 'v1',
  'lang': 'ko',
  'values': {
    'ten_god': {'pyeongwan': '편관'},
    'tag': {'cheoneul_gwiin': '천을귀인'},
  },
  'meanings': {
    'ten_god.pyeongwan': {
      'segments': [
        {'text': '나를 다그치고 시험하는 기운이에요.'},
      ],
    },
  },
};

/// 정해 둔 응답을 차례로 돌려주고 요청 헤더를 기록합니다. 목록을 넘으면 마지막을 되풀이합니다.
final class _ScriptedServer extends Interceptor {
  new(this.responses);

  final List<Object> responses;
  final requestHeaders = <Map<String, Object?>>[];
  final queries = <Map<String, Object?>>[];
  var _calls = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    queries.add(options.queryParameters);
    requestHeaders.add({
      for (final e in options.headers.entries) e.key.toLowerCase(): e.value,
    });
    final next =
        responses[_calls < responses.length ? _calls : responses.length - 1];
    _calls++;
    if (next is DioExceptionType) {
      handler.reject(DioException(requestOptions: options, type: next), true);
      return;
    }
    final response = next as Response<Object?>;
    handler.resolve(
      Response<Object?>(
        requestOptions: options,
        statusCode: response.statusCode,
        headers: response.headers,
        data: response.data,
      ),
      true,
    );
  }
}

Response<Object?> _ok(String etag) => Response<Object?>(
  requestOptions: RequestOptions(),
  statusCode: 200,
  headers: Headers.fromMap({
    'etag': [etag],
  }),
  data: _body,
);

Response<Object?> _notModified() =>
    Response<Object?>(requestOptions: RequestOptions(), statusCode: 304);

({
  GlossaryRepository repository,
  CacheStore cache,
  _ScriptedServer server,
  FailingInserts cacheFailure,
  FakeCrashReporter reporter,
})
_setUp(List<Object> responses) {
  final cacheFailure = FailingInserts('cached_responses');
  final database = AppDatabase.forExecutor(
    NativeDatabase.memory().interceptWith(cacheFailure),
  );
  addTearDown(database.close);
  final cache = CacheStore(database, accountId: 'account-1');
  final server = _ScriptedServer(responses);
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..interceptors.add(server);
  final reporter = FakeCrashReporter();
  return (
    repository: GlossaryRepository(DefaultApi(dio), cache, reporter),
    cache: cache,
    server: server,
    cacheFailure: cacheFailure,
    reporter: reporter,
  );
}

Future<void> _seedBroken(CacheStore cache, String json) => cache.write(
  CacheKind.glossary,
  'ko',
  json,
  access: EvidenceAccess.unlocked,
);

void main() {
  // 메모리 DB를 한 테스트에서 둘 쓰는 경우가 있어 경고를 끕니다(서로 다른 실행기입니다).
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('처음에는 받아서 캐시에 etag와 함께 둔다', () async {
    final s = _setUp([_ok('"g1"')]);

    final names = await s.repository.load(Language.ko);

    expect(s.server.requestHeaders.single, isNot(contains('if-none-match')));
    expect(names.nameOf('ten_god.pyeongwan'), '편관');
    final stored = jsonDecode(
      (await s.cache.read(CacheKind.glossary, 'ko'))!,
    ) as Map<String, dynamic>;
    expect(stored['etag'], '"g1"');
    expect((stored['body'] as Map<String, dynamic>)['seedVersion'], 'v1');
  });

  test('캐시가 있으면 If-None-Match를 보내고 304면 캐시를 쓴다', () async {
    final s = _setUp([_ok('"g1"'), _notModified()]);

    final first = await s.repository.load(Language.ko);
    final second = await s.repository.load(Language.ko);

    expect(s.server.requestHeaders.last['if-none-match'], '"g1"');
    expect(second.values, first.values);
  });

  test('캐시 쓰기가 실패해도 받은 사전을 돌려주고 오류만 보고한다', () async {
    final s = _setUp([_ok('"g1"')]);
    s.cacheFailure.failing = true;

    final names = await s.repository.load(Language.ko);

    expect(names.nameOf('ten_god.pyeongwan'), '편관');
    expect(s.reporter.errors.single.errorType, 'StateError');
    expect(await s.cache.read(CacheKind.glossary, 'ko'), isNull);
  });

  test('언어마다 캐시를 따로 둔다', () async {
    final s = _setUp([_ok('"g1"')]);

    await s.repository.load(Language.ko);
    await s.repository.load(Language.en);

    expect(s.server.requestHeaders.last, isNot(contains('if-none-match')));
  });

  test('오프라인이고 캐시도 없으면 OfflineError', () async {
    final s = _setUp([DioExceptionType.connectionError]);

    await expectLater(
      s.repository.load(Language.ko),
      throwsA(isA<OfflineError>()),
    );
  });

  test('오프라인이면 캐시를 쓴다', () async {
    final s = _setUp([_ok('"g1"'), DioExceptionType.connectionError]);

    await s.repository.load(Language.ko);
    final cached = await s.repository.load(Language.ko);
    expect(cached.nameOf('tag.cheoneul_gwiin'), '천을귀인');
  });

  for (final (label, broken) in [
    ('문법 오류', '{not json'),
    ('모양이 다른 JSON', '{"etag": 1, "body": []}'),
  ]) {
    test('깨진 캐시($label)는 온라인이면 200으로 고쳐지고 오프라인이면 OfflineError', () async {
      final online = _setUp([_ok('"g1"')]);
      await _seedBroken(online.cache, broken);

      final names = await online.repository.load(Language.ko);

      expect(names.nameOf('ten_god.pyeongwan'), '편관');
      expect(
        online.server.requestHeaders.single,
        isNot(contains('if-none-match')),
      );
      final stored = jsonDecode(
        (await online.cache.read(CacheKind.glossary, 'ko'))!,
      ) as Map<String, dynamic>;
      expect(stored['etag'], '"g1"');

      final offline = _setUp([DioExceptionType.connectionError]);
      await _seedBroken(offline.cache, broken);
      await expectLater(
        offline.repository.load(Language.ko),
        throwsA(isA<OfflineError>()),
      );
    });
  }

  test('시간 초과면 캐시를 쓴다', () async {
    final s = _setUp([_ok('"g1"'), DioExceptionType.receiveTimeout]);

    await s.repository.load(Language.ko);
    final cached = await s.repository.load(Language.ko);

    expect(cached.nameOf('tag.cheoneul_gwiin'), '천을귀인');
  });

  test('시간 초과이고 캐시도 없으면 TimeoutError', () async {
    final s = _setUp([DioExceptionType.receiveTimeout]);

    await expectLater(
      s.repository.load(Language.ko),
      throwsA(isA<TimeoutError>()),
    );
  });

  test('캐시 없이 304를 받으면 UnexpectedError', () async {
    final s = _setUp([_notModified()]);

    await expectLater(
      s.repository.load(Language.ko),
      throwsA(isA<UnexpectedError>()),
    );
  });

  test('nameOf는 첫 점에서 범주와 값을 나누고 모르는 id는 null이다', () {
    const names = GlossaryNames({
      'ten_god': {'pyeongwan': '편관'},
      'tag': {'cheoneul_gwiin': '천을귀인', 'ten_god_rush.bigyeop': '비겁 몰림'},
    });

    expect(names.nameOf('ten_god.pyeongwan'), '편관');
    expect(names.nameOf('tag.cheoneul_gwiin'), '천을귀인');
    expect(names.nameOf('tag.ten_god_rush.bigyeop'), '비겁 몰림');
    expect(names.nameOf('tag.unknown'), isNull);
    expect(names.nameOf('unknown.cheoneul_gwiin'), isNull);
    expect(names.nameOf('cheoneul_gwiin'), isNull);
    expect(names.nameOf(''), isNull);
    expect(names.valueName('ten_god', 'pyeongwan'), '편관');
  });

  testWidgets('glossaryProvider는 fake 서버 fixture의 이름을 돌려준다', (tester) async {
    final container = (await tester.runAsync(
      () => bootstrapForTest('member'),
    ))!;
    addTearDown(container.dispose);
    await tester.runAsync(() => container.read(entryStateProvider.future));

    final names = (await tester.runAsync(
      () => container.read(glossaryProvider.future),
    ))!;

    expect(names.nameOf('element.wood'), '목');
    expect(names.nameOf('color.wood'), '초록');
    expect(names.nameOf('tag.cheoneul_gwiin'), '천을귀인');
    expect(names.nameOf('ten_god.pyeongwan'), '편관');
  });

  group('glossaryProvider 언어', () {
    Future<List<Object?>> languagesUsed({
      required Future<Profile?> Function() profile,
    }) async {
      final s = _setUp([_ok('"g1"')]);
      final container = ProviderContainer(
        overrides: [
          appLanguageProvider.overrideWithValue(Language.ja),
          cachedProfileProvider.overrideWith((ref) => profile()),
          glossaryRepositoryProvider.overrideWithValue(s.repository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(glossaryProvider.future);
      return [for (final q in s.server.queries) q['lang']];
    }

    test('프로필 사본이 없으면 앱 언어를 쓴다', () async {
      final used = await languagesUsed(profile: () async => null);
      expect(used, [Language.ja]);
    });

    test('프로필 사본을 읽다 실패해도 앱 언어로 사전을 받는다', () async {
      final used = await languagesUsed(
        profile: () async => throw StateError('깨진 사본'),
      );
      expect(used, [Language.ja]);
    });

    test('프로필 사본이 있으면 그 언어를 쓴다', () async {
      final used = await languagesUsed(
        profile: () async =>
            Profile.fromJson({...seoulProfile, 'language': 'en'}),
      );
      expect(used, [Language.en]);
    });
  });
}
