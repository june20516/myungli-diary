import 'dart:async';

import 'package:dio/dio.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/identity.dart';
import 'package:myungli_diary/core/api/gen/model/identity_list.dart';
import 'package:myungli_diary/core/api/gen/model/link_identity_request.dart';
import 'package:myungli_diary/core/api/gen/model/login_provider.dart';

/// 실패 응답(problem+json) 하나를 만듭니다.
DioException problemOf(int status, String code) {
  final options = RequestOptions();
  return DioException.badResponse(
    statusCode: status,
    requestOptions: options,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: status,
      data: {'code': code, 'status': status, 'traceId': 'test'},
      headers: Headers.fromMap({
        Headers.contentTypeHeader: ['application/problem+json'],
      }),
    ),
  );
}

/// 연결 목록 server 대역입니다. 붙이기·떼기가 목록을 바꾸고, 호출을 기록합니다.
class FakeIdentityApi implements DefaultApi {
  /// [identities]는 처음 연결된 제공자(붙인 순서)입니다.
  new({List<LoginProvider>? identities})
    : identities = [
        ...(identities ?? [LoginProvider.kakao]),
      ];

  /// 지금 연결된 제공자.
  final List<LoginProvider> identities;

  /// `listIdentities` 호출 수.
  int listCalls = 0;

  /// `linkIdentity`로 요청한 제공자.
  final linkCalls = <LoginProvider>[];

  /// `unlinkIdentity`로 요청한 제공자.
  final unlinkCalls = <LoginProvider>[];

  /// `linkIdentity`가 낼 오류. null이면 성공.
  DioException? linkError;

  /// `unlinkIdentity`가 낼 오류. null이면 성공.
  DioException? unlinkError;

  /// 뗀 뒤 `listIdentities`가 낼 오류. null이면 성공.
  DioException? listError;

  /// 있으면 `linkIdentity`가 이 Future가 끝날 때까지 응답하지 않습니다.
  Completer<void>? linkGate;

  Response<T> _ok<T>(T data) => Response<T>(
    requestOptions: RequestOptions(),
    statusCode: 200,
    data: data,
  );

  IdentityList _list() => IdentityList(
    items: [
      for (final provider in identities)
        Identity(provider: provider, linkedAt: DateTime.utc(2026, 10)),
    ],
  );

  @override
  Future<Response<IdentityList>> listIdentities({
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    listCalls++;
    final error = listError;
    if (error != null) {
      throw error;
    }
    return _ok(_list());
  }

  @override
  Future<Response<IdentityList>> linkIdentity({
    required LoginProvider provider,
    required LinkIdentityRequest linkIdentityRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    linkCalls.add(provider);
    await linkGate?.future;
    final error = linkError;
    if (error != null) {
      throw error;
    }
    identities.add(provider);
    return _ok(_list());
  }

  @override
  Future<Response<void>> unlinkIdentity({
    required LoginProvider provider,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    unlinkCalls.add(provider);
    final error = unlinkError;
    if (error != null) {
      throw error;
    }
    identities.remove(provider);
    return _ok<void>(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
