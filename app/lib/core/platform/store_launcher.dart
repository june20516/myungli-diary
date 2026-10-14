import 'package:flutter/foundation.dart';
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

/// `url_launcher`로 스토어를 여는 실제 adapter.
final class UrlStoreLauncher implements StoreLauncher {
  /// 실제 adapter를 만듭니다. [launch]와 [platform]은 테스트에서 바꿉니다.
  const new({this.launch = _launchExternally, this.platform});

  /// Android 스토어 주소.
  static final Uri androidUri = Uri.parse(
    'market://details?id=app.myungli.diary',
  );

  /// Android 스토어 앱이 없을 때(에뮬레이터 등) 여는 웹 주소.
  static final Uri androidWebUri = Uri.parse(
    'https://play.google.com/store/apps/details?id=app.myungli.diary',
  );

  /// iOS 스토어 주소. 앱 id가 생기기 전까지는 검색 페이지입니다.
  static final Uri iosUri = Uri.parse(
    'https://apps.apple.com/kr/search?term=myungli',
  );

  /// 주소를 여는 함수. 열렸으면 true.
  final Future<bool> Function(Uri uri) launch;

  /// 대상 플랫폼. null이면 실행 중인 플랫폼입니다.
  final TargetPlatform? platform;

  @override
  Future<void> openStore() async {
    final target = platform ?? defaultTargetPlatform;
    if (target != TargetPlatform.android) {
      if (!await launch(iosUri)) throw const StoreUnavailable();
      return;
    }
    if (!await launch(androidUri) && !await launch(androidWebUri)) {
      throw const StoreUnavailable();
    }
  }
}
