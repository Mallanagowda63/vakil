package com.vakilpartner.vakil_partner

import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // A call accepted on the lock screen opens the app over it; only while
    // the call screen is up, so the rest of the app still needs unlocking.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vakil/call_window").setMethodCallHandler { call, result ->
            if (call.method != "showOverLockScreen") return@setMethodCallHandler result.notImplemented()
            val on = call.arguments as? Boolean ?: false
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(on)
                setTurnScreenOn(on)
            } else {
                @Suppress("DEPRECATION")
                val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                if (on) window.addFlags(flags) else window.clearFlags(flags)
            }
            result.success(null)
        }
        // The online bubble over other apps (see OnlineBubble.kt).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vakil/online_bubble").setMethodCallHandler { call, result ->
            when (call.method) {
                "canDraw" -> result.success(OnlineBubble.canDraw(this))
                "openSettings" -> { OnlineBubble.openPermissionSettings(this); result.success(null) }
                "show" -> result.success(OnlineBubble.show(this))
                "hide" -> { OnlineBubble.hide(this); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }
}
