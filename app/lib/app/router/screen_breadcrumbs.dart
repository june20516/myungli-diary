import 'package:go_router/go_router.dart';
import 'package:myungli_diary/core/ia/ia_ids.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';

/// 라우터의 현재 화면이 바뀔 때마다 IA 화면 id를 breadcrumb으로 남기고, 듣기를 끝내는
/// 함수를 돌려줍니다.
///
/// `GoRouter.observers`(NavigatorObserver)는 탭 전환(StatefulShellRoute의
/// indexedStack)과 redirect를 보지 못하므로 라우터 delegate의 현재 경로를 듣습니다.
/// 경로는 `/<화면 id>`이고, IA 화면 id가 아니면 남기지 않습니다(D64 ②: breadcrumb은
/// 화면 id만).
/// 같은 화면이 이어지면 한 번만 남깁니다.
void Function() listenScreenBreadcrumbs(
  GoRouter router,
  CrashReporter reporter,
) {
  final delegate = router.routerDelegate;
  String? lastScreenId;
  void report() {
    final configuration = delegate.currentConfiguration;
    if (configuration.isEmpty) {
      return;
    }
    final screenId = screenIdOfPath(configuration.uri.path);
    if (screenId == null || screenId == lastScreenId) {
      return;
    }
    lastScreenId = screenId;
    reporter.breadcrumb(screenId);
  }

  delegate.addListener(report);
  return () => delegate.removeListener(report);
}

/// 경로 `/<화면 id>`의 IA 화면 id. IA 화면이 아니면 null입니다.
String? screenIdOfPath(String path) =>
    sanitizeScreenId(path.startsWith('/') ? path.substring(1) : path);
