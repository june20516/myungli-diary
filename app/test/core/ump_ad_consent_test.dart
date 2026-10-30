import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/platform/ad_consent.dart';
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

void main() {
  late _Api api;

  setUp(() => api = _Api());

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

  test('iOS는 ATT 전이라 비맞춤', () async {
    expect(
      await UmpAdConsent(isIOS: true, api: api).gather(),
      AdConsentResult.nonPersonalized,
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
