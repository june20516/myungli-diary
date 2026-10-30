import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart' as gma;
import 'package:myungli_diary/core/platform/ad_consent.dart';

/// UMP(Google User Messaging Platform) 경계. SDK 호출을 옮기기만 하고 분기는
/// [UmpAdConsent]에 둡니다.
abstract interface class UmpApi {
  /// 동의 정보를 새로 받습니다. 실패하면 던집니다.
  Future<void> requestUpdate();

  /// 동의가 필요하면 동의 창을 띄우고 닫힐 때 끝납니다. 창 오류는 던집니다.
  Future<void> showFormIfRequired();

  /// 이 기기에 동의가 필요 없는지(동의 대상 지역 밖).
  Future<bool> consentNotRequired();
}

/// 실제 UMP SDK를 부르는 경계(기본값).
final class SdkUmpApi implements UmpApi {
  /// 경계를 만듭니다.
  const new();

  @override
  Future<void> requestUpdate() {
    final done = Completer<void>();
    gma.ConsentInformation.instance.requestConsentInfoUpdate(
      gma.ConsentRequestParameters(),
      done.complete,
      (error) => done.completeError(StateError('UMP ${error.errorCode}')),
    );
    return done.future;
  }

  @override
  Future<void> showFormIfRequired() {
    final done = Completer<void>();
    unawaited(
      gma.ConsentForm.loadAndShowConsentFormIfRequired((error) {
        if (error == null) {
          done.complete();
        } else {
          done.completeError(StateError('UMP 창 ${error.errorCode}'));
        }
      }),
    );
    return done.future;
  }

  @override
  Future<bool> consentNotRequired() async =>
      await gma.ConsentInformation.instance.getConsentStatus() ==
      gma.ConsentStatus.notRequired;
}

/// 광고 동의의 실제 구현(UMP, D53 ④, #686).
///
/// 처음 광고 전에 동의 정보를 받고, 필요한 지역이면 동의 창을 띄웁니다. AdMob 콘솔의 동의
/// 메시지는 개인정보처리방침 주소(E16) 뒤에 게시하므로, 그 전에 창이 없거나 오류여도 던지지
/// 않고 비맞춤으로 끝납니다. 광고 요청에 쓰는 동의 값은 SDK가 직접 읽고, 결과는 기록용입니다:
/// 동의 대상 지역 밖의 Android만 맞춤이고, 사용자가 고른 지역은 고른 값을 알 수 없어
/// 비맞춤으로 봅니다. iOS는 ATT를 아직 묻지 않아(권한 창 문구 원고 대기, 결정 A99) 비맞춤입니다.
final class UmpAdConsent implements AdConsent {
  /// adapter를 만듭니다.
  const new({required this.isIOS, this.api = const SdkUmpApi()});

  /// iOS인지.
  final bool isIOS;

  /// UMP 경계.
  final UmpApi api;

  @override
  Future<AdConsentResult> gather() async {
    try {
      await api.requestUpdate();
      await api.showFormIfRequired();
      if (isIOS || !await api.consentNotRequired()) {
        return AdConsentResult.nonPersonalized;
      }
      return AdConsentResult.personalized;
    } on Object {
      return AdConsentResult.nonPersonalized;
    }
  }
}
