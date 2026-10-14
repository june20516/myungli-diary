import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/birth_hour.dart';
import 'package:myungli_diary/core/api/gen/model/birth_hour_request.dart';
import 'package:myungli_diary/core/api/gen/model/branch.dart';
import 'package:myungli_diary/core/storage/installation_id.dart';
import 'package:myungli_diary/core/storage/secure_store.dart';
import 'package:myungli_diary/design/components/input/date_picker.dart';
import 'package:myungli_diary/features/onboarding/application/birth_hour_providers.dart';

/// `getBirthHour` 호출 수를 세는 대역. [fail]이면 [StateError]를 던집니다.
class _FakeApi implements DefaultApi {
  new({required this.fail});

  final bool fail;
  int calls = 0;

  @override
  Future<Response<BirthHour>> getBirthHour({
    required BirthHourRequest birthHourRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    calls++;
    if (fail) throw StateError('예상 밖 오류');
    return Response(
      requestOptions: RequestOptions(),
      data: BirthHour(branch: Branch.in_, start: '03:30', end: '05:30'),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

const BirthHourQuery _query = (
  date: BirthDateValue(
    calendar: BirthCalendar.solar,
    year: 1990,
    month: 5,
    day: 17,
  ),
  time: '04:00',
);

Future<void> _flush() => Future<void>.delayed(const Duration(milliseconds: 20));

ProviderContainer _container(_FakeApi api) {
  final container = ProviderContainer(
    overrides: [
      localeProvider.overrideWithValue(const Locale('ko', 'KR')),
      restClientProvider.overrideWithValue(api),
      installationIdProvider.overrideWith((ref) async => 'id'),
      secureStoreProvider.overrideWithValue(MemorySecureStore()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('AppError가 아닌 예외도 null이고, 붙들지 않아 다시 요청합니다', () async {
    final api = _FakeApi(fail: true);
    final container = _container(api);
    var sub = container.listen(birthHourProvider(_query), (_, _) {});
    expect(await container.read(birthHourProvider(_query).future), isNull);
    sub.close();
    await _flush();
    sub = container.listen(birthHourProvider(_query), (_, _) {});
    await container.read(birthHourProvider(_query).future);
    expect(api.calls, 2);
  });

  test('성공한 시진은 붙들어 다시 묻지 않고, 로그아웃하면 비웁니다', () async {
    final api = _FakeApi(fail: false);
    final container = _container(api);
    final tokens = container.read(tokenStoreProvider);
    final keep = container.listen(birthHourProvider(_query), (_, _) {});
    await container.read(birthHourProvider(_query).future);
    keep.close();
    await _flush();
    container.listen(birthHourProvider(_query), (_, _) {}).close();
    await container.read(birthHourProvider(_query).future);
    expect(api.calls, 1);
    await tokens.signOut();
    await _flush();
    await container.read(birthHourProvider(_query).future);
    expect(api.calls, 2);
  });
}
