import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:myungli_diary/core/api/gen/model/chart.dart';
import 'package:myungli_diary/core/api/gen/model/consent_document.dart';
import 'package:myungli_diary/core/api/gen/model/daily.dart';
import 'package:myungli_diary/core/api/gen/model/entitlements.dart';
import 'package:myungli_diary/core/api/gen/model/focus_slot.dart';
import 'package:myungli_diary/core/api/gen/model/insight.dart';
import 'package:myungli_diary/core/api/gen/model/me.dart';
import 'package:myungli_diary/core/api/gen/model/notice_code.dart';
import 'package:myungli_diary/core/api/gen/model/personal_reading.dart';
import 'package:myungli_diary/core/api/gen/model/problem.dart';
import 'package:myungli_diary/core/api/gen/model/relation_kind.dart';
import 'package:myungli_diary/core/api/gen/model/shinsal_kind.dart';
import 'package:myungli_diary/core/api/gen/model/slot_text.dart';

/// 계약에 없는 값. 열린 enum이면 모르는 값으로 decode되고, 닫힌 enum이면 실패해야 합니다.
const _unknown = 'added_after_freeze';

Map<String, dynamic> _body(String fixture) =>
    (jsonDecode(File('fixtures/$fixture.json').readAsStringSync())
            as Map<String, dynamic>)['body']
        as Map<String, dynamic>;

Map<String, dynamic> _text(String text) => {
  'segments': [
    {'text': text},
  ],
};

