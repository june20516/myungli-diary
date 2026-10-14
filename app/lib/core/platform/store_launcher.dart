import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// 스토어의 앱 페이지 열기(강제 업데이트 안내 등).
abstract interface class StoreLauncher {
  /// 스토어의 이 앱 페이지를 엽니다.
  Future<void> openStore();
}

/// `url_launcher`로 스토어를 여는 실제 adapter.
final class UrlStoreLauncher implements StoreLauncher {
  /// 실제 adapter를 만듭니다.
  const new();

  /// Android 스토어 주소.
  static final Uri androidUri = Uri.parse(
    'market://details?id=app.myungli.diary',
  );

  /// iOS 스토어 주소. 앱 id가 생기기 전까지는 검색 페이지입니다.
  static final Uri iosUri = Uri.parse(
    'https://apps.apple.com/kr/search?term=myungli',
  );

  @override
  Future<void> openStore() async {
    final uri = defaultTargetPlatform == TargetPlatform.android
        ? androidUri
        : iosUri;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
