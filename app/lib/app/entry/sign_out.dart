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
  await tokens.signOut();
}
