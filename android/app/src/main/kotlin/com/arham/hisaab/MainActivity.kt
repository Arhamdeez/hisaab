package com.arham.hisaab

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // FlutterActivity is not a ComponentActivity, so Activity.enableEdgeToEdge()
        // cannot be used. This is the same WindowCompat call that API uses.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        IngestPlugin(this, flutterEngine)
        SlideHapticsPlugin.register(flutterEngine)
        // Available for splash haptics before first onResume in some paths.
        ForegroundActivity.activity = this
    }

    override fun onResume() {
        super.onResume()
        ForegroundActivity.activity = this
    }

    override fun onPause() {
        if (ForegroundActivity.activity === this) {
            ForegroundActivity.activity = null
        }
        super.onPause()
    }

    override fun onDestroy() {
        if (ForegroundActivity.activity === this) {
            ForegroundActivity.activity = null
        }
        super.onDestroy()
    }
}
