import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/platform/device_info.dart';

void main() {
  group('AppDeviceInfo.of(계약 InquiryInput 형식)', () {
    test('정상 값은 그대로입니다', () {
      final info = AppDeviceInfo.of(
        appVersion: '1.0.0+5',
        os: 'Android 15',
        deviceModel: 'Google Pixel 8',
      );
      expect(info.appVersion, '1.0.0+5');
      expect(info.os, 'Android 15');
      expect(info.deviceModel, 'Google Pixel 8');
    });

    test('앱 버전은 허용 글자만 남기고, OS와 기종은 제어 문자를 뺍니다', () {
      final info = AppDeviceInfo.of(
        appVersion: '1.0.0 (5)',
        os: 'iOS\n18.1',
        deviceModel: 'iPhone15,2\t',
      );
      expect(info.appVersion, '1.0.05');
      expect(info.os, 'iOS 18.1');
      expect(info.deviceModel, 'iPhone15,2');
    });

    test('비면 unknown, 길면 상한까지 자릅니다', () {
      final info = AppDeviceInfo.of(
        appVersion: '',
        os: 'x' * 100,
        deviceModel: 'y' * 200,
      );
      expect(info.appVersion, 'unknown');
      expect(info.os, hasLength(64));
      expect(info.deviceModel, hasLength(128));
    });
  });

  test('대역은 기본 값을 돌려줍니다', () async {
    expect(
      await const FakeDeviceInfoReader().read(),
      FakeDeviceInfoReader.defaultInfo,
    );
  });
}
