import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/apple_login_request.dart';
import 'package:myungli_diary/core/api/gen/model/apple_web_login_request.dart';
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/kakao_login_request.dart';
import 'package:myungli_diary/core/api/gen/model/language.dart';
import 'package:myungli_diary/core/api/gen/model/login_response.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:myungli_diary/core/api/gen/model/me.dart';
import 'package:myungli_diary/core/api/gen/model/profile_response.dart';
import 'package:myungli_diary/core/api/gen/model/token_pair.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/nonce.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/social_auth.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/device_flags.dart';
import 'package:myungli_diary/core/storage/secure_store.dart';
import 'package:myungli_diary/features/auth/application/login_completing.dart';
import 'package:myungli_diary/features/auth/application/login_controller.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_completer.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/features/onboarding/model/onboarding_draft.dart';

/// `createProfile` 성공 응답(fixture `member`).
final Map<String, dynamic> _createdProfile =
    (jsonDecode(File('fixtures/member/createProfile.json').readAsStringSync())
            as Map<String, dynamic>)['body']
        as Map<String, dynamic>;

/// 프로필을 만들 만큼 다 받은 온보딩 입력(한국 기기).
final _completeDraft = OnboardingDraft(
  honorific: '별님',
  calendar: CalendarType.solar,
  date: LunarOrSolarDate(year: 1990, month: 5, day: 15),
  time: BirthTime(status: BirthTimeStatusEnum.known, value: '14:30'),
  gender: BirthGenderEnum.female,
);

final _tokens = TokenPair(
  accessToken: 'login-access-token',
  accessTokenExpiresAt: DateTime.utc(2026, 10, 13, 1),
  refreshToken: 'login-refresh-token',
  refreshTokenExpiresAt: DateTime.utc(2026, 11, 12),
);

LoginResponse _login({required bool isNewAccount, bool? consentRequired}) =>
    LoginResponse(
      tokens: _tokens,
      isNewAccount: isNewAccount,
      consentRequired: consentRequired ?? isNewAccount,
    );

Me _me({required bool hasProfile, bool consentRequired = false}) =>
    Me.fromJson({
      'accountId': '0b3f6a9e-6c1d-4f43-9a52-3c1e7d2b8a10',
      'consentRequired': consentRequired,
      'requiredConsents': <Object?>[],
      'hasProfile': hasProfile,
      'adFree': {'active': false},
      'insight': {'active': false},
    });

DioException _problem(int status, String code) {
  final options = RequestOptions();
  return DioException.badResponse(
    statusCode: status,
    requestOptions: options,
    response: Response(
      requestOptions: options,
      statusCode: status,
      data: {'code': code, 'status': status, 'traceId': 'test'},
      headers: Headers.fromMap({
        Headers.contentTypeHeader: ['application/problem+json'],
      }),
    ),
  );
}

/// 로그인 요청을 기록하는 server 대역.
class _FakeApi implements DefaultApi {
  new({
    this.isNewAccount = true,
    this.consentRequired,
    this.hasProfile = false,
    this.kakaoProblem,
    this.getMeFails = false,
    List<String> webProblems = const [],
  }) : _webProblems = [...webProblems];

  final bool isNewAccount;

  /// 로그인 응답의 `consentRequired`. null이면 새 계정일 때만 true입니다.
  final bool? consentRequired;
  final bool hasProfile;

  /// true면 getMe가 503으로 실패합니다.
  final bool getMeFails;

  /// 카카오 로그인이 낼 problem code. null이면 성공.
  final String? kakaoProblem;

  /// Apple 웹 로그인 응답에 차례로 쓸 problem code. 다 쓰면 성공.
  final List<String> _webProblems;

  final kakaoRequests = <KakaoLoginRequest>[];
  final appleRequests = <AppleLoginRequest>[];
  final webRequests = <AppleWebLoginRequest>[];
  int getMeCalls = 0;

