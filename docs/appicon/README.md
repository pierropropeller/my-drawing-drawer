# 畫匣 App Icon（D-086）

兩款 icon，Molly 親手畫，**不跟主題色**。使用者可在「我的 → App 圖示」切換（Android `activity-alias`）。

| key | 名稱 | 預設 |
|---|---|---|
| `sanbi` | 三筆 | ✅ |
| `huati` | 花體 | |

## 檔案
- `android/app/src/main/res/` 直接覆蓋到專案：
  - `mipmap-*/ic_launcher_{key}.png`、`_round.png`（舊版 launcher）
  - `mipmap-*/ic_launcher_{key}_foreground.png`（adaptive 前景，透明底，108dp）
  - `mipmap-*/ic_launcher_{key}_monochrome.png`（Android 13 主題圖示，白色剪影）
  - `mipmap-anydpi-v26/ic_launcher_{key}.xml`、`_round.xml`
  - `ic_launcher*`（不帶 key）＝預設三筆的副本，給 `<application android:icon>` 用
  - `values/ic_launcher_background.xml`：背景白色 `#FFFFFF`
- `playstore/icon-512-{key}.png`：Google Play 用
- `source/`：1024 原圖、前景、monochrome

## 之後要加新 icon
1. 1024×1024 透明底彩色圖，構圖照手機上想見到的大小畫（整張圖＝桌面上看到的 icon，白底由系統補）
2. 另出一張白色 monochrome（透明底）
3. adaptive 前景會自動把整張圖縮到 108dp 畫布中間的 72dp（只有中間 72dp 會顯示），所以不會被放大
4. 跑同一支腳本產生一套 `ic_launcher_{新key}`
5. AndroidManifest 加一個 `activity-alias`（預設 `enabled=false`）
6. `AppIconOption` 清單加一筆（key、名稱、alias 名、預覽圖）
