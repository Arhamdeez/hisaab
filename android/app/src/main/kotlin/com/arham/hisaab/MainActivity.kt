package com.arham.hisaab

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        IngestPlugin(this, flutterEngine)
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
