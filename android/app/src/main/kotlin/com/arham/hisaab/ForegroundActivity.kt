package com.arham.hisaab

import android.app.Activity

/** Tracks the foreground [Activity] for system settings intents launched from Flutter. */
object ForegroundActivity {
    @Volatile
    var activity: Activity? = null
}
