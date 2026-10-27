import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/entry_state.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/login_provider.dart';
import 'package:myungli_diary/core/api/gen/model/me.dart';
import 'package:myungli_diary/core/api/gen/model/merge_profile.dart';
import 'package:myungli_diary/core/api/gen/model/token_pair.dart';
import 'package:myungli_diary/core/api/token_store.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/social_auth.dart';
import 'package:myungli_diary/core/platform/social_provider.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/core/storage/secure_store.dart';
import 'package:myungli_diary/features/account/application/account_merge_controller.dart';
import 'package:myungli_diary/features/account/data/account_link_repository.dart';

import 'fake_identity_api.dart';

/// 처음엔 회원 갈래이고, 받은 내 정보로 갈래를 다시 정하는 진입 대역입니다.
class _FakeEntry extends EntryController {
  /// [applyMe]로 받은 내 정보.
  final applied = <Me>[];

  @override
  Future<EntrySnapshot> build() async =>
      EntrySnapshot(EntryState.ready, mergedMe(adFree: false));

  @override
  Future<AppError?> applyMe(Me me) async {
    applied.add(me);
    state = AsyncData(
      EntrySnapshot(
        me.hasProfile ? EntryState.ready : EntryState.profileRequired,
        me,
      ),
    );
    return null;
  }
}

final _pair = TokenPair(
  accessToken: 'access-a',
  accessTokenExpiresAt: DateTime.utc(2030),
  refreshToken: 'refresh-a',
  refreshTokenExpiresAt: DateTime.utc(2031),
);

final class _Harness {
  new({
    required this.api,
    required this.container,
    required this.database,
    required this.tokens,
    required this.tokenEvents,
    required this.delays,
  });

  final FakeIdentityApi api;
  final ProviderContainer container;
  final AppDatabase database;
  final TokenStore tokens;
  final List<AuthEvent> tokenEvents;
  final List<Duration> delays;

  AccountMergeController get controller =>
      container.read(accountMergeControllerProvider.notifier);

  AccountMergeState get state => container.read(accountMergeControllerProvider);

  _FakeEntry get entry =>
      container.read(entryStateProvider.notifier) as _FakeEntry;

  /// 인증하고 [profile]을 골라 둡니다.
  Future<void> chooseAfterAuth(MergeProfile profile) async {
    expect(
      await controller.authenticate(SocialProvider.line),
      isA<MergeAuthDone>(),
    );
    controller.choose(profile);
  }
}

Future<_Harness> _harness({
  FakeIdentityApi? api,
  FakeGoogleAuth? google,
  FakeLineAuth? line,
  FakeAppleWebAuth? appleWeb,
}) async {
  final server = api ?? FakeIdentityApi();
  final database = AppDatabase.forExecutor(NativeDatabase.memory());
  addTearDown(database.close);
  final tokens = TokenStore(MemorySecureStore());
  await tokens.save(_pair);
  final events = <AuthEvent>[];
  final subscription = tokens.events.listen(events.add);
  addTearDown(subscription.cancel);
  final delays = <Duration>[];
  final container = ProviderContainer(
    overrides: [
      crashReporterProvider.overrideWithValue(FakeCrashReporter()),
      accountLinkRepositoryProvider.overrideWithValue(
        AccountLinkRepository(server),
      ),
      googleAuthProvider.overrideWithValue(google ?? FakeGoogleAuth()),
      lineAuthProvider.overrideWithValue(line ?? FakeLineAuth()),
      appleWebAuthProvider.overrideWithValue(appleWeb ?? FakeAppleWebAuth()),
      targetPlatformProvider.overrideWithValue(TargetPlatform.android),
      appDatabaseProvider.overrideWithValue(database),
      tokenStoreProvider.overrideWithValue(tokens),
      entryStateProvider.overrideWith(_FakeEntry.new),
      mergeRetryDelayProvider.overrideWithValue((duration) async {
        delays.add(duration);
      }),
    ],
  );
  addTearDown(container.dispose);
  // 화면이 보는 동안과 같이 provider를 붙들어 둡니다.
  container.listen(accountMergeControllerProvider, (_, _) {});
  await container.read(entryStateProvider.future);
  return _Harness(
    api: server,
    container: container,
    database: database,
    tokens: tokens,
    tokenEvents: events,
    delays: delays,
  );
}

