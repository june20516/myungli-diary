import 'dart:async';

import 'package:myungli_diary/core/api/gen/model/token_pair.dart';
import 'package:myungli_diary/core/storage/secure_store.dart';

/// 인증 상태 변화 이벤트입니다.
enum AuthEvent {
  /// 로그아웃됐습니다(refresh 거부, `getMe` 401, 삭제 대기 계정, 자발적 로그아웃).
  /// 로컬 정리·외부 SDK 연결 해제·진입 재계산이 이 이벤트를 듣습니다.
  signedOut,

  /// bearer 요청이 403 `consent.required`를 받았습니다. 토큰은 그대로이고
  /// 진입 갈래를 다시 계산해 약관 동의로 보내야 합니다.
  consentRequired,
}

/// 토큰 보관소입니다. access token은 메모리에만, refresh token은 보안 저장소에 둡니다.
final class TokenStore {
  /// [_secureStore]에 refresh token을 보관하는 저장소를 만듭니다.
  new(this._secureStore);

  static const _refreshKey = 'auth.refresh';

  final SecureStore _secureStore;
  final _events = StreamController<AuthEvent>.broadcast();
  String? _accessToken;

  /// 현재 access token. 없으면 null입니다.
  String? get accessToken => _accessToken;

  /// 인증 이벤트 스트림.
  Stream<AuthEvent> get events => _events.stream;

  /// 새 토큰 쌍을 저장합니다.
  Future<void> save(TokenPair pair) async {
    // 저장이 실패하면 메모리도 바꾸지 않아 옛·새 토큰이 섞이지 않습니다.
    await _secureStore.write(_refreshKey, pair.refreshToken);
    _accessToken = pair.accessToken;
  }

  /// refresh token만 심습니다. access token은 비워 두어 첫 요청이 세션 복원(refresh)을 거칩니다.
  ///
  /// 앱을 다시 실행한 상태를 만드는 fake 모드 시작 코드가 씁니다.
  Future<void> seedRefreshToken(String refreshToken) async {
    _accessToken = null;
    await _secureStore.write(_refreshKey, refreshToken);
  }

  /// 저장된 refresh token. 없으면 null입니다.
  Future<String?> refreshToken() => _secureStore.read(_refreshKey);

  /// 이벤트 없이 토큰을 지웁니다. 로그아웃이 아닙니다.
  ///
  /// 정리할 로컬 데이터가 없는 경우만 씁니다: fake 모드 시작 코드가 시나리오의
  /// 로그아웃 상태를 만들 때, 진입 계산이 다시 설치된 앱에서 이전 설치의 토큰을
  /// 버릴 때, 테스트. 로그아웃은 어떤 경로든 [signOut]을 거쳐야 로컬 정리가 돕니다.
  Future<void> discardWithoutEvent() async {
    _accessToken = null;
    await _secureStore.delete(_refreshKey);
  }

  /// 토큰을 지우고 [AuthEvent.signedOut]을 알립니다. 모든 로그아웃의 단일 진입점입니다.
  ///
  /// server에 refresh token 폐기까지 하려면(자발적 로그아웃, 삭제 대기 계정)
  /// `revokeAndSignOut`(app/entry/sign_out.dart)를 씁니다.
  Future<void> signOut() async {
    await discardWithoutEvent();
    _events.add(AuthEvent.signedOut);
  }

  /// 약관 동의가 필요해졌음을 알립니다. 토큰은 지우지 않습니다.
  void notifyConsentRequired() => _events.add(AuthEvent.consentRequired);

  /// 스트림을 닫습니다.
  Future<void> dispose() => _events.close();
}
