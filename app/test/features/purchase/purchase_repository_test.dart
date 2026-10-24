import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/fake/scenario.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/purchase_status.dart';
import 'package:myungli_diary/features/purchase/data/purchase_repository.dart';

Future<(PurchaseRepository, FakeServerInterceptor)> _repository({
  bool restoreUnavailable = false,
}) async {
  final scenario = (await loadScenarios(rootBundle))
      .singleWhere((s) => s.id == 'ad-free-active');
  final server = FakeServerInterceptor(scenario: scenario, bundle: rootBundle);
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'));
  if (restoreUnavailable) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final response = Response<Object?>(
            requestOptions: options,
            statusCode: 503,
            headers: Headers.fromMap({
              Headers.contentTypeHeader: ['application/problem+json'],
            }),
            data: <String, Object?>{
              'status': 503,
              'code': 'billing.provider_unavailable',
              'traceId': 't',
            },
          );
          handler.reject(
            DioException.badResponse(
              statusCode: 503,
              requestOptions: options,
              response: response,
            ),
            true,
          );
        },
      ),
    );
  }
  dio.interceptors.add(server);
  return (PurchaseRepository(DefaultApi(dio)), server);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('list는 fixture 순서 그대로 돌려줍니다', () async {
    final (repository, _) = await _repository();
    final purchases = await repository.list();
    expect(purchases.map((p) => p.status), [
      PurchaseStatus.active,
      PurchaseStatus.refunded,
      PurchaseStatus.expired,
      PurchaseStatus.expired,
    ]);
    expect(purchases.last.period, isNull);
  });

  test('reconcile은 POST /v1/billing/restore를 한 번 부릅니다', () async {
    final (repository, server) = await _repository();
    await repository.reconcile();
    expect(server.callCountOf('restorePurchases'), 1);
  });

  test('503이면 billing.provider_unavailable ProblemError', () async {
    final (repository, _) = await _repository(restoreUnavailable: true);
    await expectLater(
      repository.reconcile(),
      throwsA(
        isA<ProblemError>().having(
          (e) => e.code,
          'code',
          'billing.provider_unavailable',
        ),
      ),
    );
  });
}
