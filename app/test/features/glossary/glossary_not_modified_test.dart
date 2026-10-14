import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/language.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/features/glossary/data/glossary_repository.dart';

// TestWidgetsFlutterBinding은 HTTP를 막으므로, 실제 소켓이 필요한 이 테스트는 파일을 따로 둡니다.
// 실제 Dio는 기본 validateStatus에서 304를 예외로 던지므로, repository가 넘기는
// validateStatus를 지우면 이 테스트가 실패합니다.
void main() {
  test('repository는 실제 서버의 본문 없는 304를 캐시로 처리한다', () async {
    final ifNoneMatches = <String?>[];
    final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await httpServer.close(force: true);
    });
    httpServer.listen((request) async {
      final etag = request.headers.value('if-none-match');
      ifNoneMatches.add(etag);
      if (etag == '"g1"') {
        request.response.statusCode = HttpStatus.notModified;
      } else {
        request.response.headers
          ..contentType = ContentType.json
          ..set('etag', '"g1"');
        request.response.write(
          jsonEncode({
            'seedVersion': 'v1',
            'lang': 'ko',
            'values': {
              'ten_god': {'pyeongwan': '편관'},
            },
          }),
        );
      }
      await request.response.close();
    });
    final dio = Dio(
      BaseOptions(baseUrl: 'http://127.0.0.1:${httpServer.port}'),
    );
    addTearDown(dio.close);
    final database = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = GlossaryRepository(
      DefaultApi(dio),
      CacheStore(database, accountId: 'account-1'),
    );

    final first = await repository.load(Language.ko);
    final second = await repository.load(Language.ko);

    expect(ifNoneMatches, [null, '"g1"']);
    expect(second.values, first.values);
    expect(second.nameOf('ten_god.pyeongwan'), '편관');
  });
}
