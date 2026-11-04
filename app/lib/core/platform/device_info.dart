import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 문의에 함께 보내는 앱과 기기 정보(D102 ①, 계약 `InquiryInput`).
///
/// 사용자가 고칠 수 없는 값입니다. 계약의 글자 형식과 길이 안에 들도록 [AppDeviceInfo.of]가
/// 다듬습니다.
@immutable
final class AppDeviceInfo {
  /// 이미 다듬은 값으로 만듭니다.
  const new _({
    required this.appVersion,
    required this.os,
    required this.deviceModel,
  });

  /// 읽은 값을 계약 형식에 맞게 다듬어 만듭니다.
  ///
  /// [appVersion]은 영문, 숫자, `.+_-` 밖의 글자를 빼고 64자, [os]는 64자, [deviceModel]은
  /// 128자까지이며 둘은 제어 문자를 뺍니다. 비면 `unknown`입니다.
  factory of({
    required String appVersion,
    required String os,
    required String deviceModel,
  }) => AppDeviceInfo._(
    appVersion: _fit(
      appVersion.replaceAll(RegExp('[^0-9A-Za-z.+_-]'), ''),
      _versionMax,
    ),
    os: _fit(_withoutControls(os), _osMax),
    deviceModel: _fit(_withoutControls(deviceModel), _modelMax),
  );

  static const int _versionMax = 64;
  static const int _osMax = 64;
  static const int _modelMax = 128;

  static String _withoutControls(String value) =>
      value.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ').trim();

  static String _fit(String value, int max) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'unknown';
    return trimmed.length <= max ? trimmed : trimmed.substring(0, max);
  }

  /// 앱 버전과 빌드 번호(예 `1.0.0+5`).
  final String appVersion;

  /// OS 이름과 버전(예 `Android 15`, `iOS 18.1`).
  final String os;

  /// 기종(예 `Google Pixel 8`, `iPhone15,2`).
  final String deviceModel;

  @override
  bool operator ==(Object other) =>
      other is AppDeviceInfo &&
      other.appVersion == appVersion &&
      other.os == os &&
      other.deviceModel == deviceModel;

  @override
  int get hashCode => Object.hash(appVersion, os, deviceModel);
}

/// 앱과 기기 정보를 읽는 경계.
abstract interface class DeviceInfoReader {
  /// 정보를 읽습니다. 실패는 던집니다.
  Future<AppDeviceInfo> read();
}

/// 실제 플랫폼 값을 읽습니다(`package_info_plus`, `device_info_plus`).
final class PlatformDeviceInfoReader implements DeviceInfoReader {
  /// [platform]의 값을 읽는 경계를 만듭니다.
  const new({required this.platform});

  /// 실행 플랫폼.
  final TargetPlatform platform;

  @override
  Future<AppDeviceInfo> read() async {
    final package = await PackageInfo.fromPlatform();
    final appVersion = package.buildNumber.isEmpty
        ? package.version
        : '${package.version}+${package.buildNumber}';
    final plugin = DeviceInfoPlugin();
    switch (platform) {
      case TargetPlatform.android:
        final android = await plugin.androidInfo;
        return AppDeviceInfo.of(
          appVersion: appVersion,
          os: 'Android ${android.version.release}',
          deviceModel: '${android.manufacturer} ${android.model}',
        );
      case TargetPlatform.iOS:
        final ios = await plugin.iosInfo;
        return AppDeviceInfo.of(
          appVersion: appVersion,
          os: '${ios.systemName} ${ios.systemVersion}',
          deviceModel: ios.utsname.machine,
        );
      case TargetPlatform.fuchsia ||
          TargetPlatform.linux ||
          TargetPlatform.macOS ||
          TargetPlatform.windows:
        return AppDeviceInfo.of(
          appVersion: appVersion,
          os: platform.name,
          deviceModel: platform.name,
        );
    }
  }
}

/// 고정 값을 돌려주는 대역(fake 모드, 테스트).
final class FakeDeviceInfoReader implements DeviceInfoReader {
  /// [info]를 돌려주는 대역입니다.
  const new([this.info = defaultInfo]);

  /// 대역 기본값.
  static const AppDeviceInfo defaultInfo = AppDeviceInfo._(
    appVersion: '1.0.0+1',
    os: 'Android 15',
    deviceModel: 'Fake Device',
  );

  /// 돌려줄 값.
  final AppDeviceInfo info;

  @override
  Future<AppDeviceInfo> read() async => info;
}

/// 앱과 기기 정보. 기본은 대역이고, 실제 구현은 부팅이 끼웁니다.
final deviceInfoReaderProvider = Provider<DeviceInfoReader>(
  (ref) => const FakeDeviceInfoReader(),
);
