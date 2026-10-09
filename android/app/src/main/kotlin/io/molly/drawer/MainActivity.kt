package io.molly.drawer

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

/**
 * 從其他 App 分享圖片進來（D-053）。
 *
 * 收到 ACTION_SEND / ACTION_SEND_MULTIPLE 後，把每個 content URI 複製進
 * `cacheDir/share_import/`（不保留外部 URI），再把檔案路徑交給 Dart：
 * - 冷啟動：Dart 呼叫 `getInitialShare`，取得啟動時帶來的路徑（沒有則 null）。
 * - 已在執行：`onNewIntent` 後主動呼叫 Dart 的 `onShare`。
 * - `moveTaskToBack`：加入完成後回到原本的 App。
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

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
                "moveTaskToBack" -> {
                    moveTaskToBack(true)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        channel = ch
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel?.setMethodCallHandler(null)
        channel = null
        dartReady = false
        super.cleanUpFlutterEngine(flutterEngine)
    }

    /** 解析 intent；是圖片分享就在背景複製，完成後交給 Dart。處理過的 intent 會被清掉。 */
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

    /** 由 MIME 或檔名推副檔名，都失敗就用 jpg。 */
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
    }
}
