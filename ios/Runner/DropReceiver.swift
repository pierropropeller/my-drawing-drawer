import Flutter
import UIKit
import UniformTypeIdentifiers

/// 分屏拖放接收（P-013）：從「照片」「檔案」等 App 把圖片／影片拖進畫匣。
///
/// 契約見 lib/ui/media_source/drop_target_service.dart（MethodChannel `huakeng/media_drop`）：
/// - Dart → 原生：`start`（掛上落點，回傳 true）、`load {id}`（回傳本機檔案路徑，失敗回 nil）、`cancel {id}`。
/// - 原生 → Dart：`enter {count, x, y}`、`move {x, y}`、`leave`、`drop {x, y, items: [{id, name}]}`。
///   座標是 Flutter 視圖內的邏輯座標（UIKit point）。
///
/// 品質：**照原樣**複製（HEIC 不轉檔、影片不重新編碼）。UIKit 規定要在 `performDrop` 內就開始載入
/// （事後再向 item provider 要資料不保證可用），所以放開的當下就替每個項目開始
/// `loadFileRepresentation` 並複製到 `Caches/drop_import/`；Dart 之後呼叫 `load {id}` 只是等那份結果
/// （iCloud 照片會先下載，可能很久）。Dart 取走路徑後由既有匯入流程複製進 App 儲存空間，
/// 這裡的暫存檔在下次放開／啟動時依時間清掉。
final class DropReceiver: NSObject, UIDropInteractionDelegate {
  static let channelName = "huakeng/media_drop"

  /// 接受的型別。
  private static let acceptedTypes = ["public.image", "public.movie"]
  /// 同一個項目提供多種圖片格式時的優先順序（與分享擴充相同）。
  private static let preferredOrder = [
    "com.compuserve.gif", "org.webmproject.webp", "public.heic", "public.png", "public.jpeg",
    "public.heif",
  ]
  private static let knownExtensions: [String: String] = [
    "com.compuserve.gif": "gif",
    "org.webmproject.webp": "webp",
    "public.heic": "heic",
    "public.png": "png",
    "public.jpeg": "jpg",
    "public.heif": "heif",
  ]
  /// 暫存檔保留多久（秒）。Dart 在放開後馬上就會 `load` 並複製，一般用不到這麼久。
  private static let keepSeconds: TimeInterval = 2 * 60 * 60

  /// 一個放開的項目的載入狀態（只在主執行緒存取）。
  private final class Entry {
    var progress: Progress?
    var done = false
    var path: String?
    var waiters: [FlutterResult] = []
  }

  private let channel: FlutterMethodChannel
  private var interaction: UIDropInteraction?
  private weak var hostView: UIView?
  private var entries: [String: Entry] = [:]
  private var sequence = 0
  /// 已送出 `enter` 但還沒送 `leave`／`drop`。
  private var inside = false

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: DropReceiver.channelName, binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "start":
        self.start(result, attempt: 0)
      case "load":
        self.load(id: args?["id"] as? String, result: result)
      case "cancel":
        self.cancel(id: args?["id"] as? String)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - start（掛上落點）

  /// 找到 Flutter 的根 view 就掛上 `UIDropInteraction`。Dart 可能比視窗建好還早呼叫，所以找不到時最多重試約 5 秒。
  private func start(_ result: @escaping FlutterResult, attempt: Int) {
    if let view = DropReceiver.flutterView() {
      attach(to: view)
      DropReceiver.cleanOldFiles()
      result(true)
      return
    }
    if attempt >= 20 {
      result(false)
      return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
      self?.start(result, attempt: attempt + 1)
    }
  }

