import Flutter
import UIKit

/// 「貼上」按鈕用的剪貼簿圖片讀取（iOS）。
///
/// 為什麼不用 `pasteboard` 套件的 `Pasteboard.image`：它在 iOS 是 `UIPasteboard.general.image?.pngData()`，
/// 會把圖解碼後重新編成 PNG——像素不失真，但原格式（HEIC／JPEG／GIF／WebP）、EXIF、色彩描述檔都沒了，檔案也變大。
/// 這裡直接讀剪貼簿裡的**原始資料**（`data(forPasteboardType:)`），原樣寫成檔案。
///
/// 只在使用者按下「貼上」才會呼叫（讀資料時 iOS 14+ 才會跳「允許貼上」）；
/// 判斷有沒有圖用的 `types`／`hasImages` 不會觸發提示。
/// Dart 端：lib/ui/media_source/media_source_services.dart 的 `PasteboardClipboardSource`。
final class ClipboardImageChannel {
  static let channelName = "io.molly.drawer/clipboard"

  /// 認得的原始格式（型別, 副檔名），同時有多種時依這個順序挑：
  /// GIF／WebP 最前（可能有動畫，常伴隨一張靜態 PNG）；其次 HEIC、PNG、JPEG。
  private static let formats: [(uti: String, ext: String)] = [
    ("com.compuserve.gif", "gif"),
    ("org.webmproject.webp", "webp"),
    ("public.heic", "heic"),
    ("public.png", "png"),
    ("public.jpeg", "jpg"),
  ]

  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: ClipboardImageChannel.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "readImage":
        let args = call.arguments as? [String: Any]
        guard let dir = args?["dir"] as? String, !dir.isEmpty else {
          result(FlutterError(code: "bad_args", message: "dir is required", details: nil))
          return
        }
        // 平台通道的 handler 在主執行緒；讀剪貼簿與寫檔都很快（原始資料，不轉檔）。
        result(ClipboardImageChannel.readImage(into: dir))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// 讀剪貼簿裡的圖片原始資料，寫成 `dir/paste_<時間>.<副檔名>`。
  /// 回傳 `{path, ext}`；剪貼簿沒有圖片或寫檔失敗回 nil。
  static func readImage(into dir: String) -> [String: Any]? {
    let board = UIPasteboard.general
    let available = Set(board.types)
    for format in formats where available.contains(format.uti) {
      guard let data = board.data(forPasteboardType: format.uti), !data.isEmpty else { continue }
      if let out = write(data, ext: format.ext, dir: dir) { return out }
    }
    // 後備：剪貼簿只有系統轉換過的圖片（例如 TIFF、UIImage 物件）。解碼後編成 PNG（無損但不是原格式）。
    if board.hasImages, let png = board.image?.pngData(), !png.isEmpty {
      return write(png, ext: "png", dir: dir)
    }
    return nil
  }

  private static func write(_ data: Data, ext: String, dir: String) -> [String: Any]? {
    let folder = URL(fileURLWithPath: dir, isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let stamp = Int(Date().timeIntervalSince1970 * 1_000_000)
      let url = folder.appendingPathComponent("paste_\(stamp).\(ext)")
      try data.write(to: url, options: .atomic)
      return ["path": url.path, "ext": ext]
    } catch {
      return nil
    }
  }
}
