import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/fake/scenario.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/merge_profile.dart';
import 'package:myungli_diary/core/platform/social_provider.dart';
import 'package:myungli_diary/features/account/data/account_link_repository.dart';
import 'package:myungli_diary/features/auth/model/provider_proof.dart';

const _nonce = 'raw-nonce-0123456789';
const _exchangeCode = 'AbCdEfGhIjKlMnOpQrStUvWxYz0123456789-_AbCdE';

Future<(AccountLinkRepository, FakeServerInterceptor)> _repository({
  String scenarioId = 'member',
  Interceptor? before,
}) async {
  final scenario = (await loadScenarios(rootBundle))
      .singleWhere((s) => s.id == scenarioId);
  final server = FakeServerInterceptor(scenario: scenario, bundle: rootBundle);
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'));
  if (before != null) {
    dio.interceptors.add(before);
  }
  dio.interceptors.add(server);
  return (AccountLinkRepository(DefaultApi(dio)), server);
}

IdTokenProof _idToken(SocialProvider provider) =>
    IdTokenProof(provider: provider, idToken: 'id-token', rawNonce: _nonce);

Future<AppError> _errorOf(Future<Object?> Function() call) async {
  try {
    await call();
  } on AppError catch (e) {
    return e;
  }
  throw StateError('AppError가 나야 합니다.');
}

Object? _bodyOf(FakeServerInterceptor server, String operationId) =>
    jsonDecode(server.requestBodiesOf(operationId).single! as String);

