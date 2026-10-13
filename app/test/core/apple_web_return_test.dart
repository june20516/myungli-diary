import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/platform/apple_web_return.dart';
import 'package:myungli_diary/core/platform/social_auth.dart';

void main() {
  const exchange = 'abcdefghijABCDEFGHIJ0123456789_-abcdefghijk';

  group('buildAppleAuthorizeUri', () {
    test('계약의 query 값을 모두 싣고 scope는 없다', () {
      final uri = buildAppleAuthorizeUri(
        clientId: 'app.myungli.diary.web',
        redirectUri: Uri.parse(
          'https://api.example.com/v1/auth/apple/callback',
        ),
        hashedNonce: 'ab12',
        state: 'state-1',
      );
      expect(uri.origin, 'https://appleid.apple.com');
      expect(uri.path, '/auth/authorize');
      expect(uri.queryParameters, {
        'client_id': 'app.myungli.diary.web',
        'redirect_uri': 'https://api.example.com/v1/auth/apple/callback',
        'response_mode': 'form_post',
        'response_type': 'code id_token',
        'nonce': 'ab12',
        'state': 'state-1',
      });
    });
  });

  group('parseAppleWebReturn', () {
    Uri link(Map<String, String> query) => Uri(
      scheme: 'https',
      host: 'link.example.com',
      path: '/auth/apple',
      queryParameters: query,
    );

    test('state가 같으면 교환 코드를 돌려준다', () {
      final result = parseAppleWebReturn(
        link({'exchange': exchange, 'state': 's1'}),
        expectedState: 's1',
      );
      expect(result, isA<AppleWebExchange>());
      expect((result as AppleWebExchange).exchangeCode, exchange);
    });

    test('state가 다르면 교환 코드가 있어도 stateMismatch', () {
      final result = parseAppleWebReturn(
        link({'exchange': exchange, 'state': 'other'}),
        expectedState: 's1',
      );
      expect(result, const AppleWebFailure(AppleWebError.stateMismatch));
    });

    test('state가 없으면 stateMismatch', () {
      final result = parseAppleWebReturn(
        link({'exchange': exchange}),
        expectedState: 's1',
      );
      expect(result, const AppleWebFailure(AppleWebError.stateMismatch));
    });

    test('계약의 error 다섯 값을 구분한다', () {
      const expected = {
        'user_cancelled_authorize': AppleWebError.userCancelled,
        'token_invalid': AppleWebError.tokenInvalid,
        'provider_unavailable': AppleWebError.providerUnavailable,
        'invalid_request': AppleWebError.invalidRequest,
        'server_error': AppleWebError.serverError,
      };
      for (final MapEntry(:key, :value) in expected.entries) {
        final result = parseAppleWebReturn(
          link({'error': key, 'state': 's1'}),
          expectedState: 's1',
        );
        expect(result, AppleWebFailure(value), reason: key);
      }
    });

    test('모르는 error 값은 unknown', () {
      final result = parseAppleWebReturn(
        link({'error': 'weird', 'state': 's1'}),
        expectedState: 's1',
      );
      expect(result, const AppleWebFailure(AppleWebError.unknown));
    });

    test('error가 있으면 exchange보다 우선한다', () {
      final result = parseAppleWebReturn(
        link({'error': 'server_error', 'exchange': exchange, 'state': 's1'}),
        expectedState: 's1',
      );
      expect(result, const AppleWebFailure(AppleWebError.serverError));
    });

    test('형식이 틀린 교환 코드나 빈 query는 invalidRequest', () {
      expect(
        parseAppleWebReturn(
          link({'exchange': 'short', 'state': 's1'}),
          expectedState: 's1',
        ),
        const AppleWebFailure(AppleWebError.invalidRequest),
      );
      expect(
        parseAppleWebReturn(link({'state': 's1'}), expectedState: 's1'),
        const AppleWebFailure(AppleWebError.invalidRequest),
      );
    });
  });
}
