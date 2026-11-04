import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'relay_core.dart';

/// staging E2E relay 진입점입니다(#781). `tool/patrol_staging.sh`가 띄웁니다.
///
/// ```sh
/// gcloud secrets versions access latest --secret=TEST_LOGIN_SECRET --project=ID \
///   | dart run tool/e2e_staging/relay.dart --api-base https://api-staging.example
/// ```
///
/// 비밀은 stdin 첫 줄로만 받고(명령줄, 환경 변수, 파일에 두지 않음) 메모리에만 둡니다.
/// `127.0.0.1:47283`에만 bind하며, SIGINT, SIGTERM을 받으면 `/cleanup`과 같은 정리 뒤 끝납니다.
///
/// 종료 코드: 0 정상 종료, 2 인자 오류, 3 비밀 없음 또는 포트 사용 중.
Future<void> main(List<String> args) async {
  final apiBase = _apiBaseOf(args);
  if (apiBase == null) {
    _say('사용법: relay.dart --api-base https://...');
    exit(2);
  }

  final secret = await _readSecretLine();
  if (secret.isEmpty) {
    _say('stdin에서 비밀을 읽지 못했습니다');
    exit(3);
  }

  final HttpServer server;
  try {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, relayPort);
  } on SocketException {
    _say('127.0.0.1:$relayPort를 열지 못했습니다(이미 쓰는 중일 수 있음)');
    exit(3);
  }

  final client = http.Client();
  final relay = StagingRelay(
    apiBase: apiBase,
    secret: secret,
    client: client,
    log: _say,
  );

  var stopping = false;
  Future<void> stop(ProcessSignal signal) async {
    if (stopping) return;
    stopping = true;
    _say('$signal: 정리합니다');
    await server.close(force: true);
    final result = await relay.handle('POST', '/cleanup', null);
    _say('정리 결과 ${result.body}');
    client.close();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen(stop);
  ProcessSignal.sigterm.watch().listen(stop);

  _say('준비됨 http://127.0.0.1:$relayPort');
  await for (final request in server) {
    unawaited(_serve(relay, request));
  }
}

/// relay가 받는 포트입니다(Patrol 47281/47282, Metro 8081과 겹치지 않음).
const relayPort = 47283;

/// [request]를 [relay]로 처리해 응답합니다. 본문이 JSON이 아니면 400입니다.
Future<void> _serve(StagingRelay relay, HttpRequest request) async {
  final response = request.response;
  try {
    final text = await utf8.decodeStream(request);
    Object? body;
    var result = const RelayResponse(400, '{"error":"invalid json"}');
    var parsed = true;
    if (text.isNotEmpty) {
      try {
        body = jsonDecode(text);
      } on FormatException {
        parsed = false;
      }
    }
    if (parsed) {
      result = await relay.handle(request.method, request.uri.path, body);
    } else {
      _say('${request.method} ${request.uri.path} → ${result.status}');
    }
    response
      ..statusCode = result.status
      ..headers.contentType = ContentType.parse(result.contentType)
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
      ..add(utf8.encode(result.body));
  } on Object catch (error) {
    // 예외 내용에 요청 값이 섞일 수 있어 종류만 남깁니다.
    _say('${request.method} ${request.uri.path} → 500 (${error.runtimeType})');
    response.statusCode = HttpStatus.internalServerError;
  } finally {
    await response.close();
  }
}

/// `--api-base <url>`을 읽습니다. 없거나 http(s) 주소가 아니면 null입니다.
Uri? _apiBaseOf(List<String> args) {
  final index = args.indexOf('--api-base');
  if (index < 0 || index + 1 >= args.length) return null;
  final uri = Uri.tryParse(args[index + 1]);
  if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
    return null;
  }
  return uri;
}

/// stdin 첫 줄을 앞뒤 공백 없이 읽습니다. 없으면 빈 문자열입니다.
Future<String> _readSecretLine() async {
  final lines = await stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .take(1)
      .toList();
  return lines.isEmpty ? '' : lines.single.trim();
}

void _say(String line) => stderr.writeln('[relay] $line');
