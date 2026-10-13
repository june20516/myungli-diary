import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/api_route.dart';
import 'package:myungli_diary/core/api/gen_routes/routes.g.dart';

import '../../tool/common/dart_format.dart';
import '../../tool/common/openapi_spec.dart';
import '../../tool/gen_api_routes.dart';

void main() {
  group('generateApiRoutesSource', () {
    final smallSpec = <String, Object?>{
      'paths': {
        '/v1/me': {
          'parameters': <Object?>[],
          'get': {'operationId': 'getMe'},
          'delete': {'operationId': 'deleteMe'},
        },
        '/v1/daily/{date}': {
          'get': {'operationId': 'getDaily'},
        },
      },
    };

    test('첫 줄이 생성 안내이고 operation마다 한 줄을 만든다', () {
      final source = generateApiRoutesSource(smallSpec);
      expect(
        source.split('\n').first,
        '// 생성 코드: tool/gen_api.sh. 손으로 고치지 않습니다.',
      );
      expect(source, contains("ApiRoute('GET', '/v1/me', 'getMe')"));
      expect(source, contains("ApiRoute('DELETE', '/v1/me', 'deleteMe')"));
      expect(
        source,
        contains("ApiRoute('GET', '/v1/daily/{date}', 'getDaily')"),
      );
    });

    test('operationId가 없으면 실패한다', () {
      final spec = {
        'paths': {
          '/x': {'get': <String, Object?>{}},
        },
      };
      expect(() => generateApiRoutesSource(spec), throwsStateError);
    });
  });

  group('실제 계약', () {
    test('operation 37개가 route 표에 모두 있다', () {
      expect(apiRoutes, hasLength(37));
      expect(
        apiRoutes.map((route) => route.operationId).toSet(),
        hasLength(37),
      );
    });

    test('커밋된 routes.g.dart가 다시 생성한 결과와 정확히 같다', () async {
      final regenerated = await formatDartSource(
        generateApiRoutesSource(loadOpenApi()),
      );
      expect(
        File('lib/core/api/gen_routes/routes.g.dart').readAsStringSync(),
        regenerated,
      );
    });
  });

  group('matchRoute', () {
    test('path 매개변수를 풀어 낸다', () {
      final route = matchRoute('GET', '/v1/daily/2026-10-13');
      expect(route?.operationId, 'getDaily');
      expect(route?.pathParametersOf('/v1/daily/2026-10-13'), {
        'date': '2026-10-13',
      });
    });

    test('매개변수가 둘이어도 푼다', () {
      const path = '/v1/calendar/2026/10';
      final route = matchRoute('GET', path);
      expect(route?.operationId, 'getCalendar');
      expect(route?.pathParametersOf(path), {'year': '2026', 'month': '10'});
    });

    test('method 소문자도 받고, method가 다르면 찾지 못한다', () {
      expect(matchRoute('get', '/v1/me')?.operationId, 'getMe');
      expect(matchRoute('DELETE', '/v1/me')?.operationId, 'deleteMe');
      expect(matchRoute('POST', '/v1/chart'), isNull);
    });

    test('없는 경로는 null이다', () {
      expect(matchRoute('GET', '/v1/nope'), isNull);
      expect(matchRoute('GET', '/v1/daily'), isNull);
      expect(matchRoute('GET', '/v1/daily/2026-10-13/extra'), isNull);
    });

    test('끝의 슬래시와 query는 무시한다', () {
      expect(matchRoute('GET', '/v1/me/')?.operationId, 'getMe');
      expect(
        matchRoute('GET', '/v1/diaries?limit=10')?.operationId,
        'listDiaries',
      );
    });

    test('route 표의 모든 operation이 자기 경로로 찾아진다', () {
      for (final route in apiRoutes) {
        final concrete = route.pathTemplate.replaceAllMapped(
          RegExp(r'\{[^}]+\}'),
          (_) => 'x',
        );
        expect(
          matchRoute(route.method, concrete)?.operationId,
          route.operationId,
          reason: '${route.method} ${route.pathTemplate}',
        );
      }
    });
  });
}
