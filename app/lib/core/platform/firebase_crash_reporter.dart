import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:myungli_diary/core/ia/ia_ids.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';

/// Firebase Crashlytics SDK 경계. SDK 호출을 그대로 옮기기만 하고 분기는
/// [FirebaseCrashReporter]에 둡니다.
abstract interface class CrashlyticsApi {
  /// 치명적이지 않은 오류를 기록합니다.
  Future<void> recordError(Object exception, StackTrace stack);

  /// 이후 기록에 붙일 사용자 식별값. 빈 문자열이면 지웁니다.
  Future<void> setUserIdentifier(String id);

  /// 이후 기록에 붙일 흔적 한 줄.
  Future<void> log(String message);

  /// 수집을 켜거나 끕니다.
  Future<void> setCollectionEnabled({required bool enabled});
}

/// 실제 Crashlytics SDK를 부르는 경계(기본값).
final class SdkCrashlyticsApi implements CrashlyticsApi {
  /// 경계를 만듭니다.
  const new();

  @override
  Future<void> recordError(Object exception, StackTrace stack) =>
      FirebaseCrashlytics.instance.recordError(exception, stack);

  @override
  Future<void> setUserIdentifier(String id) =>
      FirebaseCrashlytics.instance.setUserIdentifier(id);

  @override
  Future<void> log(String message) => FirebaseCrashlytics.instance.log(message);

  @override
  Future<void> setCollectionEnabled({required bool enabled}) =>
      FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled);
}

/// 비정상 종료 보고의 실제 구현(D64).
///
/// [CrashSummary](타입 이름, problem code, status)와 정제한 계정 id, IA 화면 id만
/// 보냅니다. 보고는 기다리지 않고, SDK 실패(Firebase 초기화 실패로 인한 동기 예외
/// 포함)는 삼켜 부르는 쪽을 막지 않습니다.
final class FirebaseCrashReporter implements CrashReporter {
  /// 보고 담당을 만듭니다.
  const new({this.api = const SdkCrashlyticsApi()});

  /// SDK 경계.
  final CrashlyticsApi api;

  @override
  void record(CrashSummary summary, StackTrace stack) =>
      _send(() => api.recordError(summary, stack));

  @override
  void setUser(String? accountId) =>
      _send(() => api.setUserIdentifier(sanitizeAccountId(accountId) ?? ''));

  @override
  void breadcrumb(String screenId) {
    final sanitized = sanitizeScreenId(screenId);
    if (sanitized == null) return;
    _send(() => api.log('screen: $sanitized'));
  }

  void _send(Future<void> Function() call) {
    try {
      unawaited(call().catchError((Object _) {}));
    } on Object {
      // 보고 실패는 앱 동작을 막지 않습니다.
    }
  }
}
