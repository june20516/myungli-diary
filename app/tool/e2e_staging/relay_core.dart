/// staging E2E relay(#781, 결정 A108)의 요청 처리입니다.
/// Flutter 없이 `dart run`으로 돕니다.
///
/// 에뮬레이터의 앱은 `adb reverse`로 이 relay에 닿고, relay만 staging 비밀
/// `TEST_LOGIN_SECRET`을 메모리에 들고 server의 staging 전용 경로
/// (S24 테스트 로그인, S125 광고 제거 기간)를 부릅니다.
/// 로그에는 `METHOD path → status`만 남기고 비밀, 토큰, 요청과 응답 본문은
/// 남기지 않습니다.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

/// relay가 받는 label인지 봅니다. `e2e`로 시작하는 영숫자 32자 이하입니다(테스트 로그인 label 규칙
/// `^[A-Za-z0-9]{1,32}$` 안에서 relay가 만든 계정만 건드리려고 접두를 더 봅니다).
bool isRelayLabel(String label) => _relayLabelPattern.hasMatch(label);

/// [value]가 relay label 문자열인지 봅니다.
bool _isLabelValue(Object? value) => value is String && isRelayLabel(value);

final _relayLabelPattern = RegExp(r'^e2e[A-Za-z0-9]{0,29}$');

/// relay 한 요청의 응답입니다. [body]는 staging 응답을 그대로 옮길 수 있게 문자열입니다.
final class RelayResponse {
  /// [status]와 [body], [contentType]으로 만듭니다.
  const new(this.status, this.body, {this.contentType = _jsonType});

  /// [value]를 JSON으로 담은 응답입니다.
  new json(int status, Object value) : this(status, jsonEncode(value));

  /// HTTP 상태 코드입니다.
  final int status;

  /// 응답 본문입니다.
  final String body;

  /// `Content-Type` 헤더 값입니다.
  final String contentType;
}

const _jsonType = 'application/json';

/// `/session`이 `PUT /v1/me/profile`로 보내는 고정 프로필입니다(`ProfileInput`).
/// 호칭 `별님`, 양력 1990-05-15 10:30, 여성, 시간대 `Asia/Seoul`, 출생지 묻지 않음입니다.
const fixedProfile = <String, Object>{
  'honorific': '별님',
  'language': 'ko',
  'currentTimezone': 'Asia/Seoul',
  'birth': {
    'calendar': 'solar',
    'date': {'year': 1990, 'month': 5, 'day': 15},
    'isLeapMonth': false,
    'time': {'status': 'known', 'value': '10:30'},
    'gender': 'female',
    'timezone': 'Asia/Seoul',
    'place': {'status': 'not_asked'},
  },
  'notification': {'status': 'not_asked'},
};

/// staging server를 대신 부르는 relay입니다. 실행 중 만든 label을 기억해 `/cleanup`에서 지웁니다.
///
/// * `GET /ready` → 200 `{"ok":true}`
/// * `POST /login` `{label}` → staging 테스트 로그인 응답(상태, 본문) 그대로
/// * `POST /session` `{label, profile, adFreeDays}` → 로그인, 필요하면 약관 동의, 프로필, 광고 제거 기간 뒤
///   200 `{refreshToken}`
/// * `POST /cleanup` → 기억한 label마다 로그인 뒤 `DELETE /v1/me`, 200 `{deleted, failed}`
final class StagingRelay {
  /// `apiBase`의 staging server를 `client`로 부르고, 비밀 경로에는 `secret`을 헤더로 붙입니다.
  /// [log]는 요청마다 `METHOD path → status` 한 줄을 받습니다.
  new({
    required this._apiBase,
    required this._secret,
    required this._client,
    void Function(String line)? log,
  }) : _log = log ?? _ignoreLog;

  final Uri _apiBase;
  final String _secret;
  final http.Client _client;
  final void Function(String line) _log;
  final Set<String> _labels = {};