  private static func flutterView() -> UIView? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    for scene in scenes {
      for window in scene.windows {
        if let controller = window.rootViewController as? FlutterViewController {
          return controller.view
        }
      }
    }
    return nil
  }

  private func attach(to view: UIView) {
    if hostView === view, interaction != nil { return }
    if let old = interaction, let oldView = hostView {
      oldView.removeInteraction(old)
    }
    let created = UIDropInteraction(delegate: self)
    view.addInteraction(created)
    interaction = created
    hostView = view
  }

  // MARK: - UIDropInteractionDelegate

  func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
    return session.hasItemsConforming(toTypeIdentifiers: DropReceiver.acceptedTypes)
  }

  func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnter session: UIDropSession) {
    inside = true
    let p = location(of: session, in: interaction)
    let args: [String: Any] = ["count": session.items.count, "x": p.x, "y": p.y]
    channel.invokeMethod("enter", arguments: args)
  }

  func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession)
    -> UIDropProposal
  {
    let p = location(of: session, in: interaction)
    let args: [String: Any] = ["x": p.x, "y": p.y]
    channel.invokeMethod("move", arguments: args)
    return UIDropProposal(operation: .copy)
  }

  func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) {
    sendLeave()
  }

  func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnd session: UIDropSession) {
    sendLeave()
  }

  func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
    inside = false
    let p = location(of: session, in: interaction)
    DropReceiver.cleanOldFiles()
    discardUnclaimed()

    var list: [[String: Any]] = []
    for item in session.items {
      let provider = item.itemProvider
      let isImage = provider.hasItemConformingToTypeIdentifier("public.image")
      let isMovie = provider.hasItemConformingToTypeIdentifier("public.movie")
      if !isImage && !isMovie { continue }
      sequence += 1
      let id = "drop_\(Int(Date().timeIntervalSince1970 * 1000))_\(sequence)"
      let entry = Entry()
      entries[id] = entry
      startLoading(id: id, entry: entry, provider: provider)
      var info: [String: Any] = ["id": id]
      if let name = provider.suggestedName, !name.isEmpty {
        info["name"] = name
      }
      list.append(info)
    }
    let args: [String: Any] = ["x": p.x, "y": p.y, "items": list]
    channel.invokeMethod("drop", arguments: args)
  }

  private func sendLeave() {
    if !inside { return }
    inside = false
    channel.invokeMethod("leave", arguments: nil)
  }

  private func location(of session: UIDropSession, in interaction: UIDropInteraction)
    -> (x: Double, y: Double)
  {
    guard let view = interaction.view else { return (0, 0) }
    let point = session.location(in: view)
    return (Double(point.x), Double(point.y))
  }

  // MARK: - 載入（照原樣複製到 Caches/drop_import/）

  private static func pickType(for provider: NSItemProvider) -> (uti: String, ext: String)? {
    let registered = provider.registeredTypeIdentifiers
    for uti in preferredOrder where registered.contains(uti) {
      return (uti, knownExtensions[uti] ?? "")
    }
    for uti in registered {
      if uti == "public.image" || uti == "public.movie" || uti.hasPrefix("dyn.") { continue }
      if let type = UTType(uti), type.conforms(to: .image) || type.conforms(to: .movie) {
        return (uti, type.preferredFilenameExtension ?? "")
      }
    }
    // 最後手段：泛型型別（來源可能替我們轉檔，但至少不丟項目）。
    if provider.hasItemConformingToTypeIdentifier("public.image") { return ("public.image", "") }
    if provider.hasItemConformingToTypeIdentifier("public.movie") { return ("public.movie", "") }
    return nil
  }

  private func startLoading(id: String, entry: Entry, provider: NSItemProvider) {
    guard let pick = DropReceiver.pickType(for: provider) else {
      finish(id: id, path: nil)
      return
    }
    entry.progress = provider.loadFileRepresentation(forTypeIdentifier: pick.uti) {
      [weak self] url, _ in
      // 這個暫存檔只在 handler 內有效，所以在這裡複製完（APFS 上通常是 clone，不會真的搬資料）。
      var out: String?
      if let url = url, let dir = DropReceiver.importDirectory() {
        var ext = url.pathExtension.lowercased()
        if ext.isEmpty || ext.count > 5 { ext = pick.ext }
        if ext.isEmpty { ext = "bin" }
        let dest = dir.appendingPathComponent("\(id).\(ext)")
        do {
          if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
          }
          try FileManager.default.copyItem(at: url, to: dest)
          out = dest.path
        } catch {
          out = nil
        }
      }
      DispatchQueue.main.async { self?.finish(id: id, path: out) }
    }
  }

  private func finish(id: String, path: String?) {
    guard let entry = entries[id] else {
      // 已被 cancel：複製出來的檔案不要留著。
      if let path = path { try? FileManager.default.removeItem(atPath: path) }
      return
    }
    entry.done = true
    entry.path = path
    entry.progress = nil
    if !entry.waiters.isEmpty {
      let waiters = entry.waiters
      entry.waiters = []
      entries[id] = nil
      for waiter in waiters { waiter(path) }
    }
  }

  private func load(id: String?, result: @escaping FlutterResult) {
    guard let id = id, let entry = entries[id] else {
      result(nil)
      return
    }
    if entry.done {
      entries[id] = nil
      result(entry.path)
    } else {
      entry.waiters.append(result)
    }
  }

  private func cancel(id: String?) {
    guard let id = id, let entry = entries[id] else { return }
    entries[id] = nil
    entry.progress?.cancel()
    let waiters = entry.waiters
    entry.waiters = []
    for waiter in waiters { waiter(nil) }
    if let path = entry.path { try? FileManager.default.removeItem(atPath: path) }
  }

  /// 上一次放開後沒有人來 `load` 的項目（例如落在沒有 DropZone 的頁面）：丟掉並刪檔。
  private func discardUnclaimed() {
    for (id, entry) in entries where entry.done {
      entries[id] = nil
      if let path = entry.path { try? FileManager.default.removeItem(atPath: path) }
    }
  }

  // MARK: - 暫存資料夾

  /// `Caches/drop_import/`（檔名與路徑一律英文）。
  private static func importDirectory() -> URL? {
    guard
      let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    else { return nil }
    let dir = base.appendingPathComponent("drop_import", isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    } catch {
      return nil
    }
    return dir
  }

  /// 刪掉超過 [keepSeconds] 的暫存檔。
  private static func cleanOldFiles() {
    guard let dir = importDirectory(),
      let files = try? FileManager.default.contentsOfDirectory(
        at: dir, includingPropertiesForKeys: [.contentModificationDateKey])
    else { return }
    let limit = Date().addingTimeInterval(-keepSeconds)
    for file in files {
      let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
        .contentModificationDate
      if let modified = modified, modified < limit {
        try? FileManager.default.removeItem(at: file)
      }
    }
  }
}
