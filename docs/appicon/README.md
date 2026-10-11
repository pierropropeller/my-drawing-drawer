# 畫匣 App Icon（暫用版）

預設主題＝玫瑰 `#B76A7C`。圖形與「關於 App」頁的 icon 相同（白色線條匣子）。

## 給程程
- `android/app/src/main/res/`：可以直接覆蓋到 Flutter 專案的 `android/app/src/main/res/`（預設玫瑰色）。
  - `mipmap-*/ic_launcher.png`、`ic_launcher_round.png`：舊版 Android 用（48／72／96／144／192 px）
  - `mipmap-*/ic_launcher_foreground.png`：Adaptive icon 前景（108dp：108／162／216／324／432 px，透明底白色圖形，已留安全區）
  - `mipmap-anydpi-v26/`：Adaptive icon 設定，含 Android 13 主題圖示（monochrome）
  - `values/ic_launcher_background.xml`：背景色 `#B76A7C`
- `playstore/icon-512.png`：Google Play 上架用 512×512。
- `source/`：1024 原圖。四個主題色各一張（rose 玫瑰、slate 霧藍、coral 珊瑚、matcha 抹茶）＋ adaptive 前景。如果改用 `flutter_launcher_icons` 產生，用這裡的檔案。

## 四色主題 icon
App 內「關於 App」的 icon 跟主題色變色。桌面 icon 跟主題色切換屬於〔待評估〕（需要 activity-alias，切換時桌面捷徑可能消失），先只用玫瑰色。
