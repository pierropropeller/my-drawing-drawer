import UIKit
import UniformTypeIdentifiers

/// 畫匣的 Share Extension（純 UIKit，不連 Flutter、不用 App Group）。
///
/// 流程：把分享進來的圖片「原樣」讀出來 → 放進通用剪貼簿（自訂 type、僅本機、5 分鐘後過期）
/// → 嘗試用 `drawer://share` 喚起主程式。主程式回到前景時會從剪貼簿取出圖片並清掉我們的資料。
/// 詳見 docs/IOS_SHARE_EXTENSION.md、docs/IOS_IMPORT_PATHS.md。
///
/// 品質原則（Molly）：**不轉檔、不縮圖、不重新編碼**。HEIC／JPEG／PNG／GIF／WebP 都是原始位元組。
/// 放不下（擴充記憶體有限）的圖片不會被偷偷降畫質或丟掉：會停止收更多、並在畫面上明講「已加入 N 張，其餘 M 張未加入」。
///
/// 常數（pasteboard type、scheme）要與 ios/Runner/ShareHandoff.swift 保持一致。
class ShareViewController: UIViewController {

  // MARK: - 與主程式共用的約定（改動時兩邊一起改）

  private static let metaType = "io.molly.drawer.share"
  private static let imageType = "io.molly.drawer.share.image"
  private static let openURL = "drawer://share"

  // MARK: - 限制

  /// 全部圖片加總的上限。擴充的記憶體上限約 120 MB；放進剪貼簿時系統會序列化一份資料，
  /// 所以抓保守值（檔案以 mapped 方式讀入，多半不算髒頁，但序列化那份會）。
  /// 超過就停止收更多並明講（不降畫質）。真機驗證穩定後可以調高。
  private static let totalBudget = 64 * 1024 * 1024
  /// 剪貼簿資料的存活時間（秒）。
  private static let expiry: TimeInterval = 5 * 60

  // MARK: - 圖片型別（依序挑原始型別，避免挑到 `public.image` 這種泛型而觸發轉檔）

  /// 認得的原始格式與副檔名。
  private static let knownTypes: [String: String] = [
    "com.compuserve.gif": "gif",
    "org.webmproject.webp": "webp",
    "public.heic": "heic",
    "public.png": "png",
    "public.jpeg": "jpg",
    "public.heif": "heif",
  ]
  /// 同一個項目同時提供多種格式時的優先順序：
  /// GIF／WebP 最前（可能有動畫，常伴隨一張靜態 PNG／JPEG）；其次 HEIC（原始照片，JPEG 是轉出來的）、PNG、JPEG。
  private static let preferredOrder = [
    "com.compuserve.gif", "org.webmproject.webp", "public.heic", "public.png", "public.jpeg",
    "public.heif",
  ]

  // MARK: - 介面文字（擴充沒有 ARB，直接寫在這裡；書面語繁體中文）

  private enum Text {
    static let working = "正在加入畫匣…"
    static let saved = "已儲存，請打開畫匣"
    static let nothing = "沒有可加入的圖片"
    static let done = "完成"
    static let open = "打開畫匣"

    /// 結果說明。有圖片沒加進去時一定要講清楚（不靜默丟圖）。
    static func summary(added: Int, over: Int, failed: Int) -> String {
      var s = ""
      if added > 0 {
        s = "已加入 \(added) 張"
        if over > 0 {
          s += "，其餘 \(over) 張因 iOS 擴充容量限制未加入，請改用拖放或 App 內選圖。"
          if failed > 0 { s += "另有 \(failed) 張無法讀取。" }
        } else if failed > 0 {
          s += "，另有 \(failed) 張無法讀取，未加入。"
        } else {
          s += "。"
        }
        return s
      }
      if over > 0 {
        s = "\(over) 張圖片因 iOS 擴充容量限制未能加入，請改用拖放或 App 內選圖。"
      }
      if failed > 0 {
        s += "\(failed) 張圖片無法讀取，未加入。"
      }
      return s.isEmpty ? nothing : s
    }
  }

  // MARK: - 介面

  private let card = UIView()
  private let spinner = UIActivityIndicatorView(style: .medium)
  private let label = UILabel()
  private let openButton = UIButton(type: .system)
  private let doneButton = UIButton(type: .system)
  private var started = false

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = UIColor.black.withAlphaComponent(0.35)

    card.backgroundColor = UIColor.systemBackground
    card.layer.cornerRadius = 16
    card.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(card)

    spinner.startAnimating()

    label.text = Text.working
    label.font = UIFont.preferredFont(forTextStyle: .body)
    label.textColor = UIColor.label
    label.textAlignment = .center
    label.numberOfLines = 0

