import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/apple_login_request.dart';
import 'package:myungli_diary/core/api/gen/model/apple_web_login_request.dart';
import 'package:myungli_diary/core/api/gen/model/google_login_request.dart';
import 'package:myungli_diary/core/api/gen/model/kakao_login_request.dart';
import 'package:myungli_diary/core/api/gen/model/line_login_request.dart';
import 'package:myungli_diary/core/api/gen/model/login_response.dart';
import 'package:myungli_diary/core/api/gen/model/token_pair.dart';
import 'package:myungli_diary/core/platform/social_provider.dart';
import 'package:myungli_diary/features/auth/application/provider_authenticator.dart';
import 'package:myungli_diary/features/auth/data/auth_repository.dart';

final _response = LoginResponse(
  tokens: TokenPair(
    accessToken: 'a',
    accessTokenExpiresAt: DateTime.utc(2026, 10, 13, 1),
    refreshToken: 'r',
    refreshTokenExpiresAt: DateTime.utc(2026, 11, 12),
  ),
  isNewAccount: false,
  consentRequired: false,
);

/// 어느 operation이 어떤 본문으로 불렸는지 기록하는 server 대역.
class _RecordingApi implements DefaultApi {
  final calls = <String, Object>{};

  Response<LoginResponse> _ok() =>
      Response(requestOptions: RequestOptions(), data: _response);

  @override
  Future<Response<LoginResponse>> loginKakao({
    required KakaoLoginRequest kakaoLoginRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    calls['loginKakao'] = kakaoLoginRequest;
    return _ok();
  }

  @override
  Future<Response<LoginResponse>> loginLine({
    required LineLoginRequest lineLoginRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    calls['loginLine'] = lineLoginRequest;
    return _ok();
  }

  @override
  Future<Response<LoginResponse>> loginGoogle({
    required GoogleLoginRequest googleLoginRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    calls['loginGoogle'] = googleLoginRequest;
    return _ok();
  }

  @override
  Future<Response<LoginResponse>> loginApple({
    required AppleLoginRequest appleLoginRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    calls['loginApple'] = appleLoginRequest;
    return _ok();
  }

  @override
  Future<Response<LoginResponse>> completeAppleWebLogin({
    required AppleWebLoginRequest appleWebLoginRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    calls['completeAppleWebLogin'] = appleWebLoginRequest;
    return _ok();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late _RecordingApi api;
  late AuthRepository repository;

  setUp(() {
    api = _RecordingApi();
    repository = AuthRepository(api);
  });

  IdTokenProof proof(SocialProvider provider, {String? authorizationCode}) =>
      IdTokenProof(
        provider: provider,
        idToken: 'id-token',
        rawNonce: 'raw-nonce',
        authorizationCode: authorizationCode,
      );

  test('IdTokenProof(kakao)는 loginKakao입니다', () async {
    await repository.login(proof(SocialProvider.kakao));

    final request = api.calls['loginKakao']! as KakaoLoginRequest;
    expect(request.idToken, 'id-token');
    expect(request.nonce, 'raw-nonce');
    expect(api.calls, hasLength(1));
  });

  test('IdTokenProof(line)은 loginLine입니다', () async {
    await repository.login(proof(SocialProvider.line));

    final request = api.calls['loginLine']! as LineLoginRequest;
    expect(request.idToken, 'id-token');
    expect(request.nonce, 'raw-nonce');
    expect(api.calls, hasLength(1));
  });

  test('IdTokenProof(google)은 loginGoogle입니다', () async {
    await repository.login(proof(SocialProvider.google));

    final request = api.calls['loginGoogle']! as GoogleLoginRequest;
    expect(request.idToken, 'id-token');
    expect(request.nonce, 'raw-nonce');
    expect(api.calls, hasLength(1));
  });

  test('IdTokenProof(apple, authorizationCode)는 loginApple입니다', () async {
    await repository.login(
      proof(SocialProvider.apple, authorizationCode: 'auth-code'),
    );

    final request = api.calls['loginApple']! as AppleLoginRequest;
    expect(request.idToken, 'id-token');
    expect(request.authorizationCode, 'auth-code');
    expect(request.nonce, 'raw-nonce');
    expect(api.calls, hasLength(1));
  });

  test('authorizationCode 없는 Apple 증명은 Future 오류이고 server를 부르지 않습니다', () async {
    final future = repository.login(proof(SocialProvider.apple));

    await expectLater(future, throwsA(isA<UnexpectedError>()));
    expect(api.calls, isEmpty);
  });

  test('AppleWebExchangeProof는 completeAppleWebLogin입니다', () async {
    await repository.login(
      const AppleWebExchangeProof(
        exchangeCode: 'exchange-code',
        rawNonce: 'raw-nonce',
      ),
    );

    final request = api.calls['completeAppleWebLogin']! as AppleWebLoginRequest;
    expect(request.exchangeCode, 'exchange-code');
    expect(request.nonce, 'raw-nonce');
    expect(api.calls, hasLength(1));
  });
}
