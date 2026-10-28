import 'package:google_sign_in/google_sign_in.dart';
import 'package:myungli_diary/core/platform/auth_config.dart';
import 'package:myungli_diary/core/platform/nonce.dart';
import 'package:myungli_diary/core/platform/social_auth.dart';
import 'package:myungli_diary/core/platform/social_provider.dart';

/// Google SDK 경계. SDK 호출을 그대로 옮기기만 하고 분기는 [GoogleSdkAuth]에 둡니다.
abstract interface class GoogleSignInApi {
  /// SDK를 초기화합니다. 프로세스에서 한 번만 부르고, nonce도 이때만 받습니다.
  Future<void> initialize({
    required String serverClientId,
    required String nonce,
    String? clientId,
  });

  /// 계정을 고르게 하고 `authentication.idToken`을 돌려줍니다.
  Future<String?> authenticate();

  /// SDK 세션을 지웁니다.
  Future<void> signOut();
}

/// 실제 Google SDK를 부르는 경계(기본값). 이메일·프로필 scope는 받지 않습니다(D82 ④).
final class SdkGoogleSignInApi implements GoogleSignInApi {
  /// 경계를 만듭니다.
  const new();

  @override
  Future<void> initialize({
    required String serverClientId,
    required String nonce,
    String? clientId,
  }) => GoogleSignIn.instance.initialize(
    clientId: clientId,
    serverClientId: serverClientId,
    nonce: nonce,
  );

  @override
  Future<String?> authenticate() async =>
      (await GoogleSignIn.instance.authenticate()).authentication.idToken;

  @override
  Future<void> signOut() => GoogleSignIn.instance.signOut();
}

/// Google 로그인의 실제 구현(spec §5.4, 결정 A83).
///
/// SDK는 nonce를 `initialize` 한 번에만 받으므로, 처음 로그인할 때 프로세스 nonce 원문을 만들고
/// 그 해시로 한 번 초기화합니다. 앱이 꺼질 때까지 같은 원문을 credential에 담아 돌려주고,
/// 인자로 받은 원문은 쓰지 않습니다(server #555: 같은 원문 재사용 허용). 동시에 불러도
/// 초기화는 한 번이고, 초기화가 실패하면 다음 로그인이 다시 초기화합니다. id_token을 받은 뒤
/// SDK 세션을 지우고, 지우기 실패는 로그인을 막지 않습니다.
final class GoogleSdkAuth implements GoogleAuth {
  /// [isIos]면 [config]의 iOS client id도 씁니다.
  new({
    required this.config,
    required this.isIos,
    required this.nonces,
    this.api = const SdkGoogleSignInApi(),
  });

  /// 제공자 설정.
  final AuthConfig config;

  /// iOS에서 도는지.
  final bool isIos;

  /// SDK 경계.
  final GoogleSignInApi api;

  /// 프로세스 nonce를 만듭니다.
  final NonceGenerator nonces;

  /// 초기화 결과(프로세스 nonce 원문). 실패하면 비워 다음 로그인이 다시 초기화합니다.
  Future<String>? _initialized;

  @override
  Future<GoogleCredential> signIn({required String rawNonce}) async {
    if (!config.isGoogleConfigured(ios: isIos)) {
      throw const ProviderNotConfigured(SocialProvider.google);
    }
    final processNonce = await (_initialized ??= _initialize());
    final String? idToken;
    try {
      idToken = await api.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const SocialSignInCancelled();
      }
      rethrow;
    }
    if (idToken == null) {
      throw StateError('Google 응답에 id_token이 없습니다(serverClientId 확인)');
    }
    try {
      await api.signOut();
    } on Object {
      // 세션 정리 실패는 로그인을 막지 않습니다(A82).
    }
    return GoogleCredential(idToken: idToken, rawNonce: processNonce);
  }

  Future<String> _initialize() async {
    final raw = nonces.generate();
    try {
      await api.initialize(
        clientId: isIos ? config.googleIosClientId.trim() : null,
        serverClientId: config.googleServerClientId.trim(),
        nonce: hashNonce(raw),
      );
      return raw;
    } on Object {
      _initialized = null;
      rethrow;
    }
  }
}