  /// 돌고 있는 정리입니다. 정리가 겹치면 지운 label로 다시 로그인해 계정을 새로 만들 수 있어 차례로 돕니다.
  Future<void> _cleaning = Future.value();

  /// 이 실행이 staging에 보낸 label 중 아직 지우지 않은 것입니다.
  Set<String> get labels => Set.unmodifiable(_labels);

  /// [method] [path] 요청을 처리합니다. [body]는 JSON으로 읽은 요청 본문입니다(없으면 null).
  Future<RelayResponse> handle(String method, String path, Object? body) async {
    final outcome = await _routeSafely(method, path, body);
    final failedStep = outcome.failedStep;
    _log(
      '$method $path → ${outcome.response.status}'
      '${failedStep == null ? '' : ' ($failedStep)'}',
    );
    return outcome.response;
  }

  /// [_route]를 부르고, staging에 닿지 못했거나 응답이 JSON이 아니면 내용 없는 502로 바꿉니다.
  Future<_Outcome> _routeSafely(
    String method,
    String path,
    Object? body,
  ) async {
    try {
      return await _route(method, path, body);
    } on http.ClientException {
      return const _Outcome(_unreachable);
    } on FormatException {
      return const _Outcome(_unexpected);
    }
  }

  Future<_Outcome> _route(String method, String path, Object? body) async {
    switch ('$method $path') {
      case 'GET /ready':
        return _Outcome(RelayResponse.json(200, {'ok': true}));
      case 'POST /login':
        return await _login(body);
      case 'POST /session':
        return await _session(body);
      case 'POST /cleanup':
        return _Outcome(await _cleanupInTurn());
    }
    return _Outcome(RelayResponse.json(404, {'error': 'unknown route'}));
  }

  Future<_Outcome> _login(Object? body) async {
    final label = body is Map ? body['label'] : null;
    if (!_isLabelValue(label)) return const _Outcome(_badRequest);
    final response = await _testLogin(label as String);
    return _Outcome(_passThrough(response));
  }

  Future<_Outcome> _session(Object? body) async {
    final request = _SessionRequest.parse(body);
    if (request == null) return const _Outcome(_badRequest);

    final login = await _testLogin(request.label);
    if (!_ok(login)) return _Outcome(_passThrough(login));
    final loginBody = jsonDecode(login.body) as Map<String, Object?>;
    final tokens = loginBody['tokens']! as Map<String, Object?>;
    final bearer = {'Authorization': 'Bearer ${tokens['accessToken']}'};
    final consentRequired = loginBody['consentRequired'] == true;

    Map<String, Object?>? me;
    if (consentRequired || request.adFreeDays > 0) {
      final response = await _client.get(_url('/v1/me'), headers: bearer);
      if (!_ok(response)) return _failed(response, 'GET /v1/me');
      me = jsonDecode(response.body) as Map<String, Object?>;
    }

    if (consentRequired) {
      final response = await _client.post(
        _url('/v1/me/consents'),
        headers: {...bearer, ..._jsonHeaders},
        body: jsonEncode({'documents': me!['requiredConsents']}),
      );
      if (!_ok(response)) return _failed(response, 'POST /v1/me/consents');
    }

    if (request.profile) {
      final response = await _client.put(
        _url('/v1/me/profile'),
        headers: {...bearer, ..._jsonHeaders},
        body: jsonEncode(fixedProfile),
      );
      if (!_ok(response)) return _failed(response, 'PUT /v1/me/profile');
    }

    if (request.adFreeDays > 0) {
      final response = await _client.post(
        _url('/test/v1/billing/ad-free'),
        headers: {..._secretHeaders, ..._jsonHeaders},
        body: jsonEncode({
          'accountId': me!['accountId'],
          'days': request.adFreeDays,
        }),
      );
      if (!_ok(response)) {
        return _failed(response, 'POST /test/v1/billing/ad-free');
      }
    }

    return _Outcome(
      RelayResponse.json(200, {'refreshToken': tokens['refreshToken']}),
    );
  }

