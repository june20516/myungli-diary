// OpenAPI 계약(../server/api/openapi.yaml)에서 route 표를 생성합니다.
// 실행: dart run tool/gen_api_routes.dart (보통 tool/gen_api.sh가 부름)

import 'dart:io';

import 'common/dart_format.dart';
import 'common/openapi_spec.dart';

const _outputPath = 'lib/core/api/gen_routes/routes.g.dart';
const _httpMethods = ['get', 'put', 'post', 'delete', 'patch'];

/// operation의 실효 security(operation 것이 있으면 그것, 없으면 전역)가
/// bearerAuth를 요구하는지.
bool _requiresBearer(Map<String, Object?> operation, Object? globalSecurity) {
  final security = operation.containsKey('security')
      ? operation['security']
      : globalSecurity;
  if (security is! List<Object?>) {
    return false;
  }
  return security.any(
    (requirement) =>
        requirement is Map<String, Object?> &&
        requirement.containsKey('bearerAuth'),
  );
}

/// 계약(디코딩 결과)에서 route 표 소스를 만듭니다.
String generateApiRoutesSource(Map<String, Object?> spec) {
  final paths = spec['paths']! as Map<String, Object?>;
  final out = StringBuffer()
    ..writeln('// 생성 코드: tool/gen_api.sh. 손으로 고치지 않습니다.')
    ..writeln()
    ..writeln("import 'package:myungli_diary/core/api/api_route_model.dart';")
    ..writeln()
    ..writeln('/// 계약의 operation 전부.')
    ..writeln('const List<ApiRoute> apiRoutes = [');
  for (final pathEntry in paths.entries) {
    final item = pathEntry.value! as Map<String, Object?>;
    for (final method in _httpMethods) {
      final operation = item[method] as Map<String, Object?>?;
      if (operation == null) {
        continue;
      }
      final operationId = operation['operationId'];
      if (operationId is! String) {
        throw StateError(
          '${method.toUpperCase()} ${pathEntry.key}에 operationId가 없습니다.',
        );
      }
      final bearer = _requiresBearer(operation, spec['security']);
      out.writeln(
        "ApiRoute('${method.toUpperCase()}', '${pathEntry.key}', "
        "'$operationId'${bearer ? '' : ', requiresBearer: false'}),",
      );
    }
  }
  out.writeln('];');
  return out.toString();
}

Future<void> main() async {
  final source = await formatDartSource(generateApiRoutesSource(loadOpenApi()));
  final output = File(_outputPath);
  await output.parent.create(recursive: true);
  await output.writeAsString(source);
}
