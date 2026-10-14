import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/language.dart';

// TestWidgetsFlutterBinding은 HTTP를 막으므로, 실제 소켓이 필요한 이 테스트는 파일을 따로 둡니다.
void main() {
  test('실제 Dio는 본문 없는 304를 예외 없이 돌려준다', () async {
    final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await httpServer.close(force: true);
    });
    httpServer.listen((request) async {
      request.response.statusCode = HttpStatus.notModified;
      await request.response.close();
    });
    final dio = Dio(
      BaseOptions(baseUrl: 'http://127.0.0.1:${httpServer.port}'),
    );
    addTearDown(dio.close);

    final response = await DefaultApi(dio).getGlossary(
      lang: Language.ko,
      ifNoneMatch: '"g1"',
      validateStatus: (status) => status == 200 || status == 304,
    );

    expect(response.statusCode, 304);
    expect(response.data, isNull);
  });
}
