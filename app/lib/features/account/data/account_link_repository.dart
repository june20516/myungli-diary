import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/identity_list.dart';
import 'package:myungli_diary/core/api/gen/model/link_identity_request.dart';
import 'package:myungli_diary/core/api/gen/model/login_provider.dart';
import 'package:myungli_diary/core/api/gen/model/me.dart';
import 'package:myungli_diary/core/api/gen/model/merge_preview.dart';
import 'package:myungli_diary/core/api/gen/model/merge_preview_request.dart';
import 'package:myungli_diary/core/api/gen/model/merge_profile.dart';
import 'package:myungli_diary/core/api/gen/model/merge_request.dart';
import 'package:myungli_diary/core/platform/social_provider.dart';
import 'package:myungli_diary/features/auth/model/provider_proof.dart';

/// 로그인 수단 연결 목록, 붙이기, 떼기와 계정 합치기 server 요청입니다(결정 A84).
///
/// 증명을 본문으로 바꾸는 규칙은 로그인(`AuthRepository`)과 같고, nonce는 원문을 보냅니다.
/// 실패는 [AppError]입니다. 화면이 problem code로 가립니다:
/// 409 `auth.identity_in_use`·`auth.provider_taken`·`auth.last_identity`,
/// 404 `auth.identity_not_found`, 422 `merge.same_account`·`merge.no_account`·
/// `merge.token_invalid`, 409 `idempotency.in_progress`.
/// 합치기 토큰·id_token·교환 코드는 기록하지 않습니다(D64).
final class AccountLinkRepository {
  /// [_api]로 요청합니다.
  const new(this._api);

  final DefaultApi _api;

  /// 연결된 제공자를 붙인 순서로 돌려줍니다. 모르는 제공자는 건너뜁니다.
  Future<List<SocialProvider>> methods() async =>
      _providersOf(await _send(_api.listIdentities));

  /// [proof]의 제공자를 현재 계정에 붙이고 붙인 뒤의 목록을 돌려줍니다.
  Future<List<SocialProvider>> link(ProviderProof proof) async {
    final request = _linkRequestOf(proof);
    return _providersOf(
      await _send(
        () => _api.linkIdentity(
          provider: _loginProviderOf(proof.provider),
          linkIdentityRequest: request,
        ),
      ),
    );
  }

  /// 현재 계정에서 [provider] 연결을 지웁니다. 목록은 [methods]로 다시 읽습니다.
  Future<void> unlink(SocialProvider provider) async {
    try {
      await _api.unlinkIdentity(provider: _loginProviderOf(provider));
    } on DioException catch (e) {
      throw appErrorFrom(e);
    }
  }

  /// 다른 계정([proof]의 인증 계정)과 합칠 때의 요약과 합치기 토큰을 받습니다.
  Future<MergePreview> preview(ProviderProof proof) async {
    final request = _linkRequestOf(proof);
    return await _send(
      () => _api.previewMerge(
        mergePreviewRequest: MergePreviewRequest(
          provider: _loginProviderOf(proof.provider),
          idToken: request.idToken,
          authorizationCode: request.authorizationCode,
          exchangeCode: request.exchangeCode,
          nonce: request.nonce,
        ),
      ),
    );
  }

  /// [mergeToken]의 계정을 현재 계정에 합치고 합친 뒤의 [Me]를 돌려줍니다.
  ///
  /// 같은 토큰·[profile]이면 같은 [idempotencyKey]를 다시 씁니다.
  Future<Me> merge({
    required String mergeToken,
    required MergeProfile profile,
    required String idempotencyKey,
  }) async => await _send(
    () => _api.mergeAccounts(
      mergeRequest: MergeRequest(mergeToken: mergeToken, profile: profile),
      idempotencyKey: idempotencyKey,
    ),
  );

  /// 증명을 `linkIdentity`와 `previewMerge`가 같이 쓰는 본문으로 바꿉니다.
  LinkIdentityRequest _linkRequestOf(ProviderProof proof) => switch (proof) {
    AppleWebExchangeProof() => LinkIdentityRequest(
      exchangeCode: proof.exchangeCode,
      nonce: proof.rawNonce,
    ),
    IdTokenProof(provider: SocialProvider.apple) => LinkIdentityRequest(
      idToken: proof.idToken,
      authorizationCode:
          proof.authorizationCode ??
          (throw UnexpectedError(
            StateError('Apple 증명에 authorization code가 없습니다.'),
          )),
      nonce: proof.rawNonce,
    ),
    IdTokenProof() => LinkIdentityRequest(
      idToken: proof.idToken,
      nonce: proof.rawNonce,
    ),
  };

  List<SocialProvider> _providersOf(IdentityList list) => [
    for (final item in list.items) ?_socialProviderOf(item.provider),
  ];

  Future<T> _send<T>(Future<Response<T>> Function() request) async {
    try {
      final data = (await request()).data;
      if (data == null) {
        throw UnexpectedError(StateError('빈 응답'));
      }
      return data;
    } on DioException catch (e) {
      throw appErrorFrom(e);
    }
  }
}

LoginProvider _loginProviderOf(SocialProvider provider) => switch (provider) {
  SocialProvider.kakao => LoginProvider.kakao,
  SocialProvider.line => LoginProvider.line,
  SocialProvider.google => LoginProvider.google,
  SocialProvider.apple => LoginProvider.apple,
};

SocialProvider? _socialProviderOf(LoginProvider provider) => switch (provider) {
  LoginProvider.kakao => SocialProvider.kakao,
  LoginProvider.line => SocialProvider.line,
  LoginProvider.google => SocialProvider.google,
  LoginProvider.apple => SocialProvider.apple,
  LoginProvider.unknownDefaultOpenApi => null,
};

/// 연결 server 요청을 합니다. 로그인한 계정에서만 씁니다.
final accountLinkRepositoryProvider = Provider<AccountLinkRepository>(
  (ref) => AccountLinkRepository(ref.watch(restClientProvider)),
);
