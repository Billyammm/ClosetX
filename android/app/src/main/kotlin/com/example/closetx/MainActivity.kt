package com.example.closetx

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.snap.camerakit.support.app.CameraActivity

class MainActivity : FlutterFragmentActivity() {
    private var pendingCameraResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val captureLauncher = registerForActivityResult(CameraActivity.Play) { result ->
            val pendingResult = pendingCameraResult ?: return@registerForActivityResult
            pendingCameraResult = null

            when (result) {
                is CameraActivity.Play.Result.Completed -> pendingResult.success(null)
                is CameraActivity.Play.Result.Failure ->
                    pendingResult.error("CAMERA_KIT_FAILED", result.exception.message, null)
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "launchLens") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val lensId = call.argument<String>("lensId")?.trim()
                val lensGroupId = call.argument<String>("lensGroupId")?.trim()
                if (lensId.isNullOrEmpty() || lensGroupId.isNullOrEmpty()) {
                    result.error(
                        "MISSING_LENS_METADATA",
                        "This design needs a Lens ID and Lens Group ID before AR try-on.",
                        null
                    )
                    return@setMethodCallHandler
                }

                val apiToken = packageManager
                    .getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                    .metaData
                    ?.getString("com.snap.camerakit.api.token")
                    ?.trim()
                if (apiToken.isNullOrEmpty()) {
                    result.error(
                        "CAMERA_KIT_NOT_CONFIGURED",
                        "Add the Android Camera Kit API token to android/local.properties, then rebuild.",
                        null
                    )
                    return@setMethodCallHandler
                }

                if (pendingCameraResult != null) {
                    result.error("CAMERA_KIT_BUSY", "Camera Kit is already open.", null)
                    return@setMethodCallHandler
                }

                pendingCameraResult = result
                try {
                    captureLauncher.launch(
                        CameraActivity.Configuration.WithLens(
                            lensGroupId = lensGroupId,
                            lensId = lensId
                        )
                    )
                } catch (error: Exception) {
                    pendingCameraResult = null
                    result.error("CAMERA_KIT_FAILED", error.message, null)
                }
            }
    }

    companion object {
        private const val CHANNEL = "com.closetx/camera_kit"
    }
}
