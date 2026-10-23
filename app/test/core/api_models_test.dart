import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/me.dart';
import 'package:myungli_diary/core/api/gen/model/problem.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';

void main() {
  group('Me', () {
    const meJson = <String, Object?>{
      'accountId': '3f2c1a56-0000-4000-8000-000000000001',
      'consentRequired': false,
      'requiredConsents': <Object?>[],
      'hasProfile': true,
      'adFree': {'active': false},
      'insight': {'active': false},
    };

    test('필수 필드만 있는 JSON을 읽고, 생략한 필드를 null 키로 내보내지 않는다', () {
      final me = Me.fromJson(meJson);
      expect(me.accountId, '3f2c1a56-0000-4000-8000-000000000001');
      expect(me.adFree.expiresAt, isNull);

      final back = jsonDecode(jsonEncode(me.toJson())) as Map<String, Object?>;
      expect(back, meJson);
      expect((back['adFree']! as Map).containsKey('expiresAt'), isFalse);
    });
  });

  group('Problem', () {
    test('errors가 비어 있어도 읽힌다', () {
      final problem = Problem.fromJson(const {
        'type': 'https://api.myungli.app/problems/request.invalid',
        'title': 'Invalid request',
        'status': 400,
        'code': 'request.invalid',
        'traceId': 'trace-1',
        'errors': <Object?>[],
      });
      expect(problem.code, 'request.invalid');
      expect(problem.errors, isEmpty);
    });

    test('errors가 없어도 읽힌다', () {
      final problem = Problem.fromJson(const {
        'type': 'https://api.myungli.app/problems/auth.unauthorized',
        'title': 'Unauthorized',
        'status': 401,
        'code': 'auth.unauthorized',
        'traceId': 'trace-2',
      });
      expect(problem.status, 401);
    });
  });

  group('RenderedText·Segment', () {
    test('왕복해도 같은 JSON이다', () {
      final json = <String, Object?>{
        'segments': [
          {'text': '오늘은 '},
          {'text': '갑목', 'term': 'ganmok'},
        ],
      };
      final text = RenderedText.fromJson(json);
      expect(text.segments, hasLength(2));
      expect(text.segments.first, isA<Segment>());
      expect(text.segments.last.term, 'ganmok');
      expect(jsonDecode(jsonEncode(text.toJson())), json);
    });
  });
}
