import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/platform/store_launcher.dart';

void main() {
  test('Android는 market 주소를 먼저 열고, 실패하면 웹 주소로 한 번 더 시도한다', () async {
    final tried = <Uri>[];
    final launcher = UrlStoreLauncher(
      platform: TargetPlatform.android,
      launch: (uri) async {
        tried.add(uri);
        return false;
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

  test('iOS는 검색 주소를 연다', () async {
    final tried = <Uri>[];
    final launcher = UrlStoreLauncher(
      platform: TargetPlatform.iOS,
      launch: (uri) async {
        tried.add(uri);
        return true;
      },
    );
    await launcher.openStore();
    expect(tried, [UrlStoreLauncher.iosUri]);
  });
}
