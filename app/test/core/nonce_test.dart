import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/platform/nonce.dart';

void main() {
  group('hashNonce', () {
    test('SHA-256 소문자 hex (알려진 벡터)', () {
      // FIPS 180-2 부록 B.1
      expect(
        hashNonce('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
      // 빈 문자열의 SHA-256
      expect(
        hashNonce(''),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('UTF-8로 해시한다', () {
      // printf '명리' | shasum -a 256
      expect(
        hashNonce('명리'),
        '276dcef055ac9240cd94cdc5aa54bf881fa37e148dee7a5d5db42243c5982206',
      );
    });
  });

  group('NonceGenerator', () {
    test('기본 길이는 32자이고 base64url 문자만 쓴다', () {
      final raw = NonceGenerator().generate();
      expect(raw, hasLength(32));
      expect(raw, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    });

    test('16~256자를 만든다', () {
      final generator = NonceGenerator();
      expect(generator.generate(length: 16), hasLength(16));
      expect(generator.generate(length: 256), hasLength(256));
    });

    test('범위 밖 길이는 거절한다', () {
      final generator = NonceGenerator();
      expect(() => generator.generate(length: 15), throwsArgumentError);
      expect(() => generator.generate(length: 257), throwsArgumentError);
    });

    test('같은 seed면 같은 값, 호출마다 다른 값', () {
      final a = NonceGenerator(random: Random(1));
      final b = NonceGenerator(random: Random(1));
      final first = a.generate();
      expect(b.generate(), first);
      expect(a.generate(), isNot(first));
    });
  });
}
