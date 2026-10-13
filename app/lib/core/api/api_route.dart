import 'package:myungli_diary/core/api/api_route_model.dart';
import 'package:myungli_diary/core/api/gen_routes/routes.g.dart';

export 'package:myungli_diary/core/api/api_route_model.dart';

/// [method]와 [path]에 맞는 route를 찾습니다. 없으면 null입니다.
///
/// [path]의 query와 끝 슬래시는 무시합니다. 글자 그대로 쓰는 경로가
/// 매개변수 경로보다 우선합니다.
ApiRoute? matchRoute(String method, String path) {
  final upperMethod = method.toUpperCase();
  ApiRoute? best;
  for (final route in apiRoutes) {
    if (route.method != upperMethod || route.pathParametersOf(path) == null) {
      continue;
    }
    if (best == null || route.parameterCount < best.parameterCount) {
      best = route;
    }
  }
  return best;
}
