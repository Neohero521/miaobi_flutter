package com.miaobi.miaobi_flutter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        
        // Register native EditText platform view
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "native_edit_text",
            NativeEditTextFactory(messenger)
        )
    }
}
