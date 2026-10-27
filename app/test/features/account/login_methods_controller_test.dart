import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/gen/model/login_provider.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/social_auth.dart';
import 'package:myungli_diary/core/platform/social_provider.dart';
import 'package:myungli_diary/features/account/application/login_methods_controller.dart';
import 'package:myungli_diary/features/account/data/account_link_repository.dart';

import 'fake_identity_api.dart';

final class _Harness {
  new({
    required this.api,
    required this.container,
    required this.google,
    required this.kakao,
  });

  final FakeIdentityApi api;
  final ProviderContainer container;
  final FakeGoogleAuth google;
  final FakeKakaoAuth kakao;

  LoginMethodsController get controller =>
      container.read(loginMethodsControllerProvider.notifier);

  List<SocialProvider>? get methods =>
      container.read(loginMethodsControllerProvider).value;
}

Future<_Harness> _harness({
  FakeIdentityApi? api,
  FakeGoogleAuth? google,
  FakeKakaoAuth? kakao,
  FakeAppleWebAuth? appleWeb,
  List<LoginProvider>? identities,
}) async {
  final server = api ?? FakeIdentityApi(identities: identities);
  final googleAuth = google ?? FakeGoogleAuth();
  final kakaoAuth = kakao ?? FakeKakaoAuth();
  final container = ProviderContainer(
    overrides: [
      accountLinkRepositoryProvider.overrideWithValue(
        AccountLinkRepository(server),
      ),
      googleAuthProvider.overrideWithValue(googleAuth),
      kakaoAuthProvider.overrideWithValue(kakaoAuth),
      appleWebAuthProvider.overrideWithValue(appleWeb ?? FakeAppleWebAuth()),
      targetPlatformProvider.overrideWithValue(TargetPlatform.android),
    ],
  );
  addTearDown(container.dispose);
  // 화면이 보는 동안과 같이 provider를 붙들어 둡니다.
  container.listen(loginMethodsControllerProvider, (_, _) {});
  await container.read(loginMethodsControllerProvider.future);
  return _Harness(
    api: server,
    container: container,
    google: googleAuth,
    kakao: kakaoAuth,
  );
}

