package de.kaufmann.sitzplan

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val updaterChannel = "de.kaufmann.sitzplan/updater"
    private var pendingApkPath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updaterChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "installApk") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("missing_path", "Kein APK-Pfad angegeben.", null)
                    return@setMethodCallHandler
                }
                try {
                    result.success(installApk(path))
                } catch (error: Exception) {
                    result.error("install_failed", error.message, null)
                }
            }
    }

    private fun installApk(path: String): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            pendingApkPath = path
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"),
                ),
            )
            return false
        }

        launchInstaller(path)
        return true
    }

    private fun launchInstaller(path: String) {
        val apk = File(path)
        require(apk.exists() && apk.isFile) { "Die heruntergeladene APK fehlt." }
        require(apk.canonicalPath.startsWith(cacheDir.canonicalPath + File.separator)) {
            "Die APK liegt außerhalb des geschützten Update-Verzeichnisses."
        }
        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.updater.fileprovider",
            apk,
        )
        startActivity(
            Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
        )
    }

    override fun onResume() {
        super.onResume()
        val path = pendingApkPath ?: return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()
        ) {
            pendingApkPath = null
            launchInstaller(path)
        }
    }
}
