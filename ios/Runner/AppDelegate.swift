import Flutter
import UIKit
import os

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var offlineChannel: FlutterMethodChannel?
  private var thermalObserver: NSObjectProtocol?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OfflineAiCapacity")!
    let channel = FlutterMethodChannel(name: "jlpt_practice/offline_ai", binaryMessenger: registrar.messenger())
    offlineChannel = channel
    channel.setMethodCallHandler { call, result in
      guard call.method == "capacity" else { result(FlutterMethodNotImplemented); return }
      do {
        var directory = try FileManager.default.url(for: .applicationSupportDirectory,
          in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("offline_ai")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        let disk = try directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let process = ProcessInfo.processInfo
        result([
          "totalRam": process.physicalMemory,
          "availableRam": UInt64(os_proc_available_memory()),
          "freeStorage": disk.volumeAvailableCapacityForImportantUsage ?? 0,
          "is64Bit": MemoryLayout<Int>.size == 8,
          "hot": process.thermalState == .serious || process.thermalState == .critical,
          "directory": directory.path
        ])
      } catch {
        result(FlutterError(code: "capacity", message: "Device capacity unavailable", details: nil))
      }
    }
    thermalObserver = NotificationCenter.default.addObserver(
      forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main
    ) { _ in
      let state = ProcessInfo.processInfo.thermalState
      if state == .serious || state == .critical {
        channel.invokeMethod("pressure", arguments: "thermal")
      }
    }
  }

  override func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
    super.applicationDidReceiveMemoryWarning(application)
    offlineChannel?.invokeMethod("pressure", arguments: "memory")
  }
}
