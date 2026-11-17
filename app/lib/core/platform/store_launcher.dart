import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// 스토어의 앱 페이지 열기(강제 업데이트 안내 등).
abstract interface class StoreLauncher {
  /// 스토어의 이 앱 페이지를 엽니다. 열지 못하면 [StoreUnavailable] 등 예외입니다.
  Future<void> openStore();
}

/// 스토어 페이지를 열 앱이 없어 열지 못했습니다.
final class StoreUnavailable implements Exception {
  /// 열지 못함.
  const new();
}

Future<bool> _launchExternally(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// iOS 설치 경로를 읽는 채널. 이름은 AppDelegate.swift의 채널 이름과 같습니다.
const MethodChannel _distributionChannel = MethodChannel(
  'app.myungli.diary/distribution',
);

/// 이 iOS 앱이 TestFlight로 설치됐는지(AppDelegate가 App Store 영수증 이름으로 판별).
Future<bool> _readIsTestFlight() async =>
    await _distributionChannel.invokeMethod<bool>('isTestFlight') ?? false;

/// `url_launcher`로 스토어를 여는 실제 adapter.
///
/// iOS TestFlight 설치본은 App Store에 아직 공개 페이지가 없어(출시 전 404) TestFlight 앱의
/// 이 앱 페이지를 엽니다(#1258). 그곳에서 새 빌드로 업데이트합니다.
final class UrlStoreLauncher implements StoreLauncher {
  /// 실제 adapter를 만듭니다. [launch], [platform], [isTestFlight]는 테스트에서 바꿉니다.
  const new({
    this.launch = _launchExternally,
    this.platform,
    this.isTestFlight = _readIsTestFlight,
  });

  /// Android 스토어 주소.
  static final Uri androidUri = Uri.parse(
    'market://details?id=app.myungli.diary',
  );

  /// Android 스토어 앱이 없을 때(에뮬레이터 등) 여는 웹 주소.
  static final Uri androidWebUri = Uri.parse(
    'https://play.google.com/store/apps/details?id=app.myungli.diary',
  );

  /// iOS App Store 주소(App Store Connect Apple ID 6829967838, #714).
  static final Uri iosUri = Uri.parse(
    'https://apps.apple.com/app/id6829967838',
  );

  /// iOS TestFlight 앱의 이 앱 페이지(App Store Connect Apple ID 6829967838).
  static final Uri testFlightUri = Uri.parse(
    'itms-beta://beta.itunes.apple.com/v1/app/6829967838',
  );

  /// 주소를 여는 함수. 열렸으면 true.
  final Future<bool> Function(Uri uri) launch;

  /// 대상 플랫폼. null이면 실행 중인 플랫폼입니다.
  final TargetPlatform? platform;

  /// iOS 앱이 TestFlight로 설치됐는지. iOS에서만 부릅니다.
  final Future<bool> Function() isTestFlight;

  @override
  Future<void> openStore() async {
    final target = platform ?? defaultTargetPlatform;
    if (target != TargetPlatform.android) {
      if (await _installedFromTestFlight() && await launch(testFlightUri)) {
        return;
      }
      if (!await launch(iosUri)) throw const StoreUnavailable();
      return;
    }
    if (!await launch(androidUri) && !await launch(androidWebUri)) {
      throw const StoreUnavailable();
    }
  }

  /// 설치 경로를 읽지 못하면(채널 없음, 오류) App Store 설치본으로 봅니다.
  Future<bool> _installedFromTestFlight() async {
    try {
      return await isTestFlight();
    } on Exception {
      return false;
    }
  }
}
