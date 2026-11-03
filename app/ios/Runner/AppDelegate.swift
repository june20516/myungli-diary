import AppTrackingTransparency
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    excludeDatabaseDirectoryFromBackup()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TrackingAuthorization") {
      registerTrackingChannel(messenger: registrar.messenger())
    }
  }

  /// ATT 허용 상태를 Dart에 알려 주는 채널(결정 A101). 권한 창은 UMP 동의 창이 띄우고,
  /// 여기서는 상태만 읽습니다. 이름은 Dart `ChannelTrackingAuthorization.channel`과 같습니다.
  private func registerTrackingChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "app.myungli.diary/tracking", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "authorizationStatus" else {
        result(FlutterMethodNotImplemented)
        return
      }
      switch ATTrackingManager.trackingAuthorizationStatus {
      case .authorized: result("authorized")
      case .denied: result("denied")
      case .restricted: result("restricted")
      case .notDetermined: result("notDetermined")
      @unknown default: result("unknown")
      }
    }
  }

  /// 로컬 DB 디렉터리(Application Support/Database)를 iCloud·기기 백업에서 뺍니다.
  /// 일기 초안과 출생 정보가 새 기기로 옮겨지지 않게 합니다(Android 백업 끔과 대칭).
  /// 이름은 Dart `iosDatabaseDirectoryName`(lib/core/storage/app_database.dart)과 같습니다.
  /// 디렉터리에 건 표시는 안의 파일(DB, WAL 등)에도 적용됩니다.
  private func excludeDatabaseDirectoryFromBackup() {
    let fileManager = FileManager.default
    guard
      var directory = fileManager.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
      ).first?.appendingPathComponent("Database", isDirectory: true)
    else { return }
    do {
      try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try directory.setResourceValues(values)
    } catch {
      // 실패해도 앱은 뜹니다. 실행할 때마다 다시 시도합니다.
      NSLog("DB 디렉터리 백업 제외 실패: \(error.localizedDescription)")
    }
  }
}
