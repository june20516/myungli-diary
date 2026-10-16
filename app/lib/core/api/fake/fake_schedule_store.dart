import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:uuid/uuid.dart';

/// 대역 저장소가 계약의 오류 응답(problem)으로 답할 때 던집니다.
final class FakeProblem implements Exception {
  /// [status]와 [code]의 problem 응답을 만듭니다.
  const new(this.status, this.code, this.title, this.detail);

  /// HTTP status.
  final int status;

  /// `Problem.code`.
  final String code;

  /// 개발자용 영어 제목.
  final String title;

  /// 설명.
  final String detail;

  @override
  String toString() => 'FakeProblem($status $code: $detail)';
}

/// 대역 서버의 일정 저장소. 대역 인스턴스 안에만 있어 앱을 다시 켜면
/// 처음 목록으로 돌아갑니다.
///
/// 계약(`listSchedules`·`createSchedule`·`updateSchedule`·`deleteSchedule`)의
/// 규칙을 따릅니다.
/// * 목록은 `from`~`to`(둘 다 포함)의 일정을 날짜 → 하루 종일 먼저 → 시각 →
///   만든 순서로 돌려줍니다.
/// * 고치기는 merge-patch입니다. `allDay`를 true로 바꾸면 `time`이 지워지고,
///   빈 `memo`는 지워집니다.
/// * 같은 `Idempotency-Key`로 같은 본문이 다시 오면 처음 응답을 돌려줍니다.
final class FakeScheduleStore {
  /// [seed] 일정(계약 `Schedule` JSON)으로 시작합니다.
  /// `nowUtc`(지금 UTC 시각)는 `createdAt`·`updatedAt`에 씁니다.
  new({required List<Map<String, Object?>> seed, required this._nowUtc}) {
    for (final schedule in seed) {
      _schedules[schedule['id']! as String] = Map.of(schedule);
    }
  }

  final DateTime Function() _nowUtc;
  final _uuid = const Uuid();

  /// id → 일정. 넣은 순서가 만든 순서입니다.
  final _schedules = <String, Map<String, Object?>>{};

  /// `Idempotency-Key` → (요청 본문, 처음 응답).
  final _idempotent =
      <String, ({Map<String, Object?> input, Map<String, Object?> response})>{};

  /// `listSchedules`: [from]~[to](포함) 일정 목록(`ScheduleList` JSON).
  Map<String, Object?> list({required String? from, required String? to}) {
    final start = _parseDate(from, 'from');
    final end = _parseDate(to, 'to');
    if (end.compareTo(start) < 0) {
      throw const FakeProblem(
        400,
        'request.invalid',
        'Invalid request',
        'to가 from보다 앞섭니다.',
      );
    }
    final items = _schedules.values.where((schedule) {
      final date = CalendarDate.parse(schedule['date']! as String);
      return date.compareTo(start) >= 0 && date.compareTo(end) <= 0;
    }).toList()..sort(_compareSchedules);
    return {
      'items': [for (final schedule in items) Map.of(schedule)],
    };
  }

  /// `createSchedule`: 새 일정(`Schedule` JSON).
  Map<String, Object?> create(Object? body, {String? idempotencyKey}) {
    final input = _inputFields(_decodeObject(body));
    if (idempotencyKey != null) {
      final previous = _idempotent[idempotencyKey];
      if (previous != null) {
        if (!mapEquals(previous.input, input)) {
          throw const FakeProblem(
            422,
            'idempotency.mismatch',
            'Idempotency key reused',
            '같은 Idempotency-Key에 다른 본문이 왔습니다.',
          );
        }
        return Map.of(previous.response);
      }
    }
    for (final field in ['date', 'allDay', 'title']) {
      if (!input.containsKey(field)) {
        throw FakeProblem(
          400,
          'request.invalid',
          'Invalid request',
          '$field가 없습니다.',
        );
      }
    }
    final now = _timestamp();
    final schedule = _validated({
      ...input,
      'id': _uuid.v4(),
      'createdAt': now,
      'updatedAt': now,
    });
    _schedules[schedule['id']! as String] = schedule;
    if (idempotencyKey != null) {
      _idempotent[idempotencyKey] = (input: input, response: schedule);
    }
    return Map.of(schedule);
  }

  /// `updateSchedule`: [id] 일정에 merge-patch [body]를 적용한 결과(`Schedule` JSON).
  Map<String, Object?> update(String id, Object? body) {
    final current = _find(id);
    final patch = _inputFields(_decodeObject(body));
    final merged = {...current, ...patch};
    if (patch['allDay'] == true && !patch.containsKey('time')) {
      merged.remove('time');
    }
    final schedule = _validated({...merged, 'updatedAt': _timestamp()});
    _schedules[id] = schedule;
    return Map.of(schedule);
  }

