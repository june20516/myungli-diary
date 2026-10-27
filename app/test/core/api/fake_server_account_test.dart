import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/fake/scenario.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/link_identity_request.dart';
import 'package:myungli_diary/core/api/gen/model/login_provider.dart';
import 'package:myungli_diary/core/api/gen/model/merge_preview_request.dart';
import 'package:myungli_diary/core/api/gen/model/merge_profile.dart';
import 'package:myungli_diary/core/api/gen/model/merge_request.dart';

const _nonce = 'raw-nonce-0123456789';

Future<DefaultApi> _apiOf(String scenarioId) async {
  final scenario = (await loadScenarios(rootBundle))
      .singleWhere((s) => s.id == scenarioId);
  return DefaultApi(
    Dio(BaseOptions(baseUrl: 'http://localhost:8080'))
      ..interceptors.add(
        FakeServerInterceptor(scenario: scenario, bundle: rootBundle),
      ),
  );
}

Future<String> _codeOf(Future<Object?> Function() call) async {
  try {
    await call();
  } on DioException catch (e) {
    return (appErrorFrom(e) as ProblemError).code;
  }
  throw StateError('오류가 나야 합니다.');
}

Future<List<LoginProvider>> _providers(DefaultApi api) async => [
  for (final item in (await api.listIdentities()).data!.items) item.provider,
];

Future<int?> _link(DefaultApi api, LoginProvider provider) => api
    .linkIdentity(
      provider: provider,
      linkIdentityRequest: LinkIdentityRequest(idToken: 't', nonce: _nonce),
    )
    .then((r) => r.statusCode);

Future<int?> _preview(DefaultApi api, LoginProvider provider) => api
    .previewMerge(
      mergePreviewRequest: MergePreviewRequest(
        provider: provider,
        idToken: 't',
        nonce: _nonce,
      ),
    )
    .then((r) => r.statusCode);

Future<int?> _merge(DefaultApi api) => api
    .mergeAccounts(
      mergeRequest: MergeRequest(
        mergeToken: 'token',
        profile: MergeProfile.current,
      ),
      idempotencyKey: 'key',
    )
    .then((r) => r.statusCode);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('연결 목록', () {
    test('처음 목록은 kakao 하나입니다', () async {
      final api = await _apiOf('member');
      expect(await _providers(api), [LoginProvider.kakao]);
    });

    test('google 붙이기는 409 auth.identity_in_use입니다', () async {
      final api = await _apiOf('member');
      expect(
        await _codeOf(() => _link(api, LoginProvider.google)),
        'auth.identity_in_use',
      );
      expect(await _providers(api), [LoginProvider.kakao]);
    });

    test('다른 제공자는 201로 붙고, 다시 붙이면 200입니다', () async {
      final api = await _apiOf('member');
      expect(await _link(api, LoginProvider.line), 201);
      expect(await _link(api, LoginProvider.line), 200);
      expect(await _providers(api), [LoginProvider.kakao, LoginProvider.line]);
    });

    test('떼면 목록에서 빠지고 마지막 하나는 409 auth.last_identity입니다', () async {
      final api = await _apiOf('member');
      await _link(api, LoginProvider.apple);
      final removed = await api.unlinkIdentity(provider: LoginProvider.kakao);
      expect(removed.statusCode, 204);
      expect(await _providers(api), [LoginProvider.apple]);
      expect(
        await _codeOf(() => api.unlinkIdentity(provider: LoginProvider.apple)),
        'auth.last_identity',
      );
    });

    test('연결에 없는 제공자를 떼면 404 auth.identity_not_found입니다', () async {
      final api = await _apiOf('member');
      expect(
        await _codeOf(() => api.unlinkIdentity(provider: LoginProvider.line)),
        'auth.identity_not_found',
      );
    });
  });

  group('합치기 인증', () {
    test('처음엔 kakao가 같은 계정이라 422 merge.same_account입니다', () async {
      final api = await _apiOf('member');
      expect(
        await _codeOf(() => _preview(api, LoginProvider.kakao)),
        'merge.same_account',
      );
    });

    test('붙인 뒤엔 그 제공자도 merge.same_account입니다', () async {
      final api = await _apiOf('member');
      await _link(api, LoginProvider.line);
      expect(
        await _codeOf(() => _preview(api, LoginProvider.line)),
        'merge.same_account',
      );
    });

    test('Apple은 422 merge.no_account입니다', () async {
      final api = await _apiOf('member');
      expect(
        await _codeOf(() => _preview(api, LoginProvider.apple)),
        'merge.no_account',
      );
    });

    test('연결하지 않은 LINE과 Google은 요약 200입니다', () async {
      final api = await _apiOf('member');
      for (final provider in [LoginProvider.line, LoginProvider.google]) {
        final preview = (await api.previewMerge(
          mergePreviewRequest: MergePreviewRequest(
            provider: provider,
            idToken: 't',
            nonce: _nonce,
          ),
        )).data!;
        expect(preview.mergeToken, isNotEmpty);
        expect(preview.summary.diaries, 2);
        expect(preview.summary.schedules, 0);
        expect(preview.summary.overlapDays, 1);
        expect(preview.summary.addedDays.adFree, 12);
        expect(preview.summary.current.honorific, '하늘');
        expect(preview.summary.other.honorific, '다른 계정');
      }
    });

    test('mergeAccounts는 시나리오 Me를 돌려줍니다', () async {
      final api = await _apiOf('member');
      final me = (await api.mergeAccounts(
        mergeRequest: MergeRequest(
          mergeToken: 'token',
          profile: MergeProfile.current,
        ),
        idempotencyKey: 'key',
      )).data!;
      expect(me.hasProfile, isTrue);
    });
  });

  group('합치기 시나리오', () {
    test(
      'merge-token-invalid는 mergeAccounts가 422 merge.token_invalid입니다',
      () async {
        final api = await _apiOf('merge-token-invalid');
        expect(await _codeOf(() => _merge(api)), 'merge.token_invalid');
      },
    );

    test('merge-in-progress는 처음 한 번 409 idempotency.in_progress입니다', () async {
      final api = await _apiOf('merge-in-progress');
      expect(await _codeOf(() => _merge(api)), 'idempotency.in_progress');
      expect(await _merge(api), 200);
    });
  });
}
