import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/platform/store_launcher.dart';

void main() {
  test('Android는 market 주소를 먼저 열고, 실패하면 웹 주소로 한 번 더 시도한다', () async {
    final tried = <Uri>[];
    final launcher = UrlStoreLauncher(
      platform: TargetPlatform.android,
      launch: (uri) async {
        tried.add(uri);
        return uri == UrlStoreLauncher.androidWebUri;
      },
    );
    await launcher.openStore();
    expect(tried, [
      UrlStoreLauncher.androidUri,
      UrlStoreLauncher.androidWebUri,
    ]);
    expect(
      UrlStoreLauncher.androidWebUri.toString(),
      'https://play.google.com/store/apps/details?id=app.myungli.diary',
    );
  });

  test('Android에서 market 주소가 열리면 대체 주소를 시도하지 않는다', () async {
    final tried = <Uri>[];
    final launcher = UrlStoreLauncher(
      platform: TargetPlatform.android,
      launch: (uri) async {
        tried.add(uri);
        return true;
      },
    );
    await launcher.openStore();
    expect(tried, [UrlStoreLauncher.androidUri]);
  });

  test('iOS App Store 설치본은 App Store 주소만 연다', () async {
    final tried = <Uri>[];
    final launcher = UrlStoreLauncher(
      platform: TargetPlatform.iOS,
      isTestFlight: () async => false,
      launch: (uri) async {
        tried.add(uri);
        return true;
      },
    );
    await launcher.openStore();
    expect(tried, [UrlStoreLauncher.iosUri]);
    expect(
      UrlStoreLauncher.iosUri.toString(),
      'https://apps.apple.com/app/id6829967838',
    );
  });

  test('Android에서 두 주소 모두 열지 못하면 StoreUnavailable입니다', () async {
    final launcher = UrlStoreLauncher(
      platform: TargetPlatform.android,
      launch: (_) async => false,
    );
    await expectLater(launcher.openStore(), throwsA(isA<StoreUnavailable>()));
  });

  test('iOS에서 열지 못하면 StoreUnavailable입니다', () async {
    final launcher = UrlStoreLauncher(
      platform: TargetPlatform.iOS,
      isTestFlight: () async => true,
      launch: (_) async => false,
    );
    await expectLater(launcher.openStore(), throwsA(isA<StoreUnavailable>()));
  });

  group('iOS TestFlight 설치본(#1258)', () {
    test('TestFlight 앱의 이 앱 페이지를 연다', () async {
      final tried = <Uri>[];
      final launcher = UrlStoreLauncher(
        platform: TargetPlatform.iOS,
        isTestFlight: () async => true,
        launch: (uri) async {
          tried.add(uri);
          return true;
        },
      );
      await launcher.openStore();
      expect(tried, [UrlStoreLauncher.testFlightUri]);
      expect(
        UrlStoreLauncher.testFlightUri.toString(),
        'itms-beta://beta.itunes.apple.com/v1/app/6829967838',
      );
    });

    test('TestFlight 앱을 열지 못하면 App Store 주소로 한 번 더 시도한다', () async {
      final tried = <Uri>[];
      final launcher = UrlStoreLauncher(
        platform: TargetPlatform.iOS,
        isTestFlight: () async => true,
        launch: (uri) async {
          tried.add(uri);
          return uri == UrlStoreLauncher.iosUri;
        },
      );
      await launcher.openStore();
      expect(tried, [UrlStoreLauncher.testFlightUri, UrlStoreLauncher.iosUri]);
    });

    test('설치 경로를 읽지 못하면 App Store 설치본으로 본다', () async {
      final tried = <Uri>[];
      final launcher = UrlStoreLauncher(
        platform: TargetPlatform.iOS,
        isTestFlight: () async => throw PlatformException(code: 'unavailable'),
        launch: (uri) async {
          tried.add(uri);
          return true;
        },
      );
      await launcher.openStore();
      expect(tried, [UrlStoreLauncher.iosUri]);
    });

    test('Android는 설치 경로를 읽지 않는다', () async {
      var asked = false;
      final launcher = UrlStoreLauncher(
        platform: TargetPlatform.android,
        isTestFlight: () async {
          asked = true;
          return true;
        },
        launch: (_) async => true,
      );
      await launcher.openStore();
      expect(asked, isFalse);
    });
  });
}