  /// 앞선 정리가 끝난 뒤 [_cleanup]을 돕니다.
  Future<RelayResponse> _cleanupInTurn() {
    final result = _cleaning.then((_) => _cleanup());
    _cleaning = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// 기억한 label마다 로그인해 계정을 지웁니다. 지운 label은 잊어, 다시 불러도 지운 계정을 새로
  /// 만들지 않습니다. 실패한 label은 남겨 다음 정리에서 다시 시도합니다.
  Future<RelayResponse> _cleanup() async {
    var deleted = 0;
    final failed = <String>[];
    for (final label in _labels.toList()) {
      if (await _deleteAccount(label)) {
        _labels.remove(label);
        deleted++;
      } else {
        failed.add(label);
      }
    }
    return RelayResponse.json(200, {'deleted': deleted, 'failed': failed});
  }

  Future<bool> _deleteAccount(String label) async {
    try {
      final login = await _testLogin(label);
      if (!_ok(login)) return false;
      final tokens =
          (jsonDecode(login.body) as Map<String, Object?>)['tokens']!
              as Map<String, Object?>;
      final response = await _client.delete(
        _url('/v1/me'),
        headers: {'Authorization': 'Bearer ${tokens['accessToken']}'},
      );
      return _ok(response);
    } on http.ClientException {
      return false;
    } on FormatException {
      return false;
    }
  }

  /// 테스트 로그인을 부릅니다. 부르기 전에 label을 기억해, 응답을 못 받아도 정리 대상이 됩니다.
  Future<http.Response> _testLogin(String label) {
    _labels.add(label);
    return _client.post(
      _url('/test/v1/auth/login'),
      headers: {..._secretHeaders, ..._jsonHeaders},
      body: jsonEncode({'label': label}),
    );
  }

  Uri _url(String path) => _apiBase.resolve(path);

  Map<String, String> get _secretHeaders => {'X-Test-Login-Secret': _secret};

  static const Map<String, String> _jsonHeaders = {'Content-Type': _jsonType};

  static bool _ok(http.Response response) =>
      response.statusCode >= 200 && response.statusCode < 300;

  static RelayResponse _passThrough(http.Response response) => RelayResponse(
    response.statusCode,
    response.body,
    contentType: response.headers['content-type'] ?? _jsonType,
  );

  static _Outcome _failed(http.Response response, String step) =>
      _Outcome(_passThrough(response), failedStep: step);

  static void _ignoreLog(String line) {}
}

/// 형식이 틀린 요청 응답입니다. staging을 부르지 않습니다.
const _badRequest = RelayResponse(400, '{"error":"invalid request"}');

/// staging에 닿지 못했을 때의 응답입니다. 예외 내용은 싣지 않습니다.
const _unreachable = RelayResponse(502, '{"error":"staging unreachable"}');

/// relay 응답과, staging 단계가 실패했으면 그 단계(`METHOD path`)입니다.
final class _Outcome {
  const new(this.response, {this.failedStep});

  final RelayResponse response;
  final String? failedStep;
}

/// staging 성공 응답 본문이 JSON이 아닐 때의 응답입니다. 본문은 싣지 않습니다.
const _unexpected = RelayResponse(
  502,
  '{"error":"unexpected staging response"}',
);

/// `/session` 요청 본문입니다. `profile`은 기본 false, `adFreeDays`는 기본 0입니다.
final class _SessionRequest {
  const new(this.label, {required this.profile, required this.adFreeDays});

  final String label;
  final bool profile;
  final int adFreeDays;

  /// [body]를 읽습니다. 형식이 틀리면 null입니다.
  static _SessionRequest? parse(Object? body) {
    if (body is! Map) return null;
    final label = body['label'];
    final profile = body['profile'] ?? false;
    final adFreeDays = body['adFreeDays'] ?? 0;
    if (!_isLabelValue(label) || profile is! bool) return null;
    if (adFreeDays is! int || adFreeDays < 0) return null;
    return _SessionRequest(
      label as String,
      profile: profile,
      adFreeDays: adFreeDays,
    );
  }
}
