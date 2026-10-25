package com.slipecode.slipecode

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "slipecode/runtime")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // proot 二进制放在 jniLibs 中，现代 Android 只允许从这里执行
                    "nativeLibraryDir" -> result.success(applicationInfo.nativeLibraryDir)
                    "abi" -> result.success(Build.SUPPORTED_ABIS.firstOrNull() ?: "arm64-v8a")
                    else -> result.notImplemented()
                }
            }
    }
}
