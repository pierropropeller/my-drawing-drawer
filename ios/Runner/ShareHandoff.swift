import UIKit

/// 從 Share Extension 交接過來的圖片（沒有 App Group，所以走通用剪貼簿）。
///
/// 擴充（ios/ShareExtension/ShareViewController.swift）把圖片以自訂 pasteboard type 放進剪貼簿；
/// 這裡只處理帶有我們自訂 type 的內容，取出後存成 App 本機暫存檔並清除剪貼簿，
/// 絕不碰使用者其他的剪貼簿內容。詳見 docs/IOS_SHARE_EXTENSION.md。
///
/// 常數要與擴充裡的相同（改動時兩邊一起改）。
enum ShareHandoff {
  static let metaType = "io.molly.drawer.share"
  static let imageType = "io.molly.drawer.share.image"
  static let urlScheme = "drawer"
  static let urlHost = "share"

  /// 超過這個時間的資料視為過期，直接丟掉（擴充另外也設了 5 分鐘的 expirationDate）。
  private static let maxAge: TimeInterval = 10 * 60

  /// 暫存檔放在 `Caches/share_import/`（與 Android 的 `cacheDir/share_import/` 對應）。
  private static var importDirectory: URL? {
    FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
      .appendingPathComponent("share_import", isDirectory: true)
  }

  static func isShareURL(_ url: URL) -> Bool {
    return url.scheme?.lowercased() == urlScheme
  }

  /// 剪貼簿裡有沒有我們的 type。`contains(pasteboardTypes:)` 不會觸發 iOS 14+ 的「貼上自…」提示。
  static var hasPending: Bool {
    return UIPasteboard.general.contains(pasteboardTypes: [metaType])
  }

  /// 讀出剪貼簿裡我們的圖片資料，並清掉剪貼簿。要在主執行緒呼叫（讀剪貼簿）。
  /// 沒有、過期或內容不對時回空陣列（有我們的 type 但不能用時一樣會清掉，避免殘留）。
  static func takeImageData() -> [Data] {
    let board = UIPasteboard.general
    guard board.contains(pasteboardTypes: [metaType]) else { return [] }
    let items = board.items
    // 只要看到我們的 type，這份剪貼簿內容就是擴充放的，取出後整個清掉；其餘情況完全不動。
    defer {
      if board.contains(pasteboardTypes: [metaType]) {
        board.items = []
      }
    }

    var createdAt: TimeInterval?
    var images: [Data] = []
    for item in items {
      if createdAt == nil, let raw = item[metaType], let data = asData(raw),
        let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let t = (obj["createdAt"] as? NSNumber)?.doubleValue
      {
        createdAt = t
      }
      if let raw = item[imageType], let data = asData(raw), !data.isEmpty {
        images.append(data)
      }
    }
    guard let created = createdAt else { return [] }
    let age = Date().timeIntervalSince1970 - created
    // 時鐘被往回調（age < 0）也視為不可信。
    if age < -60 || age > maxAge { return [] }
    return images
  }

  private static func asData(_ value: Any) -> Data? {
    if let d = value as? Data { return d }
    if let d = value as? NSData { return d as Data }
    return nil
  }

  /// 把圖片寫成本機暫存檔，回傳路徑。可在背景執行緒呼叫。
  static func writeFiles(_ images: [Data]) -> [String] {
    guard let dir = importDirectory else { return [] }
    let fm = FileManager.default
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    cleanOldFiles(in: dir)
    let stamp = Int(Date().timeIntervalSince1970 * 1000)
    var paths: [String] = []
    for (i, data) in images.enumerated() {
      let url = dir.appendingPathComponent("share_\(stamp)_\(i).\(fileExtension(for: data))")
      do {
        try data.write(to: url, options: .atomic)
        paths.append(url.path)
      } catch {
        continue
      }
    }
    return paths
  }

  /// 刪掉超過一天的舊暫存檔（Dart 端在使用者確認後才複製進 App 儲存空間，所以保留一段時間）。
  private static func cleanOldFiles(in dir: URL) {
    let fm = FileManager.default
    guard
      let files = try? fm.contentsOfDirectory(
        at: dir, includingPropertiesForKeys: [.contentModificationDateKey])
    else { return }
    let limit = Date().addingTimeInterval(-24 * 60 * 60)
    for file in files {
      let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
        .contentModificationDate
      if let modified = modified, modified < limit {
        try? fm.removeItem(at: file)
      }
    }
  }

  private static func fileExtension(for data: Data) -> String {
    let b = [UInt8](data.prefix(12))
    if b.count >= 4, b[0] == 0x89, b[1] == 0x50, b[2] == 0x4E, b[3] == 0x47 { return "png" }
    if b.count >= 4, b[0] == 0x47, b[1] == 0x49, b[2] == 0x46, b[3] == 0x38 { return "gif" }
    if b.count >= 12, b[0] == 0x52, b[1] == 0x49, b[2] == 0x46, b[3] == 0x46,
      b[8] == 0x57, b[9] == 0x45, b[10] == 0x42, b[11] == 0x50
    {
      return "webp"
    }
    return "jpg"
  }
}