    openButton.setTitle(Text.open, for: .normal)
    openButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
    openButton.addTarget(self, action: #selector(openTapped), for: .touchUpInside)
    openButton.isHidden = true

    doneButton.setTitle(Text.done, for: .normal)
    doneButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
    doneButton.addTarget(self, action: #selector(finish), for: .touchUpInside)
    doneButton.isHidden = true

    let stack = UIStackView(arrangedSubviews: [spinner, label, openButton, doneButton])
    stack.axis = .vertical
    stack.alignment = .center
    stack.spacing = 14
    stack.translatesAutoresizingMaskIntoConstraints = false
    card.addSubview(stack)

    NSLayoutConstraint.activate([
      card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      card.widthAnchor.constraint(lessThanOrEqualToConstant: 340),
      card.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
      card.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),
      stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
      stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
      stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
      stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
    ])
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if started { return }
    started = true
    collectImages()
  }

  @objc private func finish() {
    removeStagingDirectory()
    extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
  }

  @objc private func openTapped() {
    openHostApp()
  }

  /// 只顯示訊息＋「完成」。
  private func showMessage(_ text: String) {
    spinner.stopAnimating()
    spinner.isHidden = true
    label.text = text
    openButton.isHidden = true
    doneButton.isHidden = false
  }

  /// 顯示結果說明＋「打開畫匣」＋「完成」（有圖片沒加進去時不自動跳走，讓使用者看得到說明）。
  private func showResult(_ text: String) {
    showMessage(text)
    openButton.isHidden = false
  }

  // MARK: - 讀出圖片（原樣，不轉檔、不縮圖）

  /// 暫存到擴充自己 tmp 資料夾的一張圖（原始位元組的複製，APFS 上是 clone，不佔記憶體）。
  private struct Staged {
    let url: URL
    let uti: String
    let ext: String
  }

  /// 逐張循序處理的狀態。只在「一張處理完才開始下一張」的鏈上存取，不會同時被兩條執行緒碰。
  private final class Collector {
    var staged: [Staged] = []
    var bytes = 0
    var failed = 0
    var stoppedForLimit = false
  }

  private var providers: [NSItemProvider] = []
  private let collector = Collector()
  private var stagingDirectory: URL?

  private func collectImages() {
    var found: [NSItemProvider] = []
    let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
    for item in items {
      for provider in item.attachments ?? [] {
        if provider.hasItemConformingToTypeIdentifier("public.image") {
          found.append(provider)
        }
      }
    }
    if found.isEmpty {
      showMessage(Text.nothing)
      return
    }
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("share_\(UUID().uuidString)", isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    } catch {
      showMessage(Text.nothing)
      return
    }
    stagingDirectory = dir
    providers = found
    step(0)
  }

  private func removeStagingDirectory() {
    if let dir = stagingDirectory {
      try? FileManager.default.removeItem(at: dir)
      stagingDirectory = nil
    }
  }

  /// 挑這個項目要取哪一種型別。回傳 (型別, 副檔名)；副檔名空字串＝之後從檔案本身決定。
  private static func pickType(for provider: NSItemProvider) -> (uti: String, ext: String)? {
    let registered = provider.registeredTypeIdentifiers
    // 1) 認得的原始格式，依優先順序。
    for uti in preferredOrder where registered.contains(uti) {
      return (uti, knownTypes[uti] ?? "")
    }
    // 2) 其他具體的圖片型別（TIFF、BMP、RAW…）：照原樣取，不轉檔。
    for uti in registered {
      if uti == "public.image" || uti.hasPrefix("dyn.") { continue }
      if let type = UTType(uti), type.conforms(to: .image) {
        return (uti, type.preferredFilenameExtension ?? "")
      }
    }
    // 3) 最後手段：泛型 public.image（來源可能替我們轉檔，但至少不丟圖）。
    if provider.hasItemConformingToTypeIdentifier("public.image") {
      return ("public.image", "")
    }
    return nil
  }

  /// 一張一張循序處理：取得檔案 URL → 檢查大小 → 複製到自己的 tmp。記憶體裡不放圖片資料。
  private func step(_ index: Int) {
    if index >= providers.count || collector.stoppedForLimit {
      DispatchQueue.main.async { self.finishCollecting() }
      return
    }
    let provider = providers[index]
    guard let pick = ShareViewController.pickType(for: provider) else {
      collector.failed += 1
      DispatchQueue.global(qos: .userInitiated).async { self.step(index + 1) }
      return
    }
    provider.loadFileRepresentation(forTypeIdentifier: pick.uti) { [weak self] url, _ in
      guard let self = self else { return }
      // 這個暫存檔只在 handler 內有效，所以要在這裡複製完。
      autoreleasepool { self.stage(url, pick: pick, index: index) }
      // 下一張改丟到別的 queue 開始，避免 handler 層層巢狀。
      DispatchQueue.global(qos: .userInitiated).async { self.step(index + 1) }
    }
  }