  /// 카카오 응답을 늦출 때 씁니다(동시 요청 확인).
  Completer<void>? kakaoGate;

  Response<T> _ok<T>(T data) =>
      Response(requestOptions: RequestOptions(), data: data);

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
    kakaoRequests.add(kakaoLoginRequest);
    await kakaoGate?.future;
    final problem = kakaoProblem;
    if (problem != null) {
      throw _problem(
        problem == 'auth.provider_unavailable' ? 503 : 401,
        problem,
      );
    }
    return _ok(
      _login(isNewAccount: isNewAccount, consentRequired: consentRequired),
    );
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
    appleRequests.add(appleLoginRequest);
    return _ok(
      _login(isNewAccount: isNewAccount, consentRequired: consentRequired),
    );
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
    webRequests.add(appleWebLoginRequest);
    if (_webProblems.isNotEmpty) {
      throw _problem(401, _webProblems.removeAt(0));
    }
    return _ok(
      _login(isNewAccount: isNewAccount, consentRequired: consentRequired),
    );
  }

  @override
  Future<Response<Me>> getMe({
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    getMeCalls++;
    if (getMeFails) {
      throw _problem(503, 'server.unavailable');
    }
    return _ok(_me(hasProfile: hasProfile));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// 쓰기가 늘 실패하는 보안 저장소(토큰 저장 실패).
class _FailingSecureStore implements SecureStore {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async =>
      throw StateError('keychain unavailable');

  @override
  Future<void> delete(String key) async {}
}

/// 진입 갱신 횟수를 세는 대역.
class _FakeEntry extends EntryController {
  new(this.log);

  final _EntryLog log;

  @override
  Future<EntrySnapshot> build() async =>
      const EntrySnapshot(EntryState.signedOut, null);

  @override
  Future<AppError?> refresh() async {
    log.refreshes++;
    log.onRefresh?.call();
    final error = log.refreshError;
    final me = log.me;
    if (error == null && me != null) {
      // 진입 계산이 내 정보를 내는 것을 흉내 냅니다(meProvider의 출처).
      state = AsyncData(EntrySnapshot(EntryState.profileRequired, me));
    }
    return error;
  }
}

/// [_FakeEntry]의 호출 기록과 응답 설정. Notifier에 공개 필드를 두지 않으려고 따로 둡니다.
class _EntryLog {
  int refreshes = 0;

  /// 갱신 직전에 부르는 기록(순서 확인용).
  void Function()? onRefresh;

  /// 갱신 결과. null이면 성공입니다.
  AppError? refreshError;

  /// 갱신이 낼 내 정보. null이면 내지 않습니다.
  Me? me;
}

/// [_FakeDraft]의 호출 기록.
class _DraftLog {
  int clears = 0;
}

/// 온보딩 입력 대역. [clear] 횟수를 셉니다.
class _FakeDraft extends OnboardingDraftController {
  new(this._initial, this.log);

  final OnboardingDraft _initial;
  final _DraftLog log;

  @override
  Future<OnboardingDraft> build() async => _initial;

  @override
  Future<void> clear() async {
    log.clears++;
    state = const AsyncData(OnboardingDraft());
  }
}

/// 프로필 저장 대역의 호출 기록과 응답 설정.
class _ProfileLog {
  int creates = 0;

  /// 저장이 던질 오류. null이면 성공입니다.
  AppError? createError;
}

final class _Harness {
  new({
    required this.profile,
    required this.flags,
    required this.container,
    required this.api,
    required this.kakao,
    required this.appleNative,
    required this.appleWeb,
    required this.crashReporter,
    required this.entry,
    required this.draft,
  });

  final ProviderContainer container;
  final _FakeApi api;
  final FakeKakaoAuth kakao;
  final FakeAppleNativeAuth appleNative;
  final FakeAppleWebAuth appleWeb;
  final FakeCrashReporter crashReporter;

  LoginController get controller =>
      container.read(loginControllerProvider.notifier);

  final _EntryLog entry;
  final _DraftLog draft;
  final _ProfileLog profile;
  final DeviceFlagsStore flags;

  String? get accessToken => container.read(tokenStoreProvider).accessToken;
}

Future<_Harness> _harness({
  _FakeApi? api,
  FakeKakaoAuth? kakao,
  FakeAppleWebAuth? appleWeb,
  FakeAppleNativeAuth? appleNative,
  SecureStore? secureStore,
  TargetPlatform platform = TargetPlatform.android,
  OnboardingDraft draft = const OnboardingDraft(),
  AppError? createProfileError,
  Me? meAfterLogin,
}) async {
  final server = api ?? _FakeApi();
  final kakaoAuth = kakao ?? FakeKakaoAuth();
  final native = appleNative ?? FakeAppleNativeAuth();
  final crashReporter = FakeCrashReporter();
  final web = appleWeb ?? FakeAppleWebAuth();
  final entryLog = _EntryLog()..me = meAfterLogin;
  final draftLog = _DraftLog();
  final profileLog = _ProfileLog()..createError = createProfileError;
  final database = AppDatabase.forExecutor(NativeDatabase.memory());
  addTearDown(database.close);
  final flags = DeviceFlagsStore(database);
  late final ProviderContainer container;
  container = ProviderContainer(
    overrides: [
      restClientProvider.overrideWithValue(server),
      secureStoreProvider.overrideWithValue(secureStore ?? MemorySecureStore()),
      crashReporterProvider.overrideWithValue(crashReporter),
      kakaoAuthProvider.overrideWithValue(kakaoAuth),
      appleNativeAuthProvider.overrideWithValue(native),
      appleWebAuthProvider.overrideWithValue(web),
      targetPlatformProvider.overrideWithValue(platform),
      entryStateProvider.overrideWith(() => _FakeEntry(entryLog)),
      onboardingDraftProvider.overrideWith(() => _FakeDraft(draft, draftLog)),
      onboardingCompleterProvider.overrideWithValue(
        OnboardingCompleter(
          createProfile: (_) async {
            profileLog.creates++;
            final error = profileLog.createError;
            if (error != null) {
              throw error;
            }
            return ProfileResponse.fromJson(_createdProfile);
          },
          readDraft: () => container.read(onboardingDraftProvider.future),
          clearDraft: () =>
              container.read(onboardingDraftProvider.notifier).clear(),
          language: Language.ko,
          deviceRegionIsKorea: true,
          deviceTimezone: () async => 'Asia/Seoul',
          flags: flags,
          needsProfile: () => container.read(meProvider)?.hasProfile == false,
          refreshEntry: () =>
              container.read(entryStateProvider.notifier).refresh(),
          crashReporter: crashReporter,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  // autoDispose controller를 테스트 동안 붙들어 둡니다.
  container.listen(loginControllerProvider, (_, _) {});
  await container.read(onboardingDraftProvider.future);
  return _Harness(
    container: container,
    api: server,
    kakao: kakaoAuth,
    appleNative: native,
    appleWeb: web,
    crashReporter: crashReporter,
    entry: entryLog,
    draft: draftLog,
    profile: profileLog,
    flags: flags,
  );
}

void main() {
  group('카카오', () {
    test('원문 nonce(32자)는 server에, 해시는 제공자에 보내고 토큰 저장 뒤 진입을 갱신합니다', () async {
      final h = await _harness();

      final outcome = await h.controller.signInWithKakao();

      expect(outcome, isA<LoginSucceeded>());
      final request = h.api.kakaoRequests.single;
      expect(request.nonce, hasLength(32));
      expect(h.kakao.providerNonces.single, hashNonce(request.nonce));
      expect(request.idToken, 'fake-kakao-id-token');
      expect(h.accessToken, 'login-access-token');
      expect(h.entry.refreshes, 1);
    });

    test('시도마다 새 nonce를 만듭니다', () async {
      final h = await _harness();

      await h.controller.signInWithKakao();
      await h.controller.signInWithKakao();

      final nonces = h.api.kakaoRequests.map((r) => r.nonce).toList();
      expect(nonces, hasLength(2));
      expect(nonces.first, isNot(nonces.last));
    });

    test('adapter가 취소하면 LoginCancelled이고 server를 부르지 않습니다', () async {
      final h = await _harness(
        kakao: FakeKakaoAuth(failWith: const SocialSignInCancelled()),
      );

      final outcome = await h.controller.signInWithKakao();

      expect(outcome, isA<LoginCancelled>());
      expect(h.api.kakaoRequests, isEmpty);
      expect(h.entry.refreshes, 0);
    });

    test('adapter가 AppError로 실패하면 LoginFailed입니다', () async {
      final h = await _harness(
        kakao: FakeKakaoAuth(failWith: const OfflineError()),
      );

      final outcome = await h.controller.signInWithKakao();

      expect((outcome as LoginFailed).error, isA<OfflineError>());
      expect(h.api.kakaoRequests, isEmpty);
    });

    test('AppError가 아닌 실패는 요약만 보고하고 LoginFailed(UnexpectedError)입니다', () async {
      final h = await _harness(secureStore: _FailingSecureStore());

      final outcome = await h.controller.signInWithKakao();

      expect((outcome as LoginFailed).error, isA<UnexpectedError>());
      final reported = h.crashReporter.errors.single;
      expect(reported.errorType, 'StateError');
      expect(reported.code, isNull);
      expect(h.entry.refreshes, 0);
    });

    test('AppError 실패는 보고하지 않습니다(화면이 안내함)', () async {
      final h = await _harness(
        api: _FakeApi(kakaoProblem: 'auth.provider_token_invalid'),
      );

      await h.controller.signInWithKakao();

      expect(h.crashReporter.errors, isEmpty);
    });

    test('503 auth.provider_unavailable이면 LoginFailed이고 토큰이 없습니다', () async {
      final h = await _harness(
        api: _FakeApi(kakaoProblem: 'auth.provider_unavailable'),
      );

      final outcome = await h.controller.signInWithKakao();

      final error = (outcome as LoginFailed).error as ProblemError;
      expect(error.code, 'auth.provider_unavailable');
      expect(error.status, 503);
      expect(h.accessToken, isNull);
      expect(h.entry.refreshes, 0);
    });

    test('토큰 저장 뒤 진입 계산이 실패하면 그 오류로 LoginFailed입니다', () async {
      final h = await _harness();
      h.entry.refreshError = const OfflineError();

      final outcome = await h.controller.signInWithKakao();

      expect(outcome, isA<LoginFailed>());
      expect((outcome as LoginFailed).error, isA<OfflineError>());
      expect(h.entry.refreshes, 1);
      // 토큰은 저장돼 다시 누르면 새로 로그인하고 진입을 다시 계산합니다.
      expect(h.accessToken, isNotNull);
    });

    test('처리 중에 다시 불러도 요청은 한 번입니다', () async {
      final api = _FakeApi()..kakaoGate = Completer<void>();
      final h = await _harness(api: api);

      final first = h.controller.signInWithKakao();
      final second = h.controller.signInWithKakao();
      api.kakaoGate!.complete();
      await Future.wait([first, second]);

      expect(api.kakaoRequests, hasLength(1));
      expect(h.kakao.providerNonces, hasLength(1));
      expect(h.entry.refreshes, 1);
    });
  });

  group('Apple', () {
    test(
      'Android는 웹 흐름의 교환 코드와 원문 nonce로 completeAppleWebLogin을 부릅니다',
      () async {
        final h = await _harness();

        final outcome = await h.controller.signInWithApple();

        expect(outcome, isA<LoginSucceeded>());
        expect(h.api.appleRequests, isEmpty);
        final request = h.api.webRequests.single;
        expect(request.exchangeCode, FakeAppleWebAuth.fakeAppleExchangeCode);
        expect(request.nonce, hasLength(32));
        expect(
          h.appleWeb.openedUris.single.queryParameters['nonce'],
          hashNonce(request.nonce),
        );
        expect(h.accessToken, 'login-access-token');
        expect(h.entry.refreshes, 1);
      },
    );

    test('iOS는 native 자격과 원문 nonce로 loginApple을 부릅니다', () async {
      final h = await _harness(platform: TargetPlatform.iOS);

      final outcome = await h.controller.signInWithApple();

      expect(outcome, isA<LoginSucceeded>());
      expect(h.api.webRequests, isEmpty);
      expect(h.appleWeb.openedUris, isEmpty);
      final request = h.api.appleRequests.single;
      expect(request.idToken, 'fake-apple-id-token');
      expect(request.authorizationCode, 'fake-apple-authorization-code');
      expect(h.appleNative.providerNonces.single, hashNonce(request.nonce));
    });

    test('iOS native가 취소하면 LoginCancelled이고 server를 부르지 않습니다', () async {
      final h = await _harness(
        platform: TargetPlatform.iOS,
        appleNative: FakeAppleNativeAuth(
          failWith: const SocialSignInCancelled(),
        ),
      );

      final outcome = await h.controller.signInWithApple();

      expect(outcome, isA<LoginCancelled>());
      expect(h.api.appleRequests, isEmpty);
      expect(h.entry.refreshes, 0);
    });

    test(
      'Android 웹 복귀가 취소면 AppleWebFailed(userCancelled)이고 server를 부르지 않습니다',
      () async {
        final h = await _harness(
          appleWeb: FakeAppleWebAuth(
            returnQuery: const {'error': 'user_cancelled_authorize'},
          ),
        );

        final outcome = await h.controller.signInWithApple();

        expect((outcome as AppleWebFailed).error, AppleWebError.userCancelled);
        expect(h.api.webRequests, isEmpty);
        expect(h.accessToken, isNull);
      },
    );

    test(
      '복귀 state가 다르면 server를 부르지 않고 AppleWebFailed(stateMismatch)입니다',
      () async {
        final h = await _harness(
          appleWeb: FakeAppleWebAuth(returnedState: 'forged'),
        );

        final outcome = await h.controller.signInWithApple();

        expect((outcome as AppleWebFailed).error, AppleWebError.stateMismatch);
        expect(h.api.webRequests, isEmpty);
        expect(h.accessToken, isNull);
        expect(h.entry.refreshes, 0);
      },
    );

    test(
      'auth.exchange_invalid면 같은 코드로 다시 보내지 않고, 다음 시도는 새 nonce·새 authorize입니다',
      () async {
        final h = await _harness(
          api: _FakeApi(webProblems: ['auth.exchange_invalid']),
        );

        final failed = await h.controller.signInWithApple();

        expect(
          ((failed as LoginFailed).error as ProblemError).code,
          'auth.exchange_invalid',
        );
        expect(h.api.webRequests, hasLength(1));
        expect(h.appleWeb.openedUris, hasLength(1));
        expect(h.accessToken, isNull);

        final retried = await h.controller.signInWithApple();

        expect(retried, isA<LoginSucceeded>());
        expect(h.appleWeb.openedUris, hasLength(2));
        expect(h.api.webRequests, hasLength(2));
        final nonces = h.api.webRequests.map((r) => r.nonce).toList();
        expect(nonces.first, isNot(nonces.last));
        expect(
          h.appleWeb.openedUris.last.queryParameters['nonce'],
          hashNonce(nonces.last),
        );
      },
    );
  });

  group('사주가 저장된 계정과 온보딩 입력', () {
    const draft = OnboardingDraft(honorific: '별님');

    test('입력이 있으면 안내를 보인 뒤 입력을 지우고 진입을 갱신합니다', () async {
      final h = await _harness(
        api: _FakeApi(isNewAccount: false, hasProfile: true),
        draft: draft,
      );
      final order = <String>[];
      h.entry.onRefresh = () => order.add('refresh');

      final outcome = await h.controller.signInWithKakao(
        showDiscardNotice: () async {
          order.add('notice(clears=${h.draft.clears})');
        },
      );

      expect(outcome, isA<LoginSucceeded>());
      expect(order, ['notice(clears=0)', 'refresh']);
      expect(h.draft.clears, 1);
    });

    test('입력이 없으면 안내 없이 진입을 갱신합니다', () async {
      final h = await _harness(
        api: _FakeApi(isNewAccount: false, hasProfile: true),
      );
      var notices = 0;

      await h.controller.signInWithKakao(
        showDiscardNotice: () async => notices++,
      );

      expect(notices, 0);
      expect(h.draft.clears, 0);
      expect(h.entry.refreshes, 1);
    });

    test('새 계정이면 입력을 남깁니다(약관 동의 뒤 프로필 저장에 씀)', () async {
      final h = await _harness(draft: draft);
      var notices = 0;

      await h.controller.signInWithKakao(
        showDiscardNotice: () async => notices++,
      );

      expect(notices, 0);
      expect(h.draft.clears, 0);
      expect(h.api.getMeCalls, 0);
    });

    test('사주 확인(getMe)이 실패하면 안내 없이 입력을 남기고 세션을 유지한 채 진입합니다', () async {
      final h = await _harness(
        api: _FakeApi(isNewAccount: false, getMeFails: true),
        draft: draft,
      );
      var notices = 0;

      final outcome = await h.controller.signInWithKakao(
        showDiscardNotice: () async => notices++,
      );

      expect(outcome, isA<LoginSucceeded>());
      expect(h.api.getMeCalls, 1);
      expect(notices, 0);
      expect(h.draft.clears, 0);
      expect(h.accessToken, 'login-access-token');
      expect(h.entry.refreshes, 1);
    });

    test('기존 계정이라도 사주가 없으면 입력을 남깁니다', () async {
      final h = await _harness(
        api: _FakeApi(isNewAccount: false),
        draft: draft,
      );
      var notices = 0;

      await h.controller.signInWithKakao(
        showDiscardNotice: () async => notices++,
      );

      expect(notices, 0);
      expect(h.draft.clears, 0);
      expect(h.entry.refreshes, 1);
    });
  });

  group('동의했고 사주가 없는 계정', () {
    final noProfile = _me(hasProfile: false);

    test('동의했고 사주가 없고 입력이 다 있으면 저장하고 진입을 다시 계산한다', () async {
      final h = await _harness(
        api: _FakeApi(isNewAccount: false),
        draft: _completeDraft,
        meAfterLogin: noProfile,
      );

      final outcome = await h.controller.signInWithKakao();

      expect(outcome, isA<LoginSucceeded>());
      expect(h.profile.creates, 1);
      expect(await h.flags.readBool(notifyAskPendingKey), isTrue);
      expect(h.draft.clears, 1);
      // 로그인의 진입 계산 한 번, 저장 마지막의 진입 계산 한 번입니다.
      expect(h.entry.refreshes, 2);
    });

    test('입력이 없으면 저장하지 않는다', () async {
      final h = await _harness(
        api: _FakeApi(isNewAccount: false),
        meAfterLogin: noProfile,
      );

      await h.controller.signInWithKakao();

      expect(h.profile.creates, 0);
      expect(await h.flags.readBool(notifyAskPendingKey), isFalse);
      expect(h.entry.refreshes, 1);
    });

    test('저장이 422면 안내를 남기고 진입을 다시 계산한다', () async {
      const rejected = ProblemError(
        code: 'name.invalid',
        status: 422,
        fieldErrors: [],
        traceId: 'test',
      );
      final h = await _harness(
        api: _FakeApi(isNewAccount: false),
        draft: _completeDraft,
        createProfileError: rejected,
        meAfterLogin: noProfile,
      );

      final outcome = await h.controller.signInWithKakao();

      expect(outcome, isA<LoginSucceeded>());
      expect(h.profile.creates, 1);
      expect(h.container.read(onboardingRejectionNoticeProvider), rejected);
      expect(h.draft.clears, 0);
      expect(h.entry.refreshes, 2);
    });

    test('그 밖의 저장 실패는 안내 없이 onboard-call에 맡깁니다', () async {
      final h = await _harness(
        api: _FakeApi(isNewAccount: false),
        draft: _completeDraft,
        createProfileError: const ProblemError(
          code: 'server.unavailable',
          status: 503,
          fieldErrors: [],
          traceId: 'test',
        ),
        meAfterLogin: noProfile,
      );

      final outcome = await h.controller.signInWithKakao();

      expect(outcome, isA<LoginSucceeded>());
      expect(h.profile.creates, 1);
      expect(h.container.read(onboardingRejectionNoticeProvider), isNull);
      expect(h.entry.refreshes, 2);
    });

    test('동의가 필요한 계정은 저장하지 않는다', () async {
      final h = await _harness(
        api: _FakeApi(consentRequired: true),
        draft: _completeDraft,
        meAfterLogin: _me(hasProfile: false, consentRequired: true),
      );

      await h.controller.signInWithKakao();

      expect(h.profile.creates, 0);
      expect(h.entry.refreshes, 1);
    });

    test('사주가 있는 계정은 저장하지 않는다', () async {
      final h = await _harness(
        api: _FakeApi(isNewAccount: false, hasProfile: true),
        draft: _completeDraft,
        meAfterLogin: _me(hasProfile: true),
      );

      await h.controller.signInWithKakao(showDiscardNotice: () async {});

      expect(h.profile.creates, 0);
      expect(h.draft.clears, 1);
      expect(h.entry.refreshes, 1);
    });
    test('저장하는 동안 라우터 보류를 켜고, 끝나면 끕니다', () async {
      final h = await _harness(
        api: _FakeApi(isNewAccount: false),
        draft: _completeDraft,
        meAfterLogin: noProfile,
      );
      final holds = <bool>[];
      h.entry.onRefresh = () =>
          holds.add(h.container.read(loginCompletingProvider));

      await h.controller.signInWithKakao();

      // 진입 계산(로그인), 저장 마지막의 진입 계산 모두 보류 중에 돕니다.
      expect(holds, [true, true]);
      expect(h.container.read(loginCompletingProvider), isFalse);
    });

    test('진입 계산이 실패해도 라우터 보류를 끕니다', () async {
      final h = await _harness(
        api: _FakeApi(isNewAccount: false),
        draft: _completeDraft,
        meAfterLogin: noProfile,
      );
      h.entry.refreshError = const OfflineError();

      final outcome = await h.controller.signInWithKakao();

      expect(outcome, isA<LoginFailed>());
      expect(h.profile.creates, 0);
      expect(h.container.read(loginCompletingProvider), isFalse);
    });

    test('저장이 예상 밖 오류로 실패해도 라우터 보류를 끄고 진입을 다시 계산한다', () async {
      final h = await _harness(
        api: _FakeApi(isNewAccount: false),
        draft: _completeDraft,
        createProfileError: UnexpectedError(StateError('boom')),
        meAfterLogin: noProfile,
      );

      await h.controller.signInWithKakao();

      expect(h.container.read(loginCompletingProvider), isFalse);
      expect(h.entry.refreshes, 2);
    });

    test('동의가 필요한 계정은 라우터 보류를 켜지 않는다', () async {
      final h = await _harness(
        api: _FakeApi(consentRequired: true),
        draft: _completeDraft,
        meAfterLogin: _me(hasProfile: false, consentRequired: true),
      );
      final holds = <bool>[];
      h.entry.onRefresh = () =>
          holds.add(h.container.read(loginCompletingProvider));

      await h.controller.signInWithKakao();

      expect(holds, [false]);
    });
  });
}