String _codeOf(AppError error) => (error as ProblemError).code;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('link 본문', () {
    for (final provider in [SocialProvider.kakao, SocialProvider.line]) {
      test('${provider.name} id_token 증명은 idToken과 nonce만 보냅니다', () async {
        final (repository, server) = await _repository();
        await repository.link(_idToken(provider));
        expect(_bodyOf(server, 'linkIdentity'), {
          'idToken': 'id-token',
          'nonce': _nonce,
        });
      });
    }

    test('Google은 idToken과 nonce를 보냅니다(이미 다른 계정이라 409)', () async {
      final (repository, server) = await _repository();
      await _errorOf(() => repository.link(_idToken(SocialProvider.google)));
      expect(_bodyOf(server, 'linkIdentity'), {
        'idToken': 'id-token',
        'nonce': _nonce,
      });
    });

    test('Apple iOS는 idToken, authorizationCode, nonce를 보냅니다', () async {
      final (repository, server) = await _repository();
      await repository.link(
        const IdTokenProof(
          provider: SocialProvider.apple,
          idToken: 'id-token',
          authorizationCode: 'auth-code',
          rawNonce: _nonce,
        ),
      );
      expect(_bodyOf(server, 'linkIdentity'), {
        'idToken': 'id-token',
        'authorizationCode': 'auth-code',
        'nonce': _nonce,
      });
    });

    test('Apple 웹은 exchangeCode와 nonce만 보냅니다', () async {
      final (repository, server) = await _repository();
      await repository.link(
        const AppleWebExchangeProof(
          exchangeCode: _exchangeCode,
          rawNonce: _nonce,
        ),
      );
      expect(_bodyOf(server, 'linkIdentity'), {
        'exchangeCode': _exchangeCode,
        'nonce': _nonce,
      });
    });

    test(
      'authorization code 없는 Apple id_token 증명은 UnexpectedError입니다',
      () async {
        final (repository, server) = await _repository();
        final error = await _errorOf(
          () => repository.link(_idToken(SocialProvider.apple)),
        );
        expect(error, isA<UnexpectedError>());
        expect(server.callCountOf('linkIdentity'), 0);
      },
    );
  });

  group('preview 본문', () {
    for (final provider in [
      SocialProvider.kakao,
      SocialProvider.line,
      SocialProvider.google,
    ]) {
      test(
        '${provider.name} id_token 증명은 provider, idToken, nonce를 보냅니다',
        () async {
          final (repository, server) = await _repository();
          // 카카오는 이미 연결돼 있어 대역 응답이 422입니다. 본문만 확인합니다.
          try {
            await repository.preview(_idToken(provider));
          } on AppError {
            // 응답은 이 테스트의 관심이 아닙니다.
          }
          expect(_bodyOf(server, 'previewMerge'), {
            'provider': provider.name,
            'idToken': 'id-token',
            'nonce': _nonce,
          });
        },
      );
    }

    test('연결하지 않은 LINE은 합치기 토큰과 요약을 받습니다', () async {
      final (repository, _) = await _repository();
      final preview = await repository.preview(_idToken(SocialProvider.line));
      expect(preview.mergeToken, isNotEmpty);
      expect(preview.summary.diaries, 2);
    });

    test('Apple iOS는 authorizationCode까지 보냅니다', () async {
      final (repository, server) = await _repository();
      await _errorOf(
        () => repository.preview(
          const IdTokenProof(
            provider: SocialProvider.apple,
            idToken: 'id-token',
            authorizationCode: 'auth-code',
            rawNonce: _nonce,
          ),
        ),
      );
      expect(_bodyOf(server, 'previewMerge'), {
        'provider': 'apple',
        'idToken': 'id-token',
        'authorizationCode': 'auth-code',
        'nonce': _nonce,
      });
    });

    test('Apple 웹은 provider와 exchangeCode, nonce를 보냅니다', () async {
      final (repository, server) = await _repository();
      await _errorOf(
        () => repository.preview(
          const AppleWebExchangeProof(
            exchangeCode: _exchangeCode,
            rawNonce: _nonce,
          ),
        ),
      );
      expect(_bodyOf(server, 'previewMerge'), {
        'provider': 'apple',
        'exchangeCode': _exchangeCode,
        'nonce': _nonce,
      });
    });
  });

  test('IdentityList의 모르는 provider는 건너뜁니다', () async {
    final (repository, _) = await _repository(
      before: InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<Object?>(
            requestOptions: options,
            statusCode: 200,
            data: <String, Object?>{
              'items': [
                {'provider': 'kakao', 'linkedAt': '2026-10-13T00:00:00Z'},
                {'provider': 'naver', 'linkedAt': '2026-10-14T00:00:00Z'},
                {'provider': 'line', 'linkedAt': '2026-10-15T00:00:00Z'},
              ],
            },
          ),
          true,
        ),
      ),
    );
    expect(await repository.methods(), [
      SocialProvider.kakao,
      SocialProvider.line,
    ]);
  });

  test('409 auth.identity_in_use는 AppError code 그대로 던집니다', () async {
    final (repository, _) = await _repository();
    final error = await _errorOf(
      () => repository.link(_idToken(SocialProvider.google)),
    );
    expect(_codeOf(error), 'auth.identity_in_use');
  });

  test('merge는 Idempotency-Key 헤더와 {mergeToken, profile} 본문을 보냅니다', () async {
    final (repository, server) = await _repository();
    final me = await repository.merge(
      mergeToken: 'merge-token-1',
      profile: MergeProfile.other,
      idempotencyKey: 'key-1',
    );
    expect(me.hasProfile, isTrue);
    expect(_bodyOf(server, 'mergeAccounts'), {
      'mergeToken': 'merge-token-1',
      'profile': 'other',
    });
    expect(
      server.requestHeadersOf('mergeAccounts').single['idempotency-key'],
      'key-1',
    );
  });

  test('link와 unlink가 methods 목록을 바꿉니다', () async {
    final (repository, _) = await _repository();
    expect(await repository.methods(), [SocialProvider.kakao]);
    expect(await repository.link(_idToken(SocialProvider.line)), [
      SocialProvider.kakao,
      SocialProvider.line,
    ]);
    await repository.unlink(SocialProvider.kakao);
    expect(await repository.methods(), [SocialProvider.line]);
  });
}
