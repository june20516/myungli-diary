import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/bootstrap.dart';
import 'package:myungli_diary/core/api/http_client.dart';
import 'package:myungli_diary/core/platform/external_browser.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';

void main() {
  final page = Uri.parse('https://example.com/legal/terms?lang=ko');

  test('UrlExternalBrowser는 받은 주소를 그대로 엽니다', () async {
    final tried = <Uri>[];
    final browser = UrlExternalBrowser(
      launch: (uri) async {
        tried.add(uri);
        return true;
      },
    );
    await browser.open(page);
    expect(tried, [page]);
  });

  test('열지 못하면 BrowserUnavailable입니다', () async {
    final browser = UrlExternalBrowser(launch: (_) async => false);
    await expectLater(browser.open(page), throwsA(isA<BrowserUnavailable>()));
  });

  test('FakeExternalBrowser는 연 주소를 차례로 남기고, failure가 있으면 던집니다', () async {
    final browser = FakeExternalBrowser();
    await browser.open(page);
    expect(browser.opened, [page]);

    browser.failure = const BrowserUnavailable();
    await expectLater(browser.open(page), throwsA(isA<BrowserUnavailable>()));
    // 실패한 시도도 남깁니다.
    expect(browser.opened, [page, page]);
  });

  test('기본값은 대역이고, http 모드 부팅은 실제 adapter를 끼웁니다', () {
    final fake = ProviderContainer();
    addTearDown(fake.dispose);
    expect(fake.read(externalBrowserProvider), isA<FakeExternalBrowser>());

    final real = ProviderContainer(
      overrides: realPlatformOverrides(ApiMode.http),
    );
    addTearDown(real.dispose);
    expect(real.read(externalBrowserProvider), isA<UrlExternalBrowser>());
  });
}