  private func stage(_ url: URL?, pick: (uti: String, ext: String), index: Int) {
    guard let url = url, let dir = stagingDirectory,
      let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize, size > 0
    else {
      collector.failed += 1
      return
    }
    if collector.bytes + size > ShareViewController.totalBudget {
      // 超過安全上限：這張和後面的都不收（不降畫質、不縮圖），最後明講。
      collector.stoppedForLimit = true
      return
    }
    var ext = pick.ext
    if ext.isEmpty { ext = url.pathExtension.lowercased() }
    if ext.isEmpty { ext = "img" }
    let dest = dir.appendingPathComponent("\(index).\(ext)")
    do {
      try FileManager.default.copyItem(at: url, to: dest)
    } catch {
      collector.failed += 1
      return
    }
    collector.staged.append(Staged(url: dest, uti: pick.uti, ext: ext))
    collector.bytes += size
  }

  /// 全部處理完（主執行緒）。
  private func finishCollecting() {
    let added = collector.staged.count
    let failed = collector.failed
    let over = collector.stoppedForLimit ? max(0, providers.count - added - failed) : 0
    if added == 0 {
      removeStagingDirectory()
      showMessage(Text.summary(added: 0, over: over, failed: failed))
      return
    }
    handoff(over: over, failed: failed)
  }

  // MARK: - 放進剪貼簿、喚起主程式

  private func handoff(over: Int, failed: Int) {
    // 到這裡才把檔案以 mapped 方式讀進來（盡量不佔髒頁記憶體），原始位元組一個都不改。
    var imageItems: [[String: Any]] = []
    var metaItems: [[String: String]] = []
    var unreadable = 0
    for staged in collector.staged {
      guard let data = try? Data(contentsOf: staged.url, options: .mappedIfSafe), !data.isEmpty
      else {
        unreadable += 1
        continue
      }
      imageItems.append([ShareViewController.imageType: data])
      metaItems.append(["uti": staged.uti, "ext": staged.ext])
    }
    if imageItems.isEmpty {
      removeStagingDirectory()
      showMessage(Text.summary(added: 0, over: over, failed: failed + unreadable))
      return
    }
    // v2：items[i] 對應第 i 張圖片的原始型別與副檔名（主程式依副檔名寫成原檔）。
    let meta: [String: Any] = [
      "v": 2,
      "count": imageItems.count,
      "createdAt": Date().timeIntervalSince1970,
      "items": metaItems,
    ]
    guard let metaData = try? JSONSerialization.data(withJSONObject: meta) else {
      removeStagingDirectory()
      showMessage(Text.nothing)
      return
    }
    var items: [[String: Any]] = [[ShareViewController.metaType: metaData]]
    items.append(contentsOf: imageItems)
    // 只存本機（不經 Handoff／通用剪貼簿同步到其他裝置）、5 分鐘後自動消失。
    UIPasteboard.general.setItems(
      items,
      options: [
        .localOnly: true,
        .expirationDate: Date().addingTimeInterval(ShareViewController.expiry),
      ])
    removeStagingDirectory()

    let totalFailed = failed + unreadable
    if over == 0 && totalFailed == 0 {
      openHostApp()
    } else {
      // 有圖片沒加進去：先讓使用者看到說明，不自動跳走。
      showResult(Text.summary(added: imageItems.count, over: over, failed: totalFailed))
    }
  }

  /// 嘗試喚起主程式。沒有可靠的成功訊號，所以不論結果如何，約 1 秒後都顯示「已儲存，請打開畫匣」＋「完成」。
  /// 若喚起成功，使用者已經在畫匣裡，這個畫面不會被看到。
  private func openHostApp() {
    guard let url = URL(string: ShareViewController.openURL) else {
      showMessage(Text.saved)
      return
    }
    // 1) 官方的 NSExtensionContext.open（Share Extension 通常回 false，但無害）。
    extensionContext?.open(url) { [weak self] success in
      if success {
        DispatchQueue.main.async { self?.finish() }
      }
    }
    // 2) responder chain 找到 UIApplication，呼叫 open(_:options:completionHandler:) 的 selector 版本。
    //    （舊的 openURL: 在 iOS 18 起無效，不依賴它。）
    _ = openViaResponderChain(url)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
      self?.showMessage(Text.saved)
    }
  }

  private typealias OpenFunction =
    @convention(c) (AnyObject, Selector, NSURL, NSDictionary, AnyObject?) -> Void

  private func openViaResponderChain(_ url: URL) -> Bool {
    let selector = NSSelectorFromString("openURL:options:completionHandler:")
    var responder: UIResponder? = self
    while let current = responder {
      if current.responds(to: selector) {
        let imp: IMP = current.method(for: selector)
        let function = unsafeBitCast(imp, to: OpenFunction.self)
        function(current, selector, url as NSURL, NSDictionary(), nil)
        return true
      }
      responder = current.next
    }
    return false
  }
}
