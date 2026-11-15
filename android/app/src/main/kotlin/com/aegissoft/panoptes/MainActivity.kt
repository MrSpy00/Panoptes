package com.aegissoft.panoptes

import android.os.Build
import android.os.Debug
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.InetSocketAddress
import java.net.Socket

class MainActivity : FlutterActivity() {
    private val opsecChannel = "com.aegissoft.panoptes/opsec"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, opsecChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecureScreen" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        runOnUiThread {
                            if (enabled) {
                                window.setFlags(
                                    WindowManager.LayoutParams.FLAG_SECURE,
                                    WindowManager.LayoutParams.FLAG_SECURE
                                )
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            }
                        }
                        result.success(enabled)
                    }
                    "checkDeviceIntegrity" -> {
                        result.success(inspectEnvironment())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun inspectEnvironment(): Map<String, Any> {
        val debuggerAttached = Debug.isDebuggerConnected() || Debug.waitingForDebugger()
        val suPaths = listOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/su/bin/su",
            "/data/adb/magisk"
        )
        val rootDetected = suPaths.any { File(it).exists() } ||
            (Build.TAGS?.contains("test-keys") == true)

        val fridaFiles = listOf(
            "/data/local/tmp/frida-server",
            "/data/local/tmp/re.frida.server"
        )
        var fridaDetected = fridaFiles.any { File(it).exists() }
        if (!fridaDetected) {
            for (port in listOf(27042, 27043)) {
                try {
                    Socket().use { s ->
                        s.connect(InetSocketAddress("127.0.0.1", port), 45)
                        fridaDetected = true
                    }
                } catch (_: Exception) {
                }
            }
        }

        var mapsHookDetected = false
        try {
            val maps = File("/proc/self/maps")
            if (maps.exists()) {
                val content = maps.readText()
                if (content.contains("frida", ignoreCase = true) ||
                    content.contains("xposed", ignoreCase = true) ||
                    content.contains("substrate", ignoreCase = true)
                ) {
                    mapsHookDetected = true
                }
            }
        } catch (_: Exception) {
        }

        val isEmulator = (Build.FINGERPRINT.startsWith("generic") ||
            Build.MODEL.contains("google_sdk") ||
            Build.MODEL.contains("Emulator") ||
            Build.HARDWARE.contains("goldfish") ||
            Build.HARDWARE.contains("ranchu"))

        return mapOf(
            "debuggerAttached" to debuggerAttached,
            "rootDetected" to rootDetected,
            "fridaOrHookDetected" to (fridaDetected || mapsHookDetected),
            "isEmulator" to isEmulator,
            "deviceModel" to "${Build.MANUFACTURER} ${Build.MODEL}",
            "androidRelease" to Build.VERSION.RELEASE
        )
    }
}
