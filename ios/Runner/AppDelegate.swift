import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // 保留 channel，避免被釋放。
  private var mediaChannel: FlutterMethodChannel?
  private var appIconChannel: FlutterMethodChannel?
  private var windowChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerDrawerChannels(engineBridge.pluginRegistry)
  }

  // MARK: - 與 Android MainActivity.kt 對應的兩個 channel

  private func registerDrawerChannels(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "DrawerChannels") else { return }
    let messenger = registrar.messenger()

    // 影片探測（lib/media/video_probe.dart）。
    let media = FlutterMethodChannel(name: "io.molly.drawer/media", binaryMessenger: messenger)
    media.setMethodCallHandler { call, result in
      switch call.method {
      case "probeVideo":
        let args = call.arguments as? [String: Any]
        guard let path = args?["path"] as? String else {
          result(nil)
          return
        }
        let maxSide = (args?["maxSide"] as? NSNumber)?.intValue ?? 720
        // 解碼第一格可能要幾百毫秒，不卡主執行緒。
        DispatchQueue.global(qos: .userInitiated).async {
          let out = AppDelegate.probeVideo(path: path, maxSide: maxSide)
          DispatchQueue.main.async { result(out) }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    mediaChannel = media

    // App 圖示（lib/state/app_icon.dart）。
    let appIcon = FlutterMethodChannel(name: "io.molly.drawer/appicon", binaryMessenger: messenger)
    appIcon.setMethodCallHandler { call, result in
      switch call.method {
      case "currentIcon":
        result(AppDelegate.currentIconAlias())
      case "setIcon":
        let args = call.arguments as? [String: Any]
        guard let alias = args?["alias"] as? String else {
          result(FlutterError(code: "bad_args", message: "alias is required", details: nil))
          return
        }
        AppDelegate.setIconAlias(alias, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    appIconChannel = appIcon

    // 視窗資訊（lib/ui/common/window_top_inset.dart）：iPad 視窗模式下頁面頂部要讓開視窗控制點。
    // 取不到的欄位不放進去（Dart 端用保底值）；整個失敗回 nil。
    let windowCh = FlutterMethodChannel(name: "io.molly.drawer/window", binaryMessenger: messenger)
    windowCh.setMethodCallHandler { call, result in
      switch call.method {
      case "windowInsets":
        DispatchQueue.main.async { result(AppDelegate.windowInsets()) }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    windowChannel = windowCh
  }

  // MARK: - 視窗資訊

  /// isPad、top（max(window safe inset top, 狀態列高度)）、leading、windowed（視窗小於整個螢幕）。
  /// 只用長期穩定的 API（未使用 iOS 26 的 layoutGuide(for:)，避免舊 SDK 編譯失敗）。
  private static func windowInsets() -> [String: Any]? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
    else { return nil }
    var out: [String: Any] = [:]
    out["isPad"] = UIDevice.current.userInterfaceIdiom == .pad
    let statusBar = Double(scene.statusBarManager?.statusBarFrame.height ?? 0)
    if let win = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
      out["top"] = max(Double(win.safeAreaInsets.top), statusBar)
      out["leading"] = Double(win.safeAreaInsets.left)
      let screen = scene.screen.bounds.size
      out["windowed"] = win.bounds.width < screen.width - 1 || win.bounds.height < screen.height - 1
    } else {
      out["top"] = statusBar
    }
    return out
  }

  // MARK: - App 圖示

  /// Dart 端的 alias（見 appIconOptions）對應 iOS 的 alternate icon 名稱。
  /// nil＝主圖示（Assets.xcassets/AppIcon）；其他是 Assets.xcassets 裡同名的 .appiconset，
  /// 並列在 project.pbxproj 的 ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES。
  private static let iconAliases: [(alias: String, iosName: String?)] = [
    ("IconSanbi", nil),
    ("IconHuati", "IconHuati"),
  ]

  private static func currentIconAlias() -> String? {
    let name = UIApplication.shared.alternateIconName
    return iconAliases.first(where: { $0.iosName == name })?.alias
  }

  private static func setIconAlias(_ alias: String, result: @escaping FlutterResult) {
    guard let target = iconAliases.first(where: { $0.alias == alias }) else {
      result(FlutterError(code: "no_such_alias", message: alias, details: nil))
      return
    }
    DispatchQueue.main.async {
      let app = UIApplication.shared
      guard app.supportsAlternateIcons else {
        result(FlutterError(code: "set_failed", message: "alternate icons not supported", details: nil))
        return
      }
      // 已經是這個圖示就不要再呼叫（iOS 每次更換都會彈系統提示）。
      if app.alternateIconName == target.iosName {
        result(nil)
        return
      }
      app.setAlternateIconName(target.iosName) { error in
        DispatchQueue.main.async {
          if let error = error {
            result(FlutterError(code: "set_failed", message: error.localizedDescription, details: nil))
          } else {
            result(nil)
          }
        }
      }
    }
  }

  // MARK: - 影片探測

  /// 讀影片的寬高（套用旋轉）、長度（毫秒）與第一格 JPEG 截圖；失敗回 nil。
  /// 回傳格式與 Android 相同：width、height、durationMs（可為 null）、poster（可為 null）。
  private static func probeVideo(path: String, maxSide: Int) -> [String: Any]? {
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: path) else { return nil }
    let asset = AVURLAsset(url: url)

    var width = 0
    var height = 0
    if let track = asset.tracks(withMediaType: .video).first {
      // naturalSize 是未旋轉的尺寸，要乘上 preferredTransform 才是顯示尺寸（直拍影片寬高會對調）。
      let size = track.naturalSize.applying(track.preferredTransform)
      width = Int(abs(size.width).rounded())
      height = Int(abs(size.height).rounded())
    }

    var durationMs: Any = NSNull()
    let seconds = CMTimeGetSeconds(asset.duration)
    if seconds.isFinite && seconds >= 0 {
      durationMs = Int((seconds * 1000).rounded())
    }

    // 海報規則（Molly）：影片 ≥1 秒取第 1 秒的畫面，不足 1 秒取第一格。
    var poster: Any = NSNull()
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: maxSide, height: maxSide)
    let wantsOneSecond = !(seconds.isFinite) || seconds >= 1.0
    var times: [CMTime] = []
    if wantsOneSecond { times.append(CMTime(seconds: 1.0, preferredTimescale: 600)) }
    times.append(.zero)
    var cgImage: CGImage?
    // 先要精確的畫面，不行再接受附近的關鍵格。
    for exact in [true, false] {
      generator.requestedTimeToleranceBefore = exact ? .zero : .positiveInfinity
      generator.requestedTimeToleranceAfter = exact ? .zero : .positiveInfinity
      for t in times {
        if let cg = try? generator.copyCGImage(at: t, actualTime: nil) {
          cgImage = cg
          break
        }
      }
      if cgImage != nil { break }
    }
    if let cg = cgImage {
      if width == 0 || height == 0 {
        width = cg.width
        height = cg.height
      }
      // 取不到畫面就只回傳寬高與長度，之後再補截圖。
      if let data = UIImage(cgImage: cg).jpegData(compressionQuality: 0.85) {
        poster = FlutterStandardTypedData(bytes: data)
      }
    }

    // 連寬高都讀不到、也沒有截圖＝不是可用的影片。
    if width == 0 && height == 0 && poster is NSNull { return nil }

    return [
      "width": width,
      "height": height,
      "durationMs": durationMs,
      "poster": poster,
    ]
  }
}
