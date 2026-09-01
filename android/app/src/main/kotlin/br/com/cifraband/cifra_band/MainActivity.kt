package br.com.cifraband.cifra_band

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APK_INSTALLER_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val apkPath = call.argument<String>("path")
                    if (apkPath.isNullOrBlank()) {
                        result.error(
                            "INVALID_PATH",
                            "O caminho da APK nao foi informado.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        openApkInstaller(apkPath)
                        result.success(true)
                    } catch (error: Exception) {
                        result.error(
                            "INSTALLER_ERROR",
                            error.message ?: "Falha ao abrir instalador.",
                            null
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun openApkInstaller(apkPath: String) {
        val apkFile = File(apkPath)
        if (!apkFile.exists()) {
            throw IllegalArgumentException("APK nao encontrada.")
        }

        val apkUri: Uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            apkFile
        )

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(
                apkUri,
                "application/vnd.android.package-archive"
            )
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        startActivity(intent)
    }

    companion object {
        private const val APK_INSTALLER_CHANNEL = "cifra_band/apk_installer"
    }
}
