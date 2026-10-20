import 'package:url_launcher/url_launcher.dart';

/// 웹 페이지를 앱 밖 브라우저로 엽니다(약관·개인정보 처리방침 등).
abstract interface class ExternalBrowser {
  /// [uri]를 외부 브라우저로 엽니다. 열지 못하면 [BrowserUnavailable] 등 예외입니다.
  Future<void> open(Uri uri);
}

/// 페이지를 열 브라우저가 없어 열지 못했습니다.
final class BrowserUnavailable implements Exception {
  /// 열지 못함.
  const new();
}

Future<bool> _launchExternally(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// `url_launcher`로 외부 브라우저를 여는 실제 adapter.
final class UrlExternalBrowser implements ExternalBrowser {
  /// 실제 adapter를 만듭니다. [launch]는 테스트에서 바꿉니다.
  const new({this.launch = _launchExternally});

  /// 주소를 여는 함수. 열렸으면 true.
  final Future<bool> Function(Uri uri) launch;

  @override
  Future<void> open(Uri uri) async {
    if (!await launch(uri)) throw const BrowserUnavailable();
  }
}
