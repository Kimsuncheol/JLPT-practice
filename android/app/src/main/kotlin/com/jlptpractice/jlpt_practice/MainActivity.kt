package com.jlptpractice.jlpt_practice

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.os.StatFs
import java.io.File

class MainActivity : FlutterActivity() {
    private var offlineChannel: MethodChannel? = null
    private var thermalListener: PowerManager.OnThermalStatusChangedListener? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jlpt_practice/offline_ai")
        offlineChannel = channel
        channel.setMethodCallHandler { call, result ->
            if (call.method != "capacity") {
                result.notImplemented()
            } else {
                try {
                    val memory = ActivityManager.MemoryInfo()
                    (getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).getMemoryInfo(memory)
                    val directory = File(noBackupFilesDir, "offline_ai")
                    directory.mkdirs()
                    val power = getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(mapOf(
                        "totalRam" to memory.totalMem,
                        "availableRam" to if (memory.lowMemory) 0L else (memory.availMem - memory.threshold).coerceAtLeast(0L),
                        "freeStorage" to StatFs(directory.absolutePath).availableBytes,
                        "is64Bit" to Process.is64Bit(),
                        "hot" to (Build.VERSION.SDK_INT >= 29 && power.currentThermalStatus >= PowerManager.THERMAL_STATUS_SEVERE),
                        "directory" to directory.absolutePath
                    ))
                } catch (error: Exception) {
                    result.error("capacity", "Device capacity unavailable", null)
                }
            }
        }
        if (Build.VERSION.SDK_INT >= 29) {
            val power = getSystemService(Context.POWER_SERVICE) as PowerManager
            thermalListener = PowerManager.OnThermalStatusChangedListener { status ->
                if (status >= PowerManager.THERMAL_STATUS_SEVERE) {
                    runOnUiThread { channel.invokeMethod("pressure", "thermal") }
                }
            }
            power.addThermalStatusListener(thermalListener!!)
        }
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        if (level == TRIM_MEMORY_RUNNING_LOW || level == TRIM_MEMORY_RUNNING_CRITICAL || level >= TRIM_MEMORY_BACKGROUND) {
            offlineChannel?.invokeMethod("pressure", "memory")
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        if (Build.VERSION.SDK_INT >= 29) {
            thermalListener?.let {
                (getSystemService(Context.POWER_SERVICE) as PowerManager).removeThermalStatusListener(it)
            }
        }
        offlineChannel?.setMethodCallHandler(null)
        offlineChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
