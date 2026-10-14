import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/refresh_request.dart';
import 'package:myungli_diary/core/api/token_store.dart';

/// server에 refresh token 폐기(`logout`)를 시도한 뒤 로컬에서 로그아웃합니다.
///
/// 자발적 로그아웃(계획 6의 설정)과 삭제 대기 계정(S16, 그 토큰으로 `logout`을 부를 수
/// 있음)이 이 함수를 거칩니다. server 호출은 best-effort라 실패해도 로컬 로그아웃
/// ([TokenStore.signOut])은 반드시 합니다. 그 `signedOut` 이벤트를 받아 로컬 정리
/// (`SignOutCleaner`), 외부 SDK 연결 해제(`AccountLinker`), 진입 재계산이 돕니다.
///
/// server가 이미 거부한 토큰(refresh 거부, `getMe` 401)에는 폐기할 것이 없으므로
/// [TokenStore.signOut]을 바로 씁니다.
Future<void> revokeAndSignOut({
  required DefaultApi api,
  required TokenStore tokens,
}) async {
  await revokeStoredRefreshToken(api: api, tokens: tokens);
  // `logout`은 bearer 요청이라, access token이 만료됐고 refresh가 거부되면 interceptor가
  // 이미 로그아웃했을 수 있습니다. 그때 signedOut을 두 번 내지 않습니다.
  if (await _hasSessionOrUnknown(tokens)) {
    await tokens.signOut();
  }
}

/// 남은 토큰이 있는지. 저장소를 읽지 못하면 지우는 쪽(true)으로 봅니다.
Future<bool> _hasSessionOrUnknown(TokenStore tokens) async {
  try {
    return await tokens.hasSession();
  } on Object {
    return true;
  }
}

/// 저장된 refresh token의 server 폐기(`logout`)만 시도합니다. 로컬 토큰과 이벤트는 건드리지 않습니다.
///
/// 새 로그인이 이전 세션의 토큰을 덮어쓰기 전에 씁니다. 실패해도 server의 refresh token은
/// 만료로 끝나므로 오류를 삼킵니다.
Future<void> revokeStoredRefreshToken({
  required DefaultApi api,
  required TokenStore tokens,
}) async {
  try {
    final refreshToken = await tokens.refreshToken();
    if (refreshToken != null) {
      await api.logout(
        refreshRequest: RefreshRequest(refreshToken: refreshToken),
      );
    }
  } on Object {
    // 폐기에 실패해도 server의 refresh token은 만료로 끝납니다. 로컬 로그아웃이 우선입니다.
  }
}
