import Darwin
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "LegacyRecoveryCapacity"
    ) else { return }
    FlutterMethodChannel(
      name: "com.loosetie.triplingtable/recovery_capacity",
      binaryMessenger: registrar.messenger()
    ).setMethodCallHandler { call, result in
      guard call.method == "availableBytes" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
            let path = arguments["path"] as? String,
            path.hasPrefix("/"), !path.contains("\0") else {
        result(FlutterError(code: "capacity_unavailable",
                            message: "Destination capacity is unavailable.", details: nil))
        return
      }
      let directory = URL(fileURLWithPath: path, isDirectory: true)
      func isCanonicalDirectory() -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
          && isDirectory.boolValue
          && directory.resolvingSymlinksInPath().path == path
      }
      var stats = statfs()
      guard isCanonicalDirectory(), statfs(path, &stats) == 0,
            stats.f_bsize > 0 else {
        result(FlutterError(code: "capacity_unavailable",
                            message: "Destination capacity is unavailable.", details: nil))
        return
      }
      // f_bavail excludes blocks unavailable to unprivileged writers. Do not use
      // total free space or a purgeable/important-usage capacity estimate.
      let (bytes, overflow) = stats.f_bavail.multipliedReportingOverflow(
        by: UInt64(stats.f_bsize)
      )
      guard !overflow, bytes <= UInt64(Int64.max), isCanonicalDirectory() else {
        result(FlutterError(code: "capacity_unavailable",
                            message: "Destination capacity is unavailable.", details: nil))
        return
      }
      result(["path": path, "availableBytes": Int64(bytes)])
    }
  }
}
