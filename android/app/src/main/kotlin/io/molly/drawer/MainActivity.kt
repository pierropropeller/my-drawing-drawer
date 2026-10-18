package io.molly.drawer

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

/**
 * 從其他 App 分享圖片、GIF、影片進來（D-053、D-080）。
 *
 * 收到 ACTION_SEND / ACTION_SEND_MULTIPLE 後，把每個 content URI 複製進
 * `cacheDir/share_import/`（不保留外部 URI），再把檔案路徑交給 Dart：
 * - 冷啟動：Dart 呼叫 `getInitialShare`，取得啟動時帶來的路徑（沒有則 null）。
 * - 已在執行：`onNewIntent` 後主動呼叫 Dart 的 `onShare`。
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var mediaChannel: MethodChannel? = null
    private var appIconChannel: MethodChannel? = null

    // Dart 端是否已呼叫過 getInitialShare（之後的分享改用 onShare 推送）。
    private var dartReady = false

    // Dart 還沒來取之前收到的路徑。
    private var pending: MutableList<String>? = null

    // Dart 已在等 getInitialShare，但複製還沒做完。
    private var initialWaiter: MethodChannel.Result? = null

    // 還在背景複製的批數。
    private var copying = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 重建或從最近工作列回來時，intent 還是舊的，不要重複匯入。
        val fromHistory =
            (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0
        if (savedInstanceState == null && !fromHistory) {
            handleShareIntent(intent)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleShareIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        )
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialShare" -> {
                    dartReady = true
                    val ready = pending
                    if (ready != null) {
                        pending = null
                        result.success(ready)
                    } else if (copying > 0) {
                        initialWaiter = result
                    } else {
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        channel = ch

        // 影片探測（D-080）：寬高、長度、第一格截圖，Dart 端見 lib/media/video_probe.dart。
        val media = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MEDIA_CHANNEL,
        )
        media.setMethodCallHandler { call, result ->
            when (call.method) {
                "probeVideo" -> {
                    val path = call.argument<String>("path")
                    val maxSide = call.argument<Int>("maxSide") ?: 720
                    if (path == null) {
                        result.success(null)
                    } else {
                        // 解碼第一格可能要幾百毫秒，不卡 UI thread。
                        Thread {
                            // 任何情況（含 OOM）都要回覆，否則 Dart 端會一直等。
                            val out = try {
                                probeVideo(path, maxSide)
                            } catch (_: Throwable) {
                                null
                            }
                            runOnUiThread { result.success(out) }
                        }.start()
                    }
                }
                "extractFrames" -> {
                    // 參考圖檢視（影片）：時間軸縮圖與「截取此格」，Dart 端見 lib/ui/reference/ref_frames.dart。
                    val path = call.argument<String>("path")
                    val positions = call.argument<List<Number>>("positionsMs") ?: emptyList()
                    val maxSide = call.argument<Int>("maxSide") ?: 240
                    val quality = call.argument<Int>("quality") ?: 70
                    val exact = call.argument<Boolean>("exact") ?: false
                    if (path == null) {
                        result.success(null)
                    } else {
                        Thread {
                            val out = extractFrames(path, positions, maxSide, quality, exact)
                            runOnUiThread { result.success(out) }
                        }.start()
                    }
                }
                else -> result.notImplemented()
            }
        }
        mediaChannel = media

        // App 圖示（D-086）：用 activity-alias 切換桌面圖示，Dart 端見 lib/state/app_icon.dart。
        val appIcon = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_ICON_CHANNEL,
        )
        appIcon.setMethodCallHandler { call, result ->
            when (call.method) {
                "currentIcon" -> result.success(
                    try {
                        currentIconAlias()
                    } catch (_: Exception) {
                        null
                    },
                )
                "setIcon" -> {
                    val alias = call.argument<String>("alias")
                    if (alias == null) {
                        result.error("bad_args", "alias is required", null)
                    } else {
                        try {
                            if (setIconAlias(alias)) {
                                result.success(null)
                            } else {
                                result.error("no_such_alias", alias, null)
                            }
                        } catch (e: Exception) {
                            result.error("set_failed", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
        appIconChannel = appIcon
    }

    /**
     * 所有指向 MainActivity 的 activity-alias（含停用的），傳回簡短名稱（`IconSanbi`）與完整類別名。
     * 用查的而不是寫死，之後加新圖示只要在 Manifest 加一個 alias。
     */
    @Suppress("DEPRECATION")
    private fun iconAliases(): List<Pair<String, String>> {
        val info = try {
            packageManager.getPackageInfo(
                packageName,
                PackageManager.GET_ACTIVITIES or PackageManager.MATCH_DISABLED_COMPONENTS,
            )
        } catch (_: Exception) {
            return emptyList()
        }
        val main = javaClass.name
        return (info.activities ?: emptyArray())
            .filter { it.targetActivity == main }
            .map { it.name.substringAfterLast('.') to it.name }
    }

    /** 目前啟用的 alias 簡短名稱；沒有（或查不到）回 null，Dart 就用預設。 */
    private fun currentIconAlias(): String? {
        for ((short, full) in iconAliases()) {
            val state = packageManager.getComponentEnabledSetting(ComponentName(packageName, full))
            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) return short
        }
        // 尚未手動切換過（DEFAULT）：以 Manifest 的 enabled 為準。
        for ((short, full) in iconAliases()) {
            val state = packageManager.getComponentEnabledSetting(ComponentName(packageName, full))
            if (state == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT &&
                packageManager.getActivityInfo(
                    ComponentName(packageName, full),
                    PackageManager.MATCH_DISABLED_COMPONENTS,
                ).enabled
            ) {
                return short
            }
        }
        return null
    }

    /** 啟用 [alias]、停用其他 alias。先開後關，確保任何時刻桌面都有入口。 */
    private fun setIconAlias(alias: String): Boolean {
        val all = iconAliases()
        val target = all.firstOrNull { it.first == alias } ?: return false
        packageManager.setComponentEnabledSetting(
            ComponentName(packageName, target.second),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        for ((short, full) in all) {
            if (short == alias) continue
            packageManager.setComponentEnabledSetting(
                ComponentName(packageName, full),
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
        return true
    }

    /**
     * 讀影片的寬高（套用旋轉）、長度與海報 JPEG 截圖（Molly 的規則：影片 ≥1 秒取第 1 秒的畫面，
     * 不足 1 秒取第一格）。截圖失敗不影響寬高與長度；整支影片讀不開才回 null。
     */
    private fun probeVideo(path: String, maxSide: Int): Map<String, Any?>? {
        val mmr = MediaMetadataRetriever()
        try {
            mmr.setDataSource(path)
        } catch (_: Throwable) {
            try {
                mmr.release()
            } catch (_: Throwable) {
            }
            return null
        }
        try {
            var w = metaInt(mmr, MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
            var h = metaInt(mmr, MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
            val rotation = metaInt(mmr, MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
            if (rotation == 90 || rotation == 270) {
                val t = w
                w = h
                h = t
            }
            val duration: Long? = try {
                mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull()
            } catch (_: Throwable) {
                null
            }

            var poster: ByteArray? = null
            try {
                var bitmap = grabPosterFrame(mmr, duration, w, h, maxSide)
                if (bitmap != null) {
                    bitmap = fixOrientation(bitmap, rotation, w, h)
                    if (w == 0 || h == 0) {
                        w = bitmap.width
                        h = bitmap.height
                    }
                    val longest = maxOf(bitmap.width, bitmap.height)
                    if (longest > maxSide) {
                        val s = maxSide.toDouble() / longest
                        bitmap = Bitmap.createScaledBitmap(
                            bitmap,
                            maxOf(1, Math.round(bitmap.width * s).toInt()),
                            maxOf(1, Math.round(bitmap.height * s).toInt()),
                            true,
                        )
                    }
                    val bytes = ByteArrayOutputStream()
                    if (bitmap.compress(Bitmap.CompressFormat.JPEG, 85, bytes)) {
                        poster = bytes.toByteArray()
                    }
                }
            } catch (_: Throwable) {
                // 截圖失敗（含記憶體不足）只丟掉截圖，寬高與長度照回傳，之後由 Dart 端補。
                poster = null
            }
            return mapOf(
                "width" to w,
                "height" to h,
                "durationMs" to duration?.toInt(),
                "poster" to poster,
            )
        } catch (_: Throwable) {
            return null
        } finally {
            try {
                mmr.release()
            } catch (_: Throwable) {
            }
        }
    }

    private fun metaInt(mmr: MediaMetadataRetriever, key: Int): Int = try {
        mmr.extractMetadata(key)?.toIntOrNull() ?: 0
    } catch (_: Throwable) {
        0
    }

    /**
     * 依序嘗試各種取畫面的方法，第一個非 null 的就用：
     * 1. 第 1 秒（影片不足 1 秒或長度未知時先試 0）：OPTION_CLOSEST、再 OPTION_CLOSEST_SYNC；
     * 2. API 27+ 的 getScaledFrameAtTime（解碼大圖失敗時用）；
     * 3. API 28+ 的 getFrameAtIndex(0)；
     * 4. 不帶參數的 getFrameAtTime()。
     */
    private fun grabPosterFrame(
        mmr: MediaMetadataRetriever,
        durationMs: Long?,
        w: Int,
        h: Int,
        maxSide: Int,
    ): Bitmap? {
        val times: List<Long> =
            if (durationMs == null || durationMs >= 1000) listOf(1_000_000L, 0L) else listOf(0L)
        val options = listOf(
            MediaMetadataRetriever.OPTION_CLOSEST,
            MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
        )
        for (t in times) {
            for (opt in options) {
                try {
                    val b = mmr.getFrameAtTime(t, opt)
                    if (b != null) return b
                } catch (_: Throwable) {
                }
            }
        }
        if (Build.VERSION.SDK_INT >= 27) {
            val scale = if (w > 0 && h > 0) minOf(1.0, maxSide.toDouble() / maxOf(w, h)) else 1.0
            val sw = if (w > 0) maxOf(1, Math.round(w * scale).toInt()) else maxSide
            val sh = if (h > 0) maxOf(1, Math.round(h * scale).toInt()) else maxSide
            for (t in times) {
                for (opt in options) {
                    try {
                        val b = mmr.getScaledFrameAtTime(t, opt, sw, sh)
                        if (b != null) return b
                    } catch (_: Throwable) {
                    }
                }
            }
        }
        if (Build.VERSION.SDK_INT >= 28) {
            try {
                val b = mmr.getFrameAtIndex(0)
                if (b != null) return b
            } catch (_: Throwable) {
            }
        }
        try {
            return mmr.frameAtTime
        } catch (_: Throwable) {
        }
        return null
    }

    /**
     * 多數機型 getFrameAtTime 已經把旋轉套好；少數機型（影片帶 90/270 度旋轉旗標）沒有，
     * 這時畫面的方向會跟「已旋轉的寬高」相反，補轉回來。
     */
    private fun fixOrientation(bitmap: Bitmap, rotation: Int, w: Int, h: Int): Bitmap {
        if (rotation != 90 && rotation != 270) return bitmap
        if (w <= 0 || h <= 0 || w == h) return bitmap
        val expectPortrait = h > w
        val isPortrait = bitmap.height > bitmap.width
        if (expectPortrait == isPortrait) return bitmap
        return try {
            val m = android.graphics.Matrix()
            m.postRotate(rotation.toFloat())
            Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, m, true)
        } catch (_: Throwable) {
            bitmap
        }
    }

    /**
     * 抽出影片在指定時間點（毫秒）的畫面（JPEG，最長邊不超過 maxSide），並盡量回傳幀率。
     * 抽不到的那一格是 null；整支影片讀不開回 null。[exact] false 取最近的關鍵格（快），
     * true 取最接近該時間的畫面（截取用）。
     */
    private fun extractFrames(
        path: String,
        positionsMs: List<Number>,
        maxSide: Int,
        quality: Int,
        exact: Boolean,
    ): Map<String, Any?>? {
        val mmr = MediaMetadataRetriever()
        try {
            mmr.setDataSource(path)
            val duration = mmr.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_DURATION,
            )?.toLongOrNull()
            var fps: Double? = null
            if (Build.VERSION.SDK_INT >= 28) {
                val count = mmr.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_VIDEO_FRAME_COUNT,
                )?.toLongOrNull()
                if (count != null && duration != null && count > 0 && duration > 0) {
                    fps = count * 1000.0 / duration
                }
            }
            val option = if (exact) {
                MediaMetadataRetriever.OPTION_CLOSEST
            } else {
                MediaMetadataRetriever.OPTION_CLOSEST_SYNC
            }
            val frames = ArrayList<ByteArray?>()
            for (p in positionsMs) {
                var bytes: ByteArray? = null
                try {
                    var bitmap: Bitmap? = mmr.getFrameAtTime(p.toLong() * 1000, option)
                    if (bitmap != null) {
                        val longest = maxOf(bitmap.width, bitmap.height)
                        if (longest > maxSide) {
                            val s = maxSide.toDouble() / longest
                            bitmap = Bitmap.createScaledBitmap(
                                bitmap,
                                maxOf(1, Math.round(bitmap.width * s).toInt()),
                                maxOf(1, Math.round(bitmap.height * s).toInt()),
                                true,
                            )
                        }
                        val out = ByteArrayOutputStream()
                        bitmap.compress(Bitmap.CompressFormat.JPEG, quality, out)
                        bytes = out.toByteArray()
                    }
                } catch (_: Exception) {
                    // 這一格取不到就留 null。
                }
                frames.add(bytes)
            }
            return mapOf("frames" to frames, "fps" to fps)
        } catch (_: Exception) {
            return null
        } finally {
            try {
                mmr.release()
            } catch (_: Exception) {
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel?.setMethodCallHandler(null)
        channel = null
        mediaChannel?.setMethodCallHandler(null)
        mediaChannel = null
        appIconChannel?.setMethodCallHandler(null)
        appIconChannel = null
        dartReady = false
        super.cleanUpFlutterEngine(flutterEngine)
    }

    /** 解析 intent；是圖片／GIF／影片分享就在背景複製，完成後交給 Dart。處理過的 intent 會被清掉。 */
    private fun handleShareIntent(source: Intent?) {
        if (source == null) return
        val action = source.action
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) return
        val uris = collectUris(source)
        // 清掉已處理的 intent，避免旋轉或重新進入時再次匯入。
        setIntent(Intent(Intent.ACTION_MAIN))
        if (uris.isEmpty()) return
        copying++
        Thread {
            val paths = copyAll(uris)
            runOnUiThread {
                copying--
                deliver(paths)
            }
        }.start()
    }

    private fun deliver(paths: List<String>) {
        val waiter = initialWaiter
        if (waiter != null) {
            initialWaiter = null
            // 全部讀取失敗時回傳 null，Dart 當作沒有分享。
            waiter.success(if (paths.isEmpty()) null else paths)
            return
        }
        if (paths.isEmpty()) return
        val ch = channel
        if (dartReady && ch != null) {
            ch.invokeMethod("onShare", paths)
        } else {
            val list = pending ?: mutableListOf()
            list.addAll(paths)
            pending = list
        }
    }

    @Suppress("DEPRECATION")
    private fun collectUris(source: Intent): List<Uri> {
        val found = LinkedHashSet<Uri>()
        try {
            if (source.action == Intent.ACTION_SEND_MULTIPLE) {
                val list: List<Uri>? =
                    if (Build.VERSION.SDK_INT >= 33) {
                        source.getParcelableArrayListExtra(
                            Intent.EXTRA_STREAM,
                            Uri::class.java,
                        )
                    } else {
                        source.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                    }
                if (list != null) found.addAll(list)
            } else {
                val one: Uri? =
                    if (Build.VERSION.SDK_INT >= 33) {
                        source.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                    } else {
                        source.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                    }
                if (one != null) found.add(one)
            }
        } catch (_: Exception) {
            // 取不到 EXTRA_STREAM 就改用 ClipData。
        }
        val clip = source.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) {
                val uri = clip.getItemAt(i).uri
                if (uri != null) found.add(uri)
            }
        }
        return found.toList()
    }

    private fun copyAll(uris: List<Uri>): List<String> {
        val dir = File(cacheDir, "share_import")
        dir.mkdirs()
        // 清掉超過一天的舊檔（Dart 匯入後會自己刪，這裡只是保險）。
        val cutoff = System.currentTimeMillis() - 24L * 60 * 60 * 1000
        dir.listFiles()?.forEach { if (it.lastModified() < cutoff) it.delete() }
        val out = ArrayList<String>()
        for (uri in uris) {
            val target = File(dir, "${UUID.randomUUID()}.${extensionOf(uri)}")
            try {
                val input = contentResolver.openInputStream(uri)
                if (input == null) continue
                input.use { src ->
                    FileOutputStream(target).use { dst -> src.copyTo(dst) }
                }
                if (target.length() > 0) {
                    out.add(target.absolutePath)
                } else {
                    target.delete()
                }
            } catch (_: Exception) {
                // 讀不到的 URI（權限、已刪除）直接略過。
                target.delete()
            }
        }
        return out
    }

    /** 由 MIME 或檔名推副檔名（image/gif→gif、video/mp4→mp4…），都失敗就用 jpg。 */
    private fun extensionOf(uri: Uri): String {
        try {
            val mime = contentResolver.getType(uri)
            if (mime != null) {
                val ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(mime)
                if (ext != null && ext.isNotEmpty()) return ext
            }
        } catch (_: Exception) {
        }
        try {
            val name = displayNameOf(uri)
            if (name != null) {
                val dot = name.lastIndexOf('.')
                val len = name.length - dot - 1
                if (dot >= 0 && len in 1..5) return name.substring(dot + 1).lowercase()
            }
        } catch (_: Exception) {
        }
        return "jpg"
    }

    private fun displayNameOf(uri: Uri): String? {
        if (uri.scheme != "content") return uri.lastPathSegment
        val cursor = contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null,
        )
        if (cursor == null) return null
        cursor.use { c ->
            return if (c.moveToFirst()) c.getString(0) else null
        }
    }

    companion object {
        private const val CHANNEL = "io.molly.drawer/share"
        private const val MEDIA_CHANNEL = "io.molly.drawer/media"
        private const val APP_ICON_CHANNEL = "io.molly.drawer/appicon"
    }
}
