import 'dart:async';

import 'package:dio/dio.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/ad_free.dart';
import 'package:myungli_diary/core/api/gen/model/identity.dart';
import 'package:myungli_diary/core/api/gen/model/identity_list.dart';
import 'package:myungli_diary/core/api/gen/model/insight.dart';
import 'package:myungli_diary/core/api/gen/model/link_identity_request.dart';
import 'package:myungli_diary/core/api/gen/model/login_provider.dart';
import 'package:myungli_diary/core/api/gen/model/me.dart';
import 'package:myungli_diary/core/api/gen/model/merge_added_days.dart';
import 'package:myungli_diary/core/api/gen/model/merge_preview.dart';
import 'package:myungli_diary/core/api/gen/model/merge_preview_request.dart';
import 'package:myungli_diary/core/api/gen/model/merge_profile.dart';
import 'package:myungli_diary/core/api/gen/model/merge_profile_summary.dart';
import 'package:myungli_diary/core/api/gen/model/merge_request.dart';
import 'package:myungli_diary/core/api/gen/model/merge_summary.dart';

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

/// 응답 없음(연결 끊김) 하나를 만듭니다.
DioException connectionLost() => DioException.connectionError(
  requestOptions: RequestOptions(path: '/v1/me/merge'),
  reason: '테스트 연결 끊김',
);

/// 응답 없음(받기 시간 초과) 하나를 만듭니다.
DioException receiveTimeout() => DioException.receiveTimeout(
  timeout: const Duration(seconds: 30),
  requestOptions: RequestOptions(path: '/v1/me/merge'),
);

/// 합친 뒤의 내 정보(유저 계정 A).
Me mergedMe({bool hasProfile = true, bool adFree = true}) => Me(
  accountId: '00000000-0000-4000-8000-00000000000a',
  consentRequired: false,
  requiredConsents: const [],
  hasProfile: hasProfile,
  adFree: AdFree(active: adFree),
  insight: Insight(active: false),
);

/// 합치기 요약. 기본은 fake 모드 대역과 같은 값입니다.
MergePreview mergePreview({
  String token = 'merge-token-1',
  int diaries = 2,
  int schedules = 0,
  int overlapDays = 1,
  int adFreeDays = 12,
  MergeProfileSummary? current,
  MergeProfileSummary? other,
}) => MergePreview(
  mergeToken: token,
  expiresAt: DateTime.utc(2030),
  summary: MergeSummary(
    diaries: diaries,
    schedules: schedules,
    dateRecords: 0,
    reactions: 0,
    overlapDays: overlapDays,
    addedDays: MergeAddedDays(adFree: adFreeDays),
    current:
        current ??
        MergeProfileSummary(
          status: MergeProfileSummaryStatusEnum.saved,
          honorific: '하늘',
        ),
    other:
        other ??
        MergeProfileSummary(
          status: MergeProfileSummaryStatusEnum.saved,
          honorific: '바다',
        ),
  ),
);

/// `mergeAccounts` 요청 하나의 기록.
typedef MergeCall = ({String token, MergeProfile profile, String? key});

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

  /// 있으면 `unlinkIdentity`가 이 예외를 던집니다(AppError가 아닌 예외).
  StateError? unlinkThrows;

  /// 있으면 `listIdentities`가 이 예외를 던집니다(AppError가 아닌 예외).
  StateError? listThrows;

  /// 뗀 뒤 `listIdentities`가 낼 오류. null이면 성공.
  DioException? listError;

  /// 있으면 `linkIdentity`가 이 Future가 끝날 때까지 응답하지 않습니다.
  Completer<void>? linkGate;

  /// 지금까지 부른 요청 이름(operationId) 순서.
  final operations = <String>[];

  /// `previewMerge`로 요청한 제공자.
  final previewCalls = <LoginProvider>[];

  /// `previewMerge`가 낼 오류. null이면 [preview]를 돌려줍니다.
  DioException? previewError;

  /// `previewMerge`의 응답.
  MergePreview preview = mergePreview();

  /// 있으면 `previewMerge`가 이 Future가 끝날 때까지 응답하지 않습니다.
  Completer<void>? previewGate;

  /// `mergeAccounts` 요청 기록.
  final mergeCalls = <MergeCall>[];

  /// `mergeAccounts`가 차례로 낼 응답. [DioException]이면 던지고 [Me]면 돌려줍니다. 다 쓰면
  /// [mergeMe]입니다.
  final mergeAnswers = <Object>[];

  /// `mergeAccounts`의 기본 응답.
  Me mergeMe = mergedMe();

  /// 있으면 `mergeAccounts`가 이 Future가 끝날 때까지 응답하지 않습니다.
  Completer<void>? mergeGate;

  @override
  Future<Response<MergePreview>> previewMerge({
    required MergePreviewRequest mergePreviewRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    operations.add('previewMerge');
    previewCalls.add(mergePreviewRequest.provider);
    await previewGate?.future;
    final error = previewError;
    if (error != null) {
      throw error;
    }
    return _ok(preview);
  }

  @override
  Future<Response<Me>> mergeAccounts({
    required MergeRequest mergeRequest,
    String? idempotencyKey,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    operations.add('mergeAccounts');
    mergeCalls.add((
      token: mergeRequest.mergeToken,
      profile: mergeRequest.profile,
      key: idempotencyKey,
    ));
    await mergeGate?.future;
    if (mergeAnswers.isEmpty) {
      return _ok(mergeMe);
    }
    final answer = mergeAnswers.removeAt(0);
    if (answer is DioException) {
      throw answer;
    }
    return _ok(answer as Me);
  }

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
    operations.add('listIdentities');
    listCalls++;
    final thrown = listThrows;
    if (thrown != null) {
      throw thrown;
    }
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
    operations.add('linkIdentity');
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
    operations.add('unlinkIdentity');
    unlinkCalls.add(provider);
    final thrown = unlinkThrows;
    if (thrown != null) {
      throw thrown;
    }
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
