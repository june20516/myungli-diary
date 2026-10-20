import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/entry/legal_links_provider.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/app_config.dart';
import 'package:myungli_diary/core/api/gen/model/legal_links.dart';
import 'package:myungli_diary/core/api/gen/model/minimum_version.dart';

final _fromEntry = LegalLinks(
  terms: 'https://entry.example.com/legal/terms',
  privacy: 'https://entry.example.com/legal/privacy',
);

final _fetched = LegalLinks(
  terms: 'https://fetched.example.com/legal/terms',
  privacy: 'https://fetched.example.com/legal/privacy',
);

AppConfig _config(LegalLinks legal) => AppConfig(
  minimumVersion: MinimumVersion(ios: '1.0.0', android: '1.0.0'),
  legal: legal,
);

/// `getAppConfig`만 흉내 냅니다. [failures]번은 503입니다.
final class _ConfigApi implements DefaultApi {
  new({this.failures = 0});

  int failures;
  int calls = 0;

  @override
  Future<Response<AppConfig>> getAppConfig({
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    calls++;
    final options = RequestOptions(path: '/v1/app-config');
    if (failures > 0) {
      failures--;
      throw DioException.badResponse(
        statusCode: 503,
        requestOptions: options,
        response: Response<Object?>(
          requestOptions: options,
          statusCode: 503,
          headers: Headers.fromMap({
            Headers.contentTypeHeader: ['application/problem+json'],
          }),
          data: {
            'status': 503,
            'code': 'service.unavailable',
            'title': 'x',
            'traceId': 't',
          },
        ),
      );
    }
    return Response(
      requestOptions: options,
      statusCode: 200,
      data: _config(_fetched),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container(_ConfigApi api, {AppConfig? entryConfig}) {
  final container = ProviderContainer(
    overrides: [
      restClientProvider.overrideWithValue(api),
      entryAppConfigProvider.overrideWithValue(entryConfig),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('legalDocumentUri', () {
    test('화면 언어를 lang으로 붙입니다(D80)', () {
      expect(
        legalDocumentUri('https://example.com/legal/terms', 'ko').toString(),
        'https://example.com/legal/terms?lang=ko',
      );
      expect(
        legalDocumentUri('https://example.com/legal/privacy', 'ja').toString(),
        'https://example.com/legal/privacy?lang=ja',
      );
    });

    test('기존 query는 반복 키까지 그대로 두고 lang만 더합니다', () {
      expect(
        legalDocumentUri(
          'https://example.com/legal/terms?v=1&v=2',
          'ko',
        ).toString(),
        'https://example.com/legal/terms?v=1&v=2&lang=ko',
      );
    });

    test('끝 슬래시는 그대로입니다', () {
      expect(
        legalDocumentUri('https://example.com/legal/terms/', 'en').toString(),
        'https://example.com/legal/terms/?lang=en',
      );
    });

    test('이미 lang이 있으면 화면 언어 하나로 바꿉니다', () {
      expect(
        legalDocumentUri(
          'https://example.com/legal/terms?lang=en&lang=ja',
          'ko',
        ).toString(),
        'https://example.com/legal/terms?lang=ko',
      );
    });

    test('ko·en·ja가 아닌 언어는 lang 없이 엽니다(server 기본 en)', () {
      expect(
        legalDocumentUri('https://example.com/legal/terms', 'fr').toString(),
        'https://example.com/legal/terms',
      );
    });
  });

  group('legalLinksProvider', () {
    test('진입 계산이 받은 getAppConfig가 있으면 다시 부르지 않고 그 주소입니다', () async {
      final api = _ConfigApi();
      final container = _container(api, entryConfig: _config(_fromEntry));
      expect(await container.read(legalLinksProvider.future), _fromEntry);
      expect(api.calls, 0);
    });

    test('진입 값이 없으면 getAppConfig를 불러 그 주소입니다', () async {
      final api = _ConfigApi();
      final container = _container(api);
      expect(await container.read(legalLinksProvider.future), _fetched);
      expect(api.calls, 1);
    });

    test('받지 못하면 AppError이고, 저절로 다시 받지 않으며 invalidate하면 다시 받습니다', () async {
      final api = _ConfigApi(failures: 1);
      final container = _container(api);
      final sub = container.listen(legalLinksProvider, (_, _) {});
      addTearDown(sub.close);
      await expectLater(
        container.read(legalLinksProvider.future),
        throwsA(isA<AppError>()),
      );
      expect(api.calls, 1);

      container.invalidate(legalLinksProvider);
      expect(await container.read(legalLinksProvider.future), _fetched);
      expect(api.calls, 2);
    });
  });
}
