import Flutter
import UIKit
import MetricKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, MXMetricManagerSubscriber {
  private let crashKey = "pagestage.nativeCrashes.v1"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 14.0, *) {
      MXMetricManager.shared.add(self)
      collect(MXMetricManager.shared.pastDiagnosticPayloads)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PagestageDiagnostics") else { return }
    let channel = FlutterMethodChannel(name: "pagestage/diagnostics", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "snapshot":
        if #available(iOS 14.0, *) { self.collect(MXMetricManager.shared.pastDiagnosticPayloads) }
        result([
          "platform": "ios", "osVersion": UIDevice.current.systemVersion,
          "appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
          "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0",
          "crashes": UserDefaults.standard.array(forKey: self.crashKey) ?? []
        ])
      case "feedback":
        UIApplication.shared.open(URL(string: "https://github.com/dayeguilaiye/pagestage/issues/new")!) { success in
          result(success ? nil : FlutterError(code: "diagnostics_failed", message: "Browser unavailable", details: nil))
        }
      case "share":
        guard let args = call.arguments as? [String: Any], let path = args["path"] as? String,
              let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
          result(FlutterError(code: "diagnostics_failed", message: "Report unavailable", details: nil)); return
        }
        let file = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        let allowed = support.appendingPathComponent("diagnostics/pagestage-diagnostics.json").resolvingSymlinksInPath()
        guard file == allowed, FileManager.default.fileExists(atPath: file.path), let presenter = self.presenter() else {
          result(FlutterError(code: "diagnostics_failed", message: "Report unavailable", details: nil)); return
        }
        let sheet = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        if let popover = sheet.popoverPresentationController {
          popover.sourceView = presenter.view
          popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
          popover.permittedArrowDirections = []
        }
        presenter.present(sheet, animated: true) { result(nil) }
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private func presenter() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    var view = scenes.flatMap(\.windows).first(where: { $0.isKeyWindow })?.rootViewController
    while let next = view?.presentedViewController { view = next }
    return view
  }

  @available(iOS 14.0, *)
  func didReceive(_ payloads: [MXDiagnosticPayload]) { collect(payloads) }

  @available(iOS 14.0, *)
  private func collect(_ payloads: [MXDiagnosticPayload]) {
    var records = UserDefaults.standard.array(forKey: crashKey) as? [[String: Any]] ?? []
    for payload in payloads {
      for crash in payload.crashDiagnostics ?? [] {
        // Numeric system diagnostics only; no raw termination reason, message,
        // stack dump or application-supplied metadata is persisted.
        var record: [String: Any] = ["timestamp": Int64(payload.timeStampEnd.timeIntervalSince1970 * 1000)]
        if let signal = crash.signal { record["signal"] = signal }
        if let type = crash.exceptionType { record["exceptionType"] = type }
        if let code = crash.exceptionCode { record["exceptionCode"] = code }
        if !records.contains(where: { NSDictionary(dictionary: $0).isEqual(to: record) }) { records.append(record) }
      }
    }
    UserDefaults.standard.set(Array(records.suffix(32)), forKey: crashKey)
  }
}
