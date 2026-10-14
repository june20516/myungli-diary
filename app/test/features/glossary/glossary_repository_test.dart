import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/language.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/glossary/data/glossary_repository.dart';

import '../../support/app_harness.dart';

const Map<String, Object> _body = {
  'seedVersion': 'v1',
  'lang': 'ko',
  'values': {
    'ten_god': {'pyeongwan': '편관'},
    'tag': {'gwiin': '귀인'},
  },
};

/// 정해 둔 응답을 차례로 돌려주고 요청 헤더를 기록합니다. 목록을 넘으면 마지막을 되풀이합니다.
final class _ScriptedServer extends Interceptor {
  new(this.responses);

  final List<Object> responses;
  final requestHeaders = <Map<String, Object?>>[];
  var _calls = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
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

({GlossaryRepository repository, CacheStore cache, _ScriptedServer server})
_setUp(List<Object> responses) {
  final database = AppDatabase.forExecutor(NativeDatabase.memory());
  addTearDown(database.close);
  final cache = CacheStore(database, accountId: 'account-1');
  final server = _ScriptedServer(responses);
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..interceptors.add(server);
  return (
    repository: GlossaryRepository(DefaultApi(dio), cache),
    cache: cache,
    server: server,
  );
}

void main() {
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
    expect(cached.nameOf('tag.gwiin'), '귀인');
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
      'tag': {'gwiin': '귀인', 'ten_god_rush.bigyeop': '비겁 몰림'},
    });

    expect(names.nameOf('ten_god.pyeongwan'), '편관');
    expect(names.nameOf('tag.gwiin'), '귀인');
    expect(names.nameOf('tag.ten_god_rush.bigyeop'), '비겁 몰림');
    expect(names.nameOf('tag.unknown'), isNull);
    expect(names.nameOf('unknown.gwiin'), isNull);
    expect(names.nameOf('gwiin'), isNull);
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
    expect(names.nameOf('tag.gwiin'), '귀인');
    expect(names.nameOf('ten_god.pyeongwan'), '편관');
  });
}
