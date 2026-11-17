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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "Distribution") {
      registerDistributionChannel(messenger: registrar.messenger())
    }
  }

  /// 앱이 TestFlight로 설치됐는지 Dart에 알려 주는 채널(#1258). 업데이트 안내의 스토어 버튼이
  /// TestFlight 설치본이면 TestFlight 앱을 엽니다. TestFlight 설치본의 App Store 영수증 이름은
  /// `sandboxReceipt`입니다. StoreKit 2 `AppTransaction`은 로컬에 없을 때 App Store 로그인 창을
  /// 띄울 수 있어 버튼을 누르는 순간에 쓰지 않습니다. 이름은 Dart `_distributionChannel`과 같습니다.
  private func registerDistributionChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "app.myungli.diary/distribution", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "isTestFlight" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt")
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
