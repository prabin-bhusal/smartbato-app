package com.smartbato.app

import android.os.Build
import android.os.Debug
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.Socket

class MainActivity : FlutterActivity() {
    private val securityChannelName = "com.smartbato.app/security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, securityChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enableSecureWindow" -> {
                        try {
                            window.setFlags(
                                WindowManager.LayoutParams.FLAG_SECURE,
                                WindowManager.LayoutParams.FLAG_SECURE
                            )
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("FAILED", e.message, null)
                        }
                    }
                    "disableSecureWindow" -> {
                        try {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("FAILED", e.message, null)
                        }
                    }
                    "getDeviceRisk" -> {
                        try {
                            result.success(
                                mapOf(
                                    "isRooted" to isRooted(),
                                    "isJailbroken" to false,
                                    "isEmulator" to isEmulator(),
                                    "isHooked" to isHookedEnvironment(),
                                    "isDebuggerAttached" to Debug.isDebuggerConnected(),
                                )
                            )
                        } catch (e: Exception) {
                            result.error("FAILED", e.message, null)
                        }
                    }
                    "getAttestationToken" -> {
                        // TODO: integrate Play Integrity API token generation using cloud project number.
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isEmulator(): Boolean {
        return (Build.FINGERPRINT.startsWith("generic")
                || Build.FINGERPRINT.lowercase().contains("vbox")
                || Build.FINGERPRINT.lowercase().contains("test-keys")
                || Build.MODEL.contains("google_sdk")
                || Build.MODEL.contains("Emulator")
                || Build.MODEL.contains("Android SDK built for x86")
                || Build.MANUFACTURER.contains("Genymotion")
                || Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic")
                || "google_sdk" == Build.PRODUCT)
    }

    private fun isRooted(): Boolean {
        val rootPaths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su"
        )

        if (Build.TAGS?.contains("test-keys") == true) {
            return true
        }

        if (rootPaths.any { File(it).exists() }) {
            return true
        }

        return try {
            val process = Runtime.getRuntime().exec(arrayOf("/system/xbin/which", "su"))
            process.inputStream.bufferedReader().use { it.readLine() != null }
        } catch (_: Exception) {
            false
        }
    }

    private fun isHookedEnvironment(): Boolean {
        if (File("/data/local/tmp/frida-server").exists()) {
            return true
        }

        if (File("/data/local/tmp/re.frida.server").exists()) {
            return true
        }

        val suspiciousPorts = listOf(27042, 27043)
        if (suspiciousPorts.any { isLocalPortOpen(it) }) {
            return true
        }

        val processList = try {
            Runtime.getRuntime().exec("ps").inputStream.bufferedReader().readText().lowercase()
        } catch (_: Exception) {
            ""
        }

        if (processList.contains("frida") || processList.contains("xposed") || processList.contains("substrate")) {
            return true
        }

        return try {
            Class.forName("de.robv.android.xposed.XposedBridge")
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun isLocalPortOpen(port: Int): Boolean {
        return try {
            Socket("127.0.0.1", port).use { true }
        } catch (_: Exception) {
            false
        }
    }
}
