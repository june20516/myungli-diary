import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// 로그인 nonce 원문과 Apple 웹 로그인 `state`를 만듭니다(server 결정 S15).
///
/// 원문은 server에 그대로 보내고, 제공자(카카오·Apple)에게는 [hashNonce]한 값을 보냅니다.
final class NonceGenerator {
  /// [random]을 주지 않으면 `Random.secure()`를 씁니다.
  new({Random? random}) : _random = random ?? Random.secure();

  /// 계약 `nonce`의 최소 길이.
  static const minLength = 16;

  /// 계약 `nonce`의 최대 길이.
  static const maxLength = 256;

  static const _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';

  final Random _random;

  /// base64url 문자로 [length]자 무작위 값을 만듭니다. 기본 32자(192비트)입니다.
  String generate({int length = 32}) {
    if (length < minLength || length > maxLength) {
      throw ArgumentError.value(
        length,
        'length',
        '$minLength~$maxLength자여야 합니다',
      );
    }
    return String.fromCharCodes(
      List.generate(
        length,
        (_) => _alphabet.codeUnitAt(_random.nextInt(_alphabet.length)),
      ),
    );
  }
}

/// 제공자에게 보낼 nonce입니다. 원문 UTF-8의 SHA-256 소문자 hex입니다.
String hashNonce(String raw) => sha256.convert(utf8.encode(raw)).toString();
