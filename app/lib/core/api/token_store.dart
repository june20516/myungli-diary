import 'dart:async';

import 'package:myungli_diary/core/api/gen/model/token_pair.dart';
import 'package:myungli_diary/core/storage/secure_store.dart';

/// 인증 상태 변화 이벤트입니다.
enum AuthEvent {
  /// refresh가 거부돼 로그아웃됐습니다. 로그인 화면으로 보내야 합니다.
  signedOut,
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

  /// 토큰을 모두 지웁니다. 이벤트는 내지 않습니다(자발적 로그아웃용).
  Future<void> clear() async {
    _accessToken = null;
    await _secureStore.delete(_refreshKey);
  }

  /// 토큰을 지우고 [AuthEvent.signedOut]을 알립니다(refresh 거부 때).
  Future<void> signOut() async {
    await clear();
    _events.add(AuthEvent.signedOut);
  }

  /// 스트림을 닫습니다.
  Future<void> dispose() => _events.close();
}
