import ImageIO
import UIKit

/// 畫匣的 Share Extension（純 UIKit，不連 Flutter、不用 App Group）。
///
/// 流程：把分享進來的圖片讀出來（過大的縮小）→ 放進通用剪貼簿（自訂 type、僅本機、5 分鐘後過期）
/// → 嘗試用 `drawer://share` 喚起主程式。主程式回到前景時會從剪貼簿取出圖片並清掉我們的資料。
/// 詳見 docs/IOS_SHARE_EXTENSION.md。
///
/// 常數（pasteboard type、scheme）要與 ios/Runner/ShareHandoff.swift 保持一致。
class ShareViewController: UIViewController {

  // MARK: - 與主程式共用的約定（改動時兩邊一起改）

  private static let metaType = "io.molly.drawer.share"
  private static let imageType = "io.molly.drawer.share.image"
  private static let openURL = "drawer://share"

  // MARK: - 限制

  /// 一次最多帶幾張（Info.plist 的 ActivationRule 也限制為 30）。
  private static let maxImages = 30
  /// 單張原檔不超過這個大小才原樣放進剪貼簿，否則縮小重新編碼成 JPEG。
  private static let maxRawBytes = 6 * 1024 * 1024
  /// 全部圖片加總的上限（擴充的記憶體只有約 120 MB，剪貼簿資料也會再複製一份）。
  private static let totalBudget = 32 * 1024 * 1024
  /// 縮小時的最長邊（像素）。預算快用完時改用較小的值。
  private static let largeSide = 2560
  private static let smallSide = 1280
  /// 剪貼簿資料的存活時間（秒）。
  private static let expiry: TimeInterval = 5 * 60

  // MARK: - 介面文字（擴充沒有 ARB，直接寫在這裡；書面語繁體中文）

  private enum Text {
    static let working = "正在加入畫匣…"
    static let saved = "已儲存，請打開畫匣"
    static let nothing = "沒有可加入的圖片"
    static let done = "完成"
  }

  // MARK: - 介面

  private let card = UIView()
  private let spinner = UIActivityIndicatorView(style: .medium)
  private let label = UILabel()
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

