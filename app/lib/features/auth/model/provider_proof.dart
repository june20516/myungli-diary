import 'package:flutter/foundation.dart';
import 'package:myungli_diary/core/platform/social_provider.dart';

/// 제공자 인증 한 번의 결과입니다. server에 보낼 증명입니다(결정 A84).
@immutable
sealed class ProviderProof {
  const new({required this.rawNonce});

  /// 인증한 제공자.
  SocialProvider get provider;

  /// server에 보낼 원문 nonce.
  final String rawNonce;
}

/// OIDC id_token 증명입니다(카카오, LINE, Google, iOS Apple).
final class IdTokenProof extends ProviderProof {
  /// [authorizationCode]는 iOS Apple만 가집니다.
  const new({
    required this.provider,
    required this.idToken,
    required super.rawNonce,
    this.authorizationCode,
  });

  @override
  final SocialProvider provider;

  /// 제공자 id_token.
  final String idToken;

  /// Apple authorization code(iOS 네이티브).
  final String? authorizationCode;
}

/// Android Apple 웹 흐름의 교환 코드 증명입니다. 코드는 2분 일회용입니다.
final class AppleWebExchangeProof extends ProviderProof {
  /// 교환 코드를 담습니다.
  const new({required this.exchangeCode, required super.rawNonce});

  @override
  SocialProvider get provider => SocialProvider.apple;

  /// 일회용 교환 코드.
  final String exchangeCode;
}
