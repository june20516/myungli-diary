import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/platform/ad_consent.dart';
import 'package:myungli_diary/core/platform/tracking_authorization.dart';
import 'package:myungli_diary/core/platform/ump_ad_consent.dart';

/// UMP 경계 대역.
class _Api implements UmpApi {
  final List<String> calls = [];
  bool updateFails = false;
  bool formFails = false;
  bool notRequired = true;

  @override
  Future<void> requestUpdate() async {
    calls.add('update');
    if (updateFails) throw StateError('update');
  }

  @override
  Future<void> showFormIfRequired() async {
    calls.add('form');
    if (formFails) throw StateError('form');
  }

  @override
  Future<bool> consentNotRequired() async => notRequired;
}

/// ATT 상태 대역.
class _Tracking implements TrackingAuthorization {
  bool authorized = true;
  bool fails = false;

  @override
  Future<bool> isAuthorized() async {
    if (fails) throw StateError('tracking');
    return authorized;
  }
}

void main() {
  late _Api api;
  late _Tracking tracking;

  setUp(() {
    api = _Api();
    tracking = _Tracking();
  });

  test('동의 정보를 받고 필요하면 동의 창을 띄웁니다(UMP 먼저)', () async {
    await UmpAdConsent(isIOS: false, api: api).gather();
    expect(api.calls, ['update', 'form']);
  });

  test('Android에서 동의가 필요 없는 지역이면 맞춤 광고', () async {
    expect(
      await UmpAdConsent(isIOS: false, api: api).gather(),
      AdConsentResult.personalized,
    );
  });

  test('동의가 필요한 지역(사용자가 고름)은 비맞춤으로 봅니다', () async {
    api.notRequired = false;
    expect(
      await UmpAdConsent(isIOS: false, api: api).gather(),
      AdConsentResult.nonPersonalized,
    );
  });

  test('iOS는 ATT 허용이고 동의가 필요 없는 지역이면 맞춤 광고(A101)', () async {
    expect(
      await UmpAdConsent(isIOS: true, api: api, tracking: tracking).gather(),
      AdConsentResult.personalized,
    );
  });

  test('iOS에서 ATT를 허용하지 않았거나 동의가 필요한 지역이면 비맞춤', () async {
    tracking.authorized = false;
    expect(
      await UmpAdConsent(isIOS: true, api: api, tracking: tracking).gather(),
      AdConsentResult.nonPersonalized,
    );

    tracking.authorized = true;
    api.notRequired = false;
    expect(
      await UmpAdConsent(isIOS: true, api: api, tracking: tracking).gather(),
      AdConsentResult.nonPersonalized,
    );
  });

  test('iOS에서 ATT 상태를 읽지 못하면 던지지 않고 비맞춤', () async {
    tracking.fails = true;
    expect(
      await UmpAdConsent(isIOS: true, api: api, tracking: tracking).gather(),
      AdConsentResult.nonPersonalized,
    );
  });

  test('Android는 ATT 상태를 읽지 않습니다', () async {
    tracking.fails = true;
    expect(
      await UmpAdConsent(isIOS: false, api: api, tracking: tracking).gather(),
      AdConsentResult.personalized,
    );
  });

  test('정보 받기나 창이 실패해도(메시지 없음 포함) 던지지 않고 비맞춤', () async {
    api.updateFails = true;
    expect(
      await UmpAdConsent(isIOS: false, api: api).gather(),
      AdConsentResult.nonPersonalized,
    );
    expect(api.calls, ['update']);

    api
      ..updateFails = false
      ..formFails = true
      ..calls.clear();
    expect(
      await UmpAdConsent(isIOS: false, api: api).gather(),
      AdConsentResult.nonPersonalized,
    );
  });
}