  /// `deleteSchedule`: [id] 일정을 지웁니다.
  void delete(String id) {
    _find(id);
    _schedules.remove(id);
  }

  Map<String, Object?> _find(String id) {
    final schedule = _schedules[id];
    if (schedule == null) {
      throw FakeProblem(
        404,
        'schedule.not_found',
        'Not found',
        '일정이 없습니다: $id',
      );
    }
    return schedule;
  }

  /// 계약 필드 규칙을 검사하고, 빈 `memo`를 뺀 일정을 돌려줍니다.
  Map<String, Object?> _validated(Map<String, Object?> schedule) {
    final date = schedule['date'];
    final allDay = schedule['allDay'];
    final title = schedule['title'];
    final time = schedule['time'];
    final memo = schedule['memo'];
    if (date is! String) {
      throw _invalid('date는 문자열이어야 합니다.');
    }
    _parseDate(date, 'date');
    if (allDay is! bool) {
      throw _invalid('allDay는 bool이어야 합니다.');
    }
    if (title is! String || title.isEmpty || title.length > _maxTitleLength) {
      throw _invalid('title은 1~$_maxTitleLength자여야 합니다.');
    }
    if (time != null && (time is! String || !_timePattern.hasMatch(time))) {
      throw _invalid('time은 HH:MM이어야 합니다.');
    }
    if (memo != null && (memo is! String || memo.length > _maxMemoLength)) {
      throw _invalid('memo는 0~$_maxMemoLength자여야 합니다.');
    }
    if (allDay == (time != null)) {
      throw FakeProblem(
        422,
        'request.inconsistent',
        'Inconsistent request',
        allDay ? '하루 종일 일정에는 time이 없어야 합니다.' : '시각 일정에는 time이 있어야 합니다.',
      );
    }
    return {...schedule}
      ..removeWhere((key, value) => key == 'memo' && value == '');
  }

  /// 시나리오 시계의 지금(RFC 3339 UTC, 초 단위).
  String _timestamp() {
    final now = _nowUtc().toUtc();
    return DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    ).toIso8601String().replaceFirst('.000Z', 'Z');
  }

  static const _maxTitleLength = 100;
  static const _maxMemoLength = 2000;
  static final _timePattern = RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$');
}

/// 날짜 → 하루 종일 먼저 → 시각 → 만든 순서.
int _compareSchedules(Map<String, Object?> a, Map<String, Object?> b) {
  final byDate = (a['date']! as String).compareTo(b['date']! as String);
  if (byDate != 0) {
    return byDate;
  }
  final aTime = a['time'] as String? ?? '';
  final bTime = b['time'] as String? ?? '';
  final byTime = aTime.compareTo(bTime);
  if (byTime != 0) {
    return byTime;
  }
  return (a['createdAt']! as String).compareTo(b['createdAt']! as String);
}

FakeProblem _invalid(String detail) =>
    FakeProblem(400, 'request.invalid', 'Invalid request', detail);

CalendarDate _parseDate(String? value, String name) {
  if (value == null) {
    throw _invalid('$name가 없습니다.');
  }
  try {
    return CalendarDate.parse(value);
  } on FormatException {
    throw _invalid('$name는 있는 YYYY-MM-DD 날짜여야 합니다: $value');
  }
}

/// 요청 본문에서 계약의 입력 필드(`ScheduleInput`·`SchedulePatch`)만 남깁니다.
/// `id`·`createdAt` 같은 서버 필드는 요청으로 바꿀 수 없습니다.
Map<String, Object?> _inputFields(Map<String, Object?> body) => {
  for (final entry in body.entries)
    if (_inputFieldNames.contains(entry.key)) entry.key: entry.value,
};

const _inputFieldNames = {'date', 'allDay', 'time', 'title', 'memo'};

/// 요청 본문(생성 클라이언트는 JSON 문자열, 직접 부르면 Map)을 객체로 읽습니다.
Map<String, Object?> _decodeObject(Object? body) {
  final decoded = body is String ? _tryDecode(body) : body;
  if (decoded is! Map) {
    throw const FakeProblem(
      400,
      'request.malformed',
      'Malformed request',
      '본문은 JSON 객체여야 합니다.',
    );
  }
  return Map<String, Object?>.from(decoded);
}

Object? _tryDecode(String source) {
  try {
    return jsonDecode(source);
  } on FormatException {
    return null;
  }
}
