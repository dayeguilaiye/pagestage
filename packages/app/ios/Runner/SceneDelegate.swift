import Flutter
import UIKit
import UniformTypeIdentifiers

class SceneDelegate: FlutterSceneDelegate {
  // A file another app opened in pagestage while it was not running.
  override func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    IncomingFiles.shared.receive(connectionOptions.urlContexts.map(\.url))
  }

  // A file another app opened in pagestage while it runs. Any other URL goes
  // on to Flutter's plugins.
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    let files = URLContexts.filter { $0.url.isFileURL }
    IncomingFiles.shared.receive(files.map(\.url))
    let others = URLContexts.subtracting(files)
    if !others.isEmpty { super.scene(scene, openURLContexts: others) }
  }
}

/// Files other apps open in pagestage ("Open in…"). Each is copied into
/// tmp/incoming/<id>/ under its own name, and the copy's path handed to Dart
/// over `pagestage/incoming`. Paths wait until Dart calls `ready`, so a file
/// that launched the app is kept while Flutter starts. Dart imports the copy
/// and deletes it.
final class IncomingFiles {
  static let shared = IncomingFiles()

  private var channel: FlutterMethodChannel?
  private var listening = false
  private var waiting: [String] = []
  private let copying = DispatchQueue(label: "pagestage.incoming")

  /// Called for each engine: Dart in a new one has not listened yet.
  func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "pagestage/incoming", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self, call.method == "ready" else { result(FlutterMethodNotImplemented); return }
      self.listening = true
      result(self.waiting)
      self.waiting.removeAll()
    }
    self.channel = channel
    listening = false
  }

  /// On the main thread.
  func receive(_ urls: [URL]) {
    for url in urls where url.isFileURL {
      copying.async {
        let path = IncomingFiles.copy(url)
        DispatchQueue.main.async { self.deliver(path) }
      }
    }
  }

  private func deliver(_ path: String) {
    guard listening, let channel else { waiting.append(path); return }
    channel.invokeMethod("open", arguments: path) { [weak self] reply in
      // Dart stopped listening, after a restart say: the file waits for the
      // next `ready`.
      guard let self, let reply = reply as? NSObject,
            reply === FlutterMethodNotImplemented || reply is FlutterError else { return }
      self.listening = false
      self.waiting.append(path)
    }
  }

  /// The copy's path. A file that cannot be read still gets one, with
  /// nothing there, so Dart's import reports it unreadable by name.
  private static func copy(_ url: URL) -> String {
    let manager = FileManager.default
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    let folder = manager.temporaryDirectory
      .appendingPathComponent("incoming", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let copy = folder.appendingPathComponent(name(of: url))
    do {
      try manager.createDirectory(at: folder, withIntermediateDirectories: true)
      try manager.copyItem(at: url, to: copy)
      // The copy the system made for pagestage is not needed any more.
      if isInbox(url) { try? manager.removeItem(at: url) }
    } catch {
      // Reported by the import.
    }
    return copy.path
  }

  /// The file's own name made safe, with an extension the import knows
  /// added when it has none.
  private static func name(of url: URL) -> String {
    var name = url.lastPathComponent
      .components(separatedBy: CharacterSet(charactersIn: "/:\\").union(.controlCharacters))
      .joined(separator: "_")
      .trimmingCharacters(in: .whitespaces)
    if name.isEmpty || name == "." || name == ".." { name = "book" }
    if (name as NSString).pathExtension.isEmpty,
       let type = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType {
      if type.conforms(to: .plainText) {
        name += ".txt"
      } else if type.conforms(to: .epub) {
        name += ".epub"
      }
    }
    return name
  }

  /// Whether `url` is the copy the system made in pagestage's own inbox:
  /// Documents/Inbox, or tmp/<bundle id>-Inbox.
  private static func isInbox(_ url: URL) -> Bool {
    let home = URL(fileURLWithPath: NSHomeDirectory()).resolvingSymlinksInPath().path + "/"
    return url.resolvingSymlinksInPath().path.hasPrefix(home)
      && url.deletingLastPathComponent().lastPathComponent.hasSuffix("Inbox")
  }
}
