package br.com.cifraband.cifra_band

import android.app.AlertDialog
import android.content.Intent
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.InstallStateUpdatedListener
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val updates by lazy { AppUpdateManagerFactory.create(this) }
    private var checking = false
    private var flowActive = false
    private var lastPromptAt = 0L
    private var restartDialog: AlertDialog? = null
    private val listener = InstallStateUpdatedListener { state ->
        if (state.installStatus() == InstallStatus.DOWNLOADED) showRestart()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        updates.registerListener(listener)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cifra_band/play_updates")
            .setMethodCallHandler { call, result ->
                if (call.method == "checkForUpdate") {
                    checkUpdate(false)
                    result.success(null)
                } else result.notImplemented()
            }
    }

    private fun checkUpdate(resumeOnly: Boolean) {
        if (checking || flowActive || isFinishing) return
        checking = true
        updates.appUpdateInfo.addOnSuccessListener { info ->
            checking = false
            if (info.installStatus() == InstallStatus.DOWNLOADED) {
                showRestart()
                return@addOnSuccessListener
            }
            val ongoing = info.updateAvailability() == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS
            if (!ongoing && (resumeOnly || info.updateAvailability() != UpdateAvailability.UPDATE_AVAILABLE ||
                        System.currentTimeMillis() - lastPromptAt < 10 * 60 * 1000)) return@addOnSuccessListener
            val type = if (ongoing || info.updatePriority() >= 4) AppUpdateType.IMMEDIATE else AppUpdateType.FLEXIBLE
            if (!info.isUpdateTypeAllowed(type)) return@addOnSuccessListener
            try {
                flowActive = updates.startUpdateFlowForResult(info, this,
                    AppUpdateOptions.newBuilder(type).build(), 7201)
                if (flowActive) lastPromptAt = System.currentTimeMillis()
            } catch (_: Exception) { flowActive = false }
        }.addOnFailureListener { checking = false }
    }

    private fun showRestart() {
        if (isFinishing || restartDialog?.isShowing == true) return
        restartDialog = AlertDialog.Builder(this)
            .setTitle("Atualização pronta")
            .setMessage("Reinicie o Cifra Band para concluir a atualização.")
            .setPositiveButton("Reiniciar") { _, _ -> updates.completeUpdate() }
            .setNegativeButton("Depois", null).show()
    }

    override fun onResume() { super.onResume(); checkUpdate(true) }

    @Deprecated("Activity result API used by Play Core")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 7201) flowActive = false
    }

    override fun onDestroy() {
        restartDialog?.dismiss()
        updates.unregisterListener(listener)
        super.onDestroy()
    }
}
