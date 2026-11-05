package com.loosetie.triplingtable

import android.os.Build
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var immersive = false
    private var previousBehavior: Int? = null
    private var previousVisibility: Int? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.loosetie.triplingtable/system_ui"
        ).setMethodCallHandler { call, result ->
            if (call.method != "setImmersive") {
                result.notImplemented()
            } else {
                immersive = call.arguments == true
                applySystemBars()
                result.success(null)
            }
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && immersive) {
            window.decorView.post {
                if (immersive && hasWindowFocus()) applySystemBars()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun applySystemBars() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val controller = window.insetsController ?: return
            if (immersive) {
                if (previousBehavior == null) {
                    previousBehavior = controller.systemBarsBehavior
                }
                controller.systemBarsBehavior =
                    WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                controller.hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
            } else {
                controller.show(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
                previousBehavior?.let { controller.systemBarsBehavior = it }
                previousBehavior = null
            }
        } else {
            val decor = window.decorView
            if (immersive) {
                if (previousVisibility == null) previousVisibility = decor.systemUiVisibility
                decor.systemUiVisibility = decor.systemUiVisibility or
                    View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                    View.SYSTEM_UI_FLAG_FULLSCREEN or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
            } else {
                previousVisibility?.let { decor.systemUiVisibility = it }
                previousVisibility = null
            }
        }
    }
}