/// 이 계정의 캐시와 일기 초안, 온보딩 입력, 기기 플래그를 하나씩 넣습니다.
Future<void> _seed(AppDatabase database) async {
  await CacheStore(
    database,
    accountId: mergedMe().accountId,
  ).write(CacheKind.daily, 'k', '{}', access: EvidenceAccess.unlocked);
  await database
      .into(database.diaryDrafts)
      .insert(
        DiaryDraftsCompanion.insert(
          accountId: mergedMe().accountId,
          date: '2026-10-13',
          body: '초안',
          updatedAt: DateTime.utc(2026, 10, 13),
        ),
      );
  await database
      .into(database.deviceFlags)
      .insert(DeviceFlagsCompanion.insert(key: 'ads.consent', value: '1'));
}

Future<int> _count(
  AppDatabase database,
  ResultSetImplementation<HasResultSet, Object?> table,
) async => (await database.select(table).get()).length;

void main() {
  group('authenticate', () {
    test('authenticate는 인증하고 previewMerge', () async {
      final h = await _harness();
      final outcome = await h.controller.authenticate(SocialProvider.line);
      expect(outcome, isA<MergeAuthDone>());
      expect(h.api.previewCalls, [LoginProvider.line]);
      final state = h.state as MergeChoosing;
      expect(state.preview, h.api.preview);
      expect(state.selected, isNull);
    });

    test('인증하는 동안 누른 제공자가 busy, 요약을 받는 동안 MergeSummaryLoading', () async {
      final h = await _harness();
      final gate = h.api.previewGate = Completer<void>();
      final pending = h.controller.authenticate(SocialProvider.google);
      expect(h.state, isA<MergeAuth>());
      expect((h.state as MergeAuth).busy, SocialProvider.google);
      await pumpEventQueue();
      expect(h.state, isA<MergeSummaryLoading>());
      gate.complete();
      expect(await pending, isA<MergeAuthDone>());
    });

    test('처리 중에 다시 부르면 새 요청 없이 진행 중인 결과', () async {
      final h = await _harness();
      final gate = h.api.previewGate = Completer<void>();
      final first = h.controller.authenticate(SocialProvider.line);
      final second = h.controller.authenticate(SocialProvider.google);
      gate.complete();
      expect(await second, isA<MergeAuthDone>());
      expect(await first, isA<MergeAuthDone>());
      expect(h.api.previewCalls, [LoginProvider.line]);
    });

    test('422 same_account → MergeNotOther(self)', () async {
      final h = await _harness();
      h.api.previewError = problemOf(422, 'merge.same_account');
      final outcome = await h.controller.authenticate(SocialProvider.line);
      expect(outcome, isA<MergeNotOther>());
      expect((outcome as MergeNotOther).reason, MergeNotOtherReason.self);
      expect(h.state, isA<MergeAuth>());
      expect((h.state as MergeAuth).busy, isNull);
    });

    test(
      '422 no_account → MergeNotOther(none)이고 linkIdentity를 부르지 않음',
      () async {
        final h = await _harness();
        h.api.previewError = problemOf(422, 'merge.no_account');
        final outcome = await h.controller.authenticate(SocialProvider.apple);
        expect((outcome as MergeNotOther).reason, MergeNotOtherReason.none);
        expect(h.api.linkCalls, isEmpty);
        expect(h.api.operations, ['previewMerge']);
        expect(h.state, isA<MergeAuth>());
      },
    );

    final failures = {
      '401 provider_token_invalid': problemOf(
        401,
        'auth.provider_token_invalid',
      ),
      '401 exchange_invalid': problemOf(401, 'auth.exchange_invalid'),
      '503': problemOf(503, 'service.unavailable'),
      '연결 끊김': connectionLost(),
    };
    for (final entry in failures.entries) {
      test('그 밖의 실패 → MergeAuthFailed (${entry.key})', () async {
        final h = await _harness();
        h.api.previewError = entry.value;
        expect(
          await h.controller.authenticate(SocialProvider.line),
          isA<MergeAuthFailed>(),
        );
        expect(h.state, isA<MergeAuth>());
        expect((h.state as MergeAuth).busy, isNull);
      });
    }

    test('SDK 예외도 MergeAuthFailed', () async {
      final h = await _harness(
        google: FakeGoogleAuth(failWith: Exception('sdk')),
      );
      expect(
        await h.controller.authenticate(SocialProvider.google),
        isA<MergeAuthFailed>(),
      );
      expect(h.api.previewCalls, isEmpty);
    });

    test('취소는 MergeAuthCancelled이고 server를 부르지 않음', () async {
      final h = await _harness(
        google: FakeGoogleAuth(failWith: const SocialSignInCancelled()),
      );
      expect(
        await h.controller.authenticate(SocialProvider.google),
        isA<MergeAuthCancelled>(),
      );
      expect(h.api.previewCalls, isEmpty);
      expect(h.state, isA<MergeAuth>());
    });

    test(
      'Apple 웹 취소는 MergeAuthCancelled, 그 밖의 Apple 웹 실패는 MergeAuthFailed',
      () async {
        final cancelled = await _harness(
          appleWeb: FakeAppleWebAuth(
            returnQuery: {'error': 'user_cancelled_authorize'},
          ),
        );
        expect(
          await cancelled.controller.authenticate(SocialProvider.apple),
          isA<MergeAuthCancelled>(),
        );
        final failed = await _harness(
          appleWeb: FakeAppleWebAuth(returnQuery: {'error': 'server_error'}),
        );
        expect(
          await failed.controller.authenticate(SocialProvider.apple),
          isA<MergeAuthFailed>(),
        );
        expect(failed.api.previewCalls, isEmpty);
      },
    );
  });

  group('choose', () {
    test('고른 프로필이 상태에 남음', () async {
      final h = await _harness();
      await h.chooseAfterAuth(MergeProfile.other);
      expect((h.state as MergeChoosing).selected, MergeProfile.other);
      h.controller.choose(MergeProfile.current);
      expect((h.state as MergeChoosing).selected, MergeProfile.current);
    });
  });

  group('merge', () {
    test('고르기 전이면 요청 없이 MergeFailed', () async {
      final h = await _harness();
      await h.controller.authenticate(SocialProvider.line);
      expect(await h.controller.merge(), isA<MergeFailed>());
      expect(h.api.mergeCalls, isEmpty);
    });

    test(
      'merge의 Idempotency-Key는 (mergeToken, profile) 조합마다 하나이고 같은 조합 재확정은 같은 키',
      () async {
        final h = await _harness();
        await h.chooseAfterAuth(MergeProfile.current);
        h.api.mergeAnswers.addAll([
          problemOf(503, 'service.unavailable'),
          problemOf(503, 'service.unavailable'),
          problemOf(503, 'service.unavailable'),
          problemOf(503, 'service.unavailable'),
        ]);
        expect(await h.controller.merge(), isA<MergeFailed>());
        expect(await h.controller.merge(), isA<MergeFailed>());
        h.controller.choose(MergeProfile.other);
        expect(await h.controller.merge(), isA<MergeFailed>());
        h.controller.choose(MergeProfile.current);
        expect(await h.controller.merge(), isA<MergeFailed>());

        final keys = [for (final call in h.api.mergeCalls) call.key];
        expect(keys.every((key) => key != null && key.isNotEmpty), isTrue);
        expect(keys[0], keys[1]);
        expect(keys[2], isNot(keys[0]));
        expect(keys[3], keys[0]);
        expect(
          [for (final call in h.api.mergeCalls) call.profile],
          [
            MergeProfile.current,
            MergeProfile.current,
            MergeProfile.other,
            MergeProfile.current,
          ],
        );
      },
    );

    test('토큰이 바뀌면 같은 프로필이어도 새 키', () async {
      final h = await _harness();
      await h.chooseAfterAuth(MergeProfile.current);
      h.api.mergeAnswers.add(problemOf(422, 'merge.token_invalid'));
      expect(await h.controller.merge(), isA<MergeTokenInvalid>());

      h.api.preview = mergePreview(token: 'merge-token-2');
      await h.chooseAfterAuth(MergeProfile.current);
      expect(await h.controller.merge(), isA<MergeDone>());

      final calls = h.api.mergeCalls;
      expect(calls[1].token, 'merge-token-2');
      expect(calls[1].key, isNot(calls[0].key));
    });

    test('409 idempotency.in_progress면 1초 뒤 같은 키로 다시(최대 5번)', () async {
      final h = await _harness();
      await h.chooseAfterAuth(MergeProfile.other);
      h.api.mergeAnswers.addAll([
        problemOf(409, 'idempotency.in_progress'),
        problemOf(409, 'idempotency.in_progress'),
      ]);
      expect(await h.controller.merge(), isA<MergeDone>());
      expect(h.api.mergeCalls, hasLength(3));
      expect({for (final call in h.api.mergeCalls) call.key}, hasLength(1));
      expect(h.delays, [
        const Duration(seconds: 1),
        const Duration(seconds: 1),
      ]);
    });

    test('409가 다섯 번 다시 보낸 뒤에도 이어지면 MergeFailed이고 고름 유지', () async {
      final h = await _harness();
      await h.chooseAfterAuth(MergeProfile.other);
      h.api.mergeAnswers.addAll([
        for (var i = 0; i < 6; i++) problemOf(409, 'idempotency.in_progress'),
      ]);
      expect(await h.controller.merge(), isA<MergeFailed>());
      expect(h.api.mergeCalls, hasLength(6));
      expect(h.delays, hasLength(5));
      expect((h.state as MergeChoosing).selected, MergeProfile.other);
    });

    for (final lost in {
      '연결 끊김': connectionLost,
      '시간 초과': receiveTimeout,
    }.entries) {
      test('응답 없음(${lost.key})이면 같은 토큰·본문·키로 한 번 다시', () async {
        final h = await _harness();
        await h.chooseAfterAuth(MergeProfile.other);
        h.api.mergeAnswers.add(lost.value());
        expect(await h.controller.merge(), isA<MergeDone>());
        final calls = h.api.mergeCalls;
        expect(calls, hasLength(2));
        expect(calls[1], calls[0]);
        expect(h.delays, isEmpty);
      });
    }

    test('재전송이 200이면 MergeDone(S115)', () async {
      final h = await _harness();
      await h.chooseAfterAuth(MergeProfile.current);
      final me = mergedMe();
      h.api.mergeAnswers.addAll([connectionLost(), me]);
      expect(await h.controller.merge(), isA<MergeDone>());
      expect(h.entry.applied, [me]);
    });

    test('재전송이 422 token_invalid면 MergeTokenInvalid이고 getMe를 부르지 않음', () async {
      final h = await _harness();
      await h.chooseAfterAuth(MergeProfile.current);
      h.api.mergeAnswers.addAll([
        connectionLost(),
        problemOf(422, 'merge.token_invalid'),
      ]);
      expect(await h.controller.merge(), isA<MergeTokenInvalid>());
      // FakeIdentityApi는 getMe를 구현하지 않아 부르면 기록 밖 오류가 납니다.
      expect(h.api.operations, [
        'previewMerge',
        'mergeAccounts',
        'mergeAccounts',
      ]);
      expect(h.state, isA<MergeAuth>());
      expect(h.entry.applied, isEmpty);
    });

    test('재전송도 응답이 없으면 더 보내지 않고 MergeFailed', () async {
      final h = await _harness();
      await h.chooseAfterAuth(MergeProfile.current);
      h.api.mergeAnswers.addAll([connectionLost(), receiveTimeout()]);
      expect(await h.controller.merge(), isA<MergeFailed>());
      expect(h.api.mergeCalls, hasLength(2));
      expect((h.state as MergeChoosing).selected, MergeProfile.current);
    });

    test('첫 요청 422 token_invalid도 MergeTokenInvalid', () async {
      final h = await _harness();
      await h.chooseAfterAuth(MergeProfile.current);
      h.api.mergeAnswers.add(problemOf(422, 'merge.token_invalid'));
      expect(await h.controller.merge(), isA<MergeTokenInvalid>());
      expect(h.api.mergeCalls, hasLength(1));
      expect(h.state, isA<MergeAuth>());
    });

    test('그 밖의 실패는 MergeFailed이고 고름 유지', () async {
      final h = await _harness();
      await h.chooseAfterAuth(MergeProfile.other);
      h.api.mergeAnswers.add(problemOf(500, 'internal'));
      expect(await h.controller.merge(), isA<MergeFailed>());
      final state = h.state as MergeChoosing;
      expect(state.selected, MergeProfile.other);
      expect(state.preview, h.api.preview);
    });

    test('합치는 동안 MergeRunning이고 다시 부르면 새 요청 없이 진행 중인 결과', () async {
      final h = await _harness();
      await h.chooseAfterAuth(MergeProfile.other);
      final gate = h.api.mergeGate = Completer<void>();
      final first = h.controller.merge();
      final running = h.state as MergeRunning;
      expect(running.selected, MergeProfile.other);
      final second = h.controller.merge();
      gate.complete();
      expect(await first, isA<MergeDone>());
      expect(await second, isA<MergeDone>());
      expect(h.api.mergeCalls, hasLength(1));
    });

    test('성공이면 캐시와 일기 초안을 지우고 meProvider를 응답 Me로, 진입 다시 계산', () async {
      final h = await _harness();
      await _seed(h.database);
      await h.chooseAfterAuth(MergeProfile.other);
      final me = mergedMe();
      h.api.mergeMe = me;

      expect(await h.controller.merge(), isA<MergeDone>());

      expect(await _count(h.database, h.database.cachedResponses), 0);
      expect(h.entry.applied, [me]);
      expect(h.container.read(meProvider), me);
      expect(h.container.read(entryProvider), EntryState.ready);
    });

    test('일기 초안도 지움(기기 플래그는 남음)', () async {
      final h = await _harness();
      await _seed(h.database);
      await h.chooseAfterAuth(MergeProfile.current);

      expect(await h.controller.merge(), isA<MergeDone>());

      expect(await _count(h.database, h.database.diaryDrafts), 0);
      expect(await _count(h.database, h.database.deviceFlags), 1);
    });

    test('실패 갈래에서는 캐시와 초안을 지우지 않음', () async {
      final h = await _harness();
      await _seed(h.database);
      await h.chooseAfterAuth(MergeProfile.current);
      h.api.mergeAnswers.add(problemOf(500, 'internal'));

      expect(await h.controller.merge(), isA<MergeFailed>());

      expect(await _count(h.database, h.database.cachedResponses), 1);
      expect(await _count(h.database, h.database.diaryDrafts), 1);
      expect(h.entry.applied, isEmpty);
    });
  });

  /// 성공·토큰 무효·실패·인증 실패 갈래를 모두 지납니다.
  Future<_Harness> runEveryBranch() async {
    final h = await _harness();
    h.api.previewError = problemOf(422, 'merge.same_account');
    await h.controller.authenticate(SocialProvider.line);
    h.api.previewError = problemOf(422, 'merge.no_account');
    await h.controller.authenticate(SocialProvider.line);
    h.api.previewError = null;
    await h.chooseAfterAuth(MergeProfile.current);
    h.api.mergeAnswers.addAll([
      problemOf(500, 'internal'),
      connectionLost(),
      problemOf(422, 'merge.token_invalid'),
    ]);
    await h.controller.merge();
    await h.controller.merge();
    await h.chooseAfterAuth(MergeProfile.other);
    await h.controller.merge();
    return h;
  }

  test('어느 갈래에서도 토큰 저장소를 바꾸지 않음', () async {
    final h = await runEveryBranch();
    await pumpEventQueue();
    expect(h.tokenEvents, isEmpty);
    expect(h.tokens.accessToken, _pair.accessToken);
    expect(await h.tokens.refreshToken(), _pair.refreshToken);
  });

  test('어느 갈래에서도 허가 취소를 부르지 않음(D95)', () async {
    final h = await runEveryBranch();
    expect(h.api.unlinkCalls, isEmpty);
    expect(h.api.linkCalls, isEmpty);
    expect(h.api.operations.toSet(), {'previewMerge', 'mergeAccounts'});
  });
}