    doneButton.setTitle(Text.done, for: .normal)
    doneButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
    doneButton.addTarget(self, action: #selector(finish), for: .touchUpInside)
    doneButton.isHidden = true

    let stack = UIStackView(arrangedSubviews: [spinner, label, doneButton])
    stack.axis = .vertical
    stack.alignment = .center
    stack.spacing = 14
    stack.translatesAutoresizingMaskIntoConstraints = false
    card.addSubview(stack)

    NSLayoutConstraint.activate([
      card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      card.widthAnchor.constraint(lessThanOrEqualToConstant: 320),
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
    extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
  }

  private func showMessage(_ text: String) {
    spinner.stopAnimating()
    spinner.isHidden = true
    label.text = text
    doneButton.isHidden = false
  }

  // MARK: - 讀出圖片

  /// 一張一張循序處理，同一時間記憶體裡只放一張的解碼資料。
  private final class Collected {
    var images: [Data] = []
    var bytes = 0
  }

  private func collectImages() {
    var providers: [NSItemProvider] = []
    let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
    for item in items {
      for provider in item.attachments ?? [] {
        if provider.hasItemConformingToTypeIdentifier("public.image") {
          providers.append(provider)
        }
      }
    }
    if providers.count > ShareViewController.maxImages {
      providers = Array(providers.prefix(ShareViewController.maxImages))
    }
    if providers.isEmpty {
      showMessage(Text.nothing)
      return
    }
    step(providers: providers, index: 0, collected: Collected())
  }

  private func step(providers: [NSItemProvider], index: Int, collected: Collected) {
    if index >= providers.count {
      DispatchQueue.main.async { self.handoff(collected.images) }
      return
    }
    let provider = providers[index]
    let next: (Data?) -> Void = { [weak self] data in
      guard let self = self else { return }
      if let data = data {
        collected.images.append(data)
        collected.bytes += data.count
      }
      self.step(providers: providers, index: index + 1, collected: collected)
    }

    provider.loadFileRepresentation(forTypeIdentifier: "public.image") { [weak self] url, _ in
      guard let self = self else { return }
      if let url = url {
        // 這個暫存檔只在 handler 內有效，所以要在這裡讀完。
        let data = autoreleasepool { () -> Data? in
          self.encode(fileURL: url, usedBytes: collected.bytes)
        }
        next(data)
        return
      }
      // 後備：有些來源只提供 item（URL／Data／UIImage）。
      provider.loadItem(forTypeIdentifier: "public.image", options: nil) { [weak self] item, _ in
        guard let self = self else { return }
        let data = autoreleasepool { () -> Data? in
          self.encode(item: item, usedBytes: collected.bytes)
        }
        next(data)
      }
    }
  }

  // MARK: - 編碼（原樣或縮小）

  private static func isPassThroughFormat(_ head: Data) -> Bool {
    let b = [UInt8](head.prefix(12))
    // JPEG
    if b.count >= 3, b[0] == 0xFF, b[1] == 0xD8, b[2] == 0xFF { return true }
    // PNG
    if b.count >= 4, b[0] == 0x89, b[1] == 0x50, b[2] == 0x4E, b[3] == 0x47 { return true }
    // GIF
    if b.count >= 4, b[0] == 0x47, b[1] == 0x49, b[2] == 0x46, b[3] == 0x38 { return true }
    // WebP（RIFF....WEBP）
    if b.count >= 12, b[0] == 0x52, b[1] == 0x49, b[2] == 0x46, b[3] == 0x46,
      b[8] == 0x57, b[9] == 0x45, b[10] == 0x42, b[11] == 0x50
    {
      return true
    }
    return false
  }

  private func encode(fileURL: URL, usedBytes: Int) -> Data? {
    let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? Int.max
    var head = Data()
    if let handle = try? FileHandle(forReadingFrom: fileURL) {
      head = (try? handle.read(upToCount: 12)) ?? Data()
      try? handle.close()
    }
    // JPEG／PNG／GIF／WebP 且不大：原樣放進去（保留透明與動畫）。
    if ShareViewController.isPassThroughFormat(head),
      size <= ShareViewController.maxRawBytes,
      usedBytes + size <= ShareViewController.totalBudget,
      let raw = try? Data(contentsOf: fileURL)
    {
      return raw
    }
    // 其他格式（HEIC 等）或太大：縮小成 JPEG。預算吃緊時縮得更小。
    let tight = usedBytes > ShareViewController.totalBudget / 2
    let side = tight ? ShareViewController.smallSide : ShareViewController.largeSide
    guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else { return nil }
    return ShareViewController.downsample(source, maxSide: side, usedBytes: usedBytes)
  }

  private func encode(item: Any?, usedBytes: Int) -> Data? {
    if let url = item as? URL, url.isFileURL {
      return encode(fileURL: url, usedBytes: usedBytes)
    }
    if let data = item as? Data {
      if ShareViewController.isPassThroughFormat(data),
        data.count <= ShareViewController.maxRawBytes,
        usedBytes + data.count <= ShareViewController.totalBudget
      {
        return data
      }
      guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
      return ShareViewController.downsample(
        source, maxSide: ShareViewController.largeSide, usedBytes: usedBytes)
    }
    if let image = item as? UIImage, let jpeg = image.jpegData(compressionQuality: 0.85),
      usedBytes + jpeg.count <= ShareViewController.totalBudget
    {
      return jpeg
    }
    return nil
  }

  private static func downsample(_ source: CGImageSource, maxSide: Int, usedBytes: Int) -> Data? {
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: maxSide,
    ]
    guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
      return nil
    }
    guard let jpeg = UIImage(cgImage: cg).jpegData(compressionQuality: 0.85) else { return nil }
    if usedBytes + jpeg.count > totalBudget { return nil }
    return jpeg
  }

  // MARK: - 放進剪貼簿、喚起主程式

  private func handoff(_ images: [Data]) {
    if images.isEmpty {
      showMessage(Text.nothing)
      return
    }
    let meta: [String: Any] = [
      "v": 1,
      "count": images.count,
      "createdAt": Date().timeIntervalSince1970,
    ]
    guard let metaData = try? JSONSerialization.data(withJSONObject: meta) else {
      showMessage(Text.nothing)
      return
    }
    var items: [[String: Any]] = [[ShareViewController.metaType: metaData]]
    for data in images {
      items.append([ShareViewController.imageType: data])
    }
    // 只存本機（不經 Handoff／通用剪貼簿同步到其他裝置）、5 分鐘後自動消失。
    UIPasteboard.general.setItems(
      items,
      options: [
        .localOnly: true,
        .expirationDate: Date().addingTimeInterval(ShareViewController.expiry),
      ])

    openHostApp()
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
