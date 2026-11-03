import 'package:flutter/services.dart';

/// iOS 앱 추적 투명성(ATT) 허용 상태를 읽는 경계(결정 A101).
///
/// 권한 창은 앱이 직접 띄우지 않습니다. UMP 동의 창이 IDFA 안내 다음에 ATT를 묻고,
/// 광고 SDK는 허용 여부를 직접 읽습니다. 이 경계는 동의 결과 기록용입니다.
abstract interface class TrackingAuthorization {
  /// 사용자가 추적을 허용했는지. 읽지 못하면 던집니다.
  Future<bool> isAuthorized();
}

/// AppDelegate의 method channel로
/// `ATTrackingManager.trackingAuthorizationStatus`를 읽습니다.
final class ChannelTrackingAuthorization implements TrackingAuthorization {
  /// 경계를 만듭니다.
  const new();

  /// AppDelegate.swift의 채널 이름과 같습니다.
  static const channel = MethodChannel('app.myungli.diary/tracking');

  @override
  Future<bool> isAuthorized() async =>
      await channel.invokeMethod<String>('authorizationStatus') == 'authorized';
}