void main() {
  group('열린 enum: 모르는 값이 와도 응답 전체 decode가 실패하지 않는다 (A66)', () {
    test(
      'Daily: NoticeCode·RelationKind·FocusSlot.reasons 항목·SlotText.variant',
      () {
        final json = _body('member/getDaily');
        (json['notices'] as List<dynamic>).add({
          'code': _unknown,
          'text': _text('새 안내'),
        });
        (json['relations'] as List<dynamic>).add({
          'kind': _unknown,
          'natalPosition': 'day_stem',
          'suppressed': true,
          'suppressedBy': _unknown,
        });
        final cards = json['cards'] as Map<String, dynamic>;
        final focus = cards['focusTime'] as Map<String, dynamic>;
        final pick =
            (focus['picks'] as List<dynamic>).first as Map<String, dynamic>;
        (pick['reasons'] as List<dynamic>).add(_unknown);
        (json['guide'] as Map<String, dynamic>)['variant'] = _unknown;

        final daily = Daily.fromJson(json);

        final notice = daily.notices.last;
        expect(notice.code, NoticeCode.unknownDefaultOpenApi);
        expect(notice.code.isKnown, isFalse);
        expect(notice.text.segments.single.text, '새 안내');

        final relation = daily.relations.last;
        expect(relation.kind, RelationKind.unknownDefaultOpenApi);
        expect(relation.suppressedBy, RelationKind.unknownDefaultOpenApi);

        // 목록 항목은 그 항목만 모르는 값이고 나머지는 그대로입니다.
        expect(daily.cards.focusTime.picks.first.reasons, [
          FocusSlotReasonsEnum.yongsin,
          FocusSlotReasonsEnum.unknownDefaultOpenApi,
        ]);
        expect(
          daily.cards.focusTime.picks.first.reasons.where((r) => r.isKnown),
          [FocusSlotReasonsEnum.yongsin],
        );

        // 모르는 variant는 기본 표시: 문장은 그대로 남습니다.
        expect(daily.guide.variant, SlotTextVariantEnum.unknownDefaultOpenApi);
        expect(daily.guide.text.segments, isNotEmpty);
      },
    );

    test('Chart: ShinsalKind·PersonalReading.kind·세운 RelationKind 항목', () {
      final json = _body('evidence-unlocked/getChart');
      (json['shinsal'] as List<dynamic>).add({
        'kind': _unknown,
        'position': 'day_branch',
      });
      (json['personalReadings'] as List<dynamic>)
        ..add({'kind': _unknown, 'text': _text('새 항목')})
        ..add({
          'kind': 'shinsal',
          'position': 'day_branch',
          'shinsal': _unknown,
          'text': _text('새 신살'),
        });
      final seun = json['seun'] as List<dynamic>;
      ((seun.first as Map<String, dynamic>)['relationsWithNatal']
              as List<dynamic>)
          .add(_unknown);

      final chart = Chart.fromJson(json);

      expect(chart.shinsal.last.kind, ShinsalKind.unknownDefaultOpenApi);
      expect(chart.shinsal.last.kind.isKnown, isFalse);
      expect(chart.shinsal.first.kind.isKnown, isTrue);
      final readings = chart.personalReadings!;
      expect(
        readings[readings.length - 2].kind,
        PersonalReadingKindEnum.unknownDefaultOpenApi,
      );
      expect(readings.last.shinsal, ShinsalKind.unknownDefaultOpenApi);
      expect(
        chart.seun.first.relationsWithNatal.last,
        RelationKind.unknownDefaultOpenApi,
      );
    });

    test('Me: ConsentDocument.document·Insight.source', () {
      final json = _body('member/getMe')
        ..['consentRequired'] = true
        ..['requiredConsents'] = [
          {'document': 'terms', 'version': '2026-10-01'},
          {'document': _unknown, 'version': '2026-10-01'},
        ]
        ..['insight'] = {
          'active': true,
          'expiresAt': '2026-10-21T00:00:00Z',
          'source': _unknown,
        };

      final me = Me.fromJson(json);

      expect(me.requiredConsents.map((d) => d.document), [
        ConsentDocumentDocumentEnum.terms,
        ConsentDocumentDocumentEnum.unknownDefaultOpenApi,
      ]);
      expect(me.insight.source_, InsightSource_Enum.unknownDefaultOpenApi);
      expect(me.insight.source_!.isKnown, isFalse);
      // 열람 권한 판단은 source가 아니라 active입니다.
      expect(me.insight.active, isTrue);
    });

    test('Entitlements: Insight.source', () {
      final json = _body('member/getEntitlements');
      json['insight'] = {
        'active': true,
        'expiresAt': '2026-10-21T00:00:00Z',
        'source': _unknown,
      };
      final entitlements = Entitlements.fromJson(json);
      expect(
        entitlements.insight.source_,
        InsightSource_Enum.unknownDefaultOpenApi,
      );
    });

    test('Problem.code는 enum이 아닌 string이라 모르는 code도 그대로 읽는다', () {
      final problem = Problem.fromJson({
        'type': 'https://api.myungli.app/problems/$_unknown',
        'title': 'New',
        'status': 409,
        'code': 'future.code',
        'traceId': 't1',
      });
      expect(problem.code, 'future.code');
    });

    test('아는 값은 isKnown이 true다', () {
      expect(NoticeCode.timeUnknown.isKnown, isTrue);
      expect(ShinsalKind.dohwa.isKnown, isTrue);
      expect(RelationKind.chung.isKnown, isTrue);
      expect(
        PersonalReadingKindEnum.PersonalReadingKindShinsal.isKnown,
        isTrue,
      );
      expect(FocusSlotReasonsEnum.gwiin.isKnown, isTrue);
      expect(SlotTextVariantEnum.single.isKnown, isTrue);
      expect(InsightSource_Enum.subscription.isKnown, isTrue);
      expect(ConsentDocumentDocumentEnum.privacy.isKnown, isTrue);
    });

    test('모르는 값은 캐시에 쓴 뒤 다시 읽어도 모르는 값이다', () {
      final json = _body('member/getDaily');
      (json['notices'] as List<dynamic>).add({
        'code': _unknown,
        'text': _text('새 안내'),
      });
      final daily = Daily.fromJson(json);
      final again = Daily.fromJson(
        jsonDecode(jsonEncode(daily.toJson())) as Map<String, dynamic>,
      );
      expect(again.notices.last.code, NoticeCode.unknownDefaultOpenApi);
    });
  });

  test('열린 enum SlotText.reaction: 모르는 값은 모르는 값으로 decode된다 (A78)', () {
    final json = _body('member/getDaily');
    ((json['fortune'] as Map<String, dynamic>)['head']
            as Map<String, dynamic>)['reaction'] =
        _unknown;
    expect(
      Daily.fromJson(json).fortune.head.reaction,
      SlotTextReactionEnum.unknownDefaultOpenApi,
    );
  });

  group('닫힌 enum: 모르는 값은 지금처럼 decode 실패다', () {
    test('Daily.dayKind', () {
      final json = _body('member/getDaily')..['dayKind'] = _unknown;
      expect(
        () => Daily.fromJson(json),
        throwsA(isA<CheckedFromJsonException>()),
      );
    });

    test('ShinsalAt.position(Position)', () {
      final json = _body('member/getChart');
      ((json['shinsal'] as List<dynamic>).first
              as Map<String, dynamic>)['position'] =
          _unknown;
      expect(
        () => Chart.fromJson(json),
        throwsA(isA<CheckedFromJsonException>()),
      );
    });
  });

  group('모르는 응답 필드는 무시한다', () {
    test('최상위와 안쪽 객체의 모르는 키', () {
      final json = _body('member/getDaily')..['addedField'] = {'x': 1};
      ((json['fortune'] as Map<String, dynamic>)['head']
              as Map<String, dynamic>)['addedField'] =
          'y';
      (json['notices'] as List<dynamic>).add({
        'code': 'time_unknown',
        'text': _text('시간 모름'),
        'addedField': true,
      });
      final daily = Daily.fromJson(json);
      expect(daily.notices.last.code, NoticeCode.timeUnknown);
    });

    test('ConsentDocument·Insight의 모르는 키', () {
      final document = ConsentDocument.fromJson({
        'document': 'terms',
        'version': 'v1',
        'title': '새 필드',
      });
      expect(document.document, ConsentDocumentDocumentEnum.terms);
      final insight = Insight.fromJson({'active': false, 'tier': 'x'});
      expect(insight.active, isFalse);
    });

    test('PersonalReading의 모르는 키', () {
      final reading = PersonalReading.fromJson({
        'kind': 'day_master',
        'position': 'day_stem',
        'text': _text('일간'),
        'addedField': 1,
      });
      expect(
        reading.kind,
        PersonalReadingKindEnum.PersonalReadingKindDayMaster,
      );
    });
  });
}