void main() {
  test('처음에는 연결된 제공자 목록을 읽습니다', () async {
    final h = await _harness(
      identities: [LoginProvider.kakao, LoginProvider.line],
    );
    expect(h.methods, [SocialProvider.kakao, SocialProvider.line]);
  });

  group('link', () {
    test('성공이면 응답 목록으로 갱신', () async {
      final h = await _harness();
      final outcome = await h.controller.link(SocialProvider.line);
      expect(outcome, isA<LinkDone>());
      expect(h.api.linkCalls, [LoginProvider.line]);
      expect(h.methods, [SocialProvider.kakao, SocialProvider.line]);
    });

    for (final code in ['auth.identity_in_use', 'auth.provider_taken']) {
      test('409 $code는 LinkInUse이고 목록 그대로', () async {
        final h = await _harness();
        h.api.linkError = problemOf(409, code);
        final outcome = await h.controller.link(SocialProvider.line);
        expect(outcome, isA<LinkInUse>());
        expect(h.methods, [SocialProvider.kakao]);
      });
    }

    test('401 provider_token_invalid는 LinkFailed이고 로그아웃하지 않습니다', () async {
      final h = await _harness();
      h.api.linkError = problemOf(401, 'auth.provider_token_invalid');
      final outcome = await h.controller.link(SocialProvider.line);
      expect(outcome, isA<LinkFailed>());
      expect(h.methods, [SocialProvider.kakao]);
      // 목록 상태는 오류가 아니고 값이 그대로입니다.
      expect(
        h.container.read(loginMethodsControllerProvider).hasError,
        isFalse,
      );
    });

    test('취소는 LinkFailed이고 server를 부르지 않음', () async {
      final h = await _harness(
        google: FakeGoogleAuth(failWith: const SocialSignInCancelled()),
      );
      final outcome = await h.controller.link(SocialProvider.google);
      expect(outcome, isA<LinkFailed>());
      expect(h.api.linkCalls, isEmpty);
    });

    test('Apple 웹 실패는 LinkFailed이고 server를 부르지 않음', () async {
      final h = await _harness(
        appleWeb: FakeAppleWebAuth(
          returnQuery: {'error': 'user_cancelled_authorize'},
        ),
      );
      final outcome = await h.controller.link(SocialProvider.apple);
      expect(outcome, isA<LinkFailed>());
      expect(h.api.linkCalls, isEmpty);
    });

    test('그 밖의 server 오류(AppError)는 LinkFailed', () async {
      final h = await _harness();
      h.api.linkError = problemOf(503, 'service.unavailable');
      expect(await h.controller.link(SocialProvider.line), isA<LinkFailed>());
      expect(h.methods, [SocialProvider.kakao]);
    });

    test('시도마다 새 원문 nonce를 제공자에게 보냄', () async {
      final h = await _harness();
      h.api.linkError = problemOf(409, 'auth.identity_in_use');
      await h.controller.link(SocialProvider.google);
      await h.controller.link(SocialProvider.google);
      expect(h.google.providerNonces, hasLength(2));
      expect(h.google.providerNonces[0], isNot(h.google.providerNonces[1]));
    });
  });

  group('진행 중 단일 실행', () {
    test('다시 link를 부르면 새 요청 없이 진행 중인 결과', () async {
      final h = await _harness();
      h.api.linkGate = Completer<void>();
      final first = h.controller.link(SocialProvider.line);
      await Future<void>.delayed(Duration.zero);
      final second = h.controller.link(SocialProvider.google);
      expect(identical(first, second), isTrue);
      h.api.linkGate!.complete();
      expect(await first, isA<LinkDone>());
      expect(h.api.linkCalls, [LoginProvider.line]);
    });

    test('link 진행 중 unlink를 부르면 새 요청을 보내지 않음', () async {
      final h = await _harness(
        identities: [LoginProvider.kakao, LoginProvider.line],
      );
      h.api.linkGate = Completer<void>();
      final first = h.controller.link(SocialProvider.google);
      await Future<void>.delayed(Duration.zero);
      expect(
        await h.controller.unlink(SocialProvider.line),
        isA<UnlinkFailed>(),
      );
      expect(h.api.unlinkCalls, isEmpty);
      h.api.linkGate!.complete();
      await first;
    });

    test('unlink 진행 중 다시 unlink하면 진행 중인 결과', () async {
      final h = await _harness(
        identities: [LoginProvider.kakao, LoginProvider.line],
      );
      final first = h.controller.unlink(SocialProvider.line);
      final second = h.controller.unlink(SocialProvider.kakao);
      expect(identical(first, second), isTrue);
      await first;
      expect(h.api.unlinkCalls, [LoginProvider.line]);
    });
  });

  group('unlink', () {
    test('unlinkIdentity 뒤 목록을 다시 읽고, 어느 제공자도 허가 취소를 부르지 않음(D95)', () async {
      final h = await _harness(
        identities: [LoginProvider.kakao, LoginProvider.line],
      );
      final listsBefore = h.api.listCalls;
      final outcome = await h.controller.unlink(SocialProvider.line);
      expect(outcome, isA<UnlinkDone>());
      expect(h.api.unlinkCalls, [LoginProvider.line]);
      expect(h.api.listCalls, listsBefore + 1);
      expect(h.methods, [SocialProvider.kakao]);
      // 제공자 SDK는 전혀 부르지 않습니다.
      expect(h.kakao.providerNonces, isEmpty);
      expect(h.google.providerNonces, isEmpty);
    });

    test('409 last_identity는 UnlinkFailed', () async {
      final h = await _harness();
      h.api.unlinkError = problemOf(409, 'auth.last_identity');
      expect(
        await h.controller.unlink(SocialProvider.kakao),
        isA<UnlinkFailed>(),
      );
      expect(h.methods, [SocialProvider.kakao]);
    });

    test('404 identity_not_found는 목록만 다시 읽음', () async {
      final h = await _harness(
        identities: [LoginProvider.kakao, LoginProvider.line],
      );
      h.api
        ..identities.remove(LoginProvider.line) // 다른 기기에서 이미 뗌
        ..unlinkError = problemOf(404, 'auth.identity_not_found');
      final listsBefore = h.api.listCalls;
      final outcome = await h.controller.unlink(SocialProvider.line);
      expect(outcome, isA<UnlinkDone>());
      expect(h.api.listCalls, listsBefore + 1);
      expect(h.methods, [SocialProvider.kakao]);
    });
  });

  test('refresh는 로딩 없이 목록을 다시 읽음', () async {
    final h = await _harness();
    h.api.identities.add(LoginProvider.line);
    await h.controller.refresh();
    expect(h.methods, [SocialProvider.kakao, SocialProvider.line]);
  });
}
