package io.github.iogami0103.attackofthedragon

import android.content.ComponentCallbacks2
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var audioLifecycleChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        audioLifecycleChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "attack_of_the_dragon/audio_lifecycle"
        )
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            audioLifecycleChannel?.invokeMethod("resumed", "window_focus")
        }
    }

    override fun onResume() {
        super.onResume()
        audioLifecycleChannel?.invokeMethod("resumed", null)
    }

    override fun onUserLeaveHint() {
        audioLifecycleChannel?.invokeMethod("inactive", "user_leave")
        super.onUserLeaveHint()
    }

    override fun onPause() {
        audioLifecycleChannel?.invokeMethod("inactive", "pause")
        super.onPause()
    }

    override fun onStop() {
        audioLifecycleChannel?.invokeMethod("inactive", "stop")
        super.onStop()
    }

    override fun onTrimMemory(level: Int) {
        if (level >= ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN) {
            audioLifecycleChannel?.invokeMethod("inactive", "ui_hidden")
        }
        super.onTrimMemory(level)
    }

    override fun onDestroy() {
        audioLifecycleChannel?.invokeMethod("inactive", "destroy")
        super.onDestroy()
    }
}
