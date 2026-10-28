import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:myungli_diary/core/platform/auth_config.dart';
import 'package:myungli_diary/core/platform/google_auth.dart';
import 'package:myungli_diary/core/platform/nonce.dart';
import 'package:myungli_diary/core/platform/social_auth.dart';
import 'package:myungli_diary/core/platform/social_provider.dart';

const _raw = 'argument-nonce-0123456789';
const _server = 'web.apps.googleusercontent.com';
const _ios = 'ios.apps.googleusercontent.com';

AuthConfig _config({String server = _server, String ios = _ios}) => AuthConfig(
  kakaoNativeAppKey: '',
  lineChannelId: '',
  googleIosClientId: ios,
  googleServerClientId: server,
  appleServicesId: '',
  appleRedirectUri: '',
  appLinkHost: '',
);

/// 부른 순서와 인자를 남기는 SDK 경계 대역.
final class _FakeGoogleApi implements GoogleSignInApi {
  final List<({String? clientId, String serverClientId, String nonce})> inits =
      [];
  final List<String> calls = [];
  Completer<void>? initGate;
  Exception? initError;
  Exception? authError;
  String? idToken = 'google-id-token';
  Exception? signOutError;

  @override
  Future<void> initialize({
    required String serverClientId,
    required String nonce,
    String? clientId,
  }) async {
    calls.add('init');
    inits.add((
      clientId: clientId,
      serverClientId: serverClientId,
      nonce: nonce,
    ));
    await initGate?.future;
    if (initError case final error?) {
      initError = null;
      throw error;
    }
  }

  @override
  Future<String?> authenticate() async {
    calls.add('auth');
    if (authError case final error?) throw error;
    return idToken;
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    if (signOutError case final error?) throw error;
  }
}

void main() {
  late _FakeGoogleApi api;
  setUp(() => api = _FakeGoogleApi());

  GoogleSdkAuth auth({AuthConfig? config, bool isIos = false}) => GoogleSdkAuth(
    config: config ?? _config(),
    isIos: isIos,
    nonces: NonceGenerator(),
    api: api,
  );

  test('첫 signIn에서만 initialize하고 두 번째는 부르지 않습니다', () async {
    final google = auth();
    await google.signIn(rawNonce: _raw);
    await google.signIn(rawNonce: _raw);
    expect(api.calls, ['init', 'auth', 'signOut', 'auth', 'signOut']);
  });

  test('동시에 두 번 불러도 initialize는 한 번이고 두 credential의 rawNonce가 같습니다', () async {
    api.initGate = Completer<void>();
    final google = auth();
    final first = google.signIn(rawNonce: _raw);
    final second = google.signIn(rawNonce: _raw);
    api.initGate!.complete();
    final results = await Future.wait([first, second]);
    expect(api.inits, hasLength(1));
    expect(results[0].rawNonce, results[1].rawNonce);
  });

  test('iOS는 clientId에 iOS client id, Android는 clientId null', () async {
    await auth(isIos: true).signIn(rawNonce: _raw);
    await auth().signIn(rawNonce: _raw);
    expect(api.inits[0].clientId, _ios);
    expect(api.inits[1].clientId, isNull);
    expect(api.inits.map((init) => init.serverClientId), [_server, _server]);
  });

  test(
    'initialize의 nonce는 hashNonce(프로세스 nonce)이고 credential.rawNonce는 그 원문입니다. '
    '인자로 받은 rawNonce는 쓰지 않습니다',
    () async {
      final credential = await auth().signIn(rawNonce: _raw);
      expect(credential.idToken, 'google-id-token');
      expect(credential.rawNonce, isNot(_raw));
      expect(
        credential.rawNonce.length,
        greaterThanOrEqualTo(NonceGenerator.minLength),
      );
      expect(api.inits.single.nonce, hashNonce(credential.rawNonce));
    },
  );

  test('canceled는 SocialSignInCancelled', () async {
    api.authError = const GoogleSignInException(
      code: GoogleSignInExceptionCode.canceled,
    );
    await expectLater(
      auth().signIn(rawNonce: _raw),
      throwsA(isA<SocialSignInCancelled>()),
    );
  });

  test('그 밖의 오류는 그대로 던집니다', () async {
    const error = GoogleSignInException(
      code: GoogleSignInExceptionCode.clientConfigurationError,
    );
    api.authError = error;
    await expectLater(auth().signIn(rawNonce: _raw), throwsA(same(error)));
  });

  test('idToken이 없으면 StateError', () async {
    api.idToken = null;
    await expectLater(
      auth().signIn(rawNonce: _raw),
      throwsA(isA<StateError>()),
    );
  });

  test('성공 뒤 signOut, 실패해도 성공', () async {
    api.signOutError = Exception('signOut 실패');
    final credential = await auth().signIn(rawNonce: _raw);
    expect(credential.idToken, 'google-id-token');
    expect(api.calls.last, 'signOut');
  });

  test('설정이 없으면 ProviderNotConfigured(server id 빔, iOS는 iOS id 빔도)', () async {
    final notConfigured = isA<ProviderNotConfigured>().having(
      (e) => e.provider,
      'provider',
      SocialProvider.google,
    );
    await expectLater(
      auth(config: _config(server: '')).signIn(rawNonce: _raw),
      throwsA(notConfigured),
    );
    await expectLater(
      auth(config: _config(ios: ''), isIos: true).signIn(rawNonce: _raw),
      throwsA(notConfigured),
    );
    // Android는 iOS id가 비어도 됩니다.
    await auth(config: _config(ios: '')).signIn(rawNonce: _raw);
    expect(api.inits, hasLength(1));
  });

  test('initialize가 실패하면 다음 signIn이 다시 initialize합니다', () async {
    final initError = Exception('init 실패');
    api.initError = initError;
    final google = auth();
    await expectLater(google.signIn(rawNonce: _raw), throwsA(same(initError)));
    final credential = await google.signIn(rawNonce: _raw);
    expect(api.inits, hasLength(2));
    expect(api.inits.last.nonce, hashNonce(credential.rawNonce));
  });
}
