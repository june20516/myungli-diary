import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/profile_patch.dart';
import 'package:myungli_diary/core/api/gen/model/schedule_patch.dart';

/// 요청을 기록하고 빈 JSON 객체로 답하는 어댑터.
class _RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _RecordingAdapter adapter;
  late DefaultApi api;

  setUp(() {
    adapter = _RecordingAdapter();
    api = DefaultApi(Dio()..httpClientAdapter = adapter);
  });

  test('프로필 수정은 application/merge-patch+json으로 나간다', () async {
    try {
      await api.updateProfile(profilePatch: ProfilePatch(honorific: '단비'));
    } on Object {
      // 빈 응답은 모델로 읽히지 않는다. 요청 쪽만 본다.
    }
    final request = adapter.requests.single;
    expect(request.method, 'PATCH');
    expect(request.contentType, 'application/merge-patch+json');
    expect(jsonDecode(request.data as String), {'honorific': '단비'});
  });

  test('일정 수정도 application/merge-patch+json으로 나간다', () async {
    try {
      await api.updateSchedule(id: 'abc', schedulePatch: SchedulePatch());
    } on Object {
      // 요청 쪽만 본다.
    }
    final request = adapter.requests.single;
    expect(request.path, '/v1/schedules/abc');
    expect(request.contentType, 'application/merge-patch+json');
  });

  test('format: date 경로 매개변수는 YYYY-MM-DD 그대로 나간다', () async {
    try {
      await api.getDaily(date: '2026-10-13');
    } on Object {
      // 요청 쪽만 본다.
    }
    expect(adapter.requests.single.path, '/v1/daily/2026-10-13');
  });
}
