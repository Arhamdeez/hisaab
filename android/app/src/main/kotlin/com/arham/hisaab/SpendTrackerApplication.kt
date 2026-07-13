package com.arham.hisaab

import android.app.Application

class SpendTrackerApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        LegacyDataMigrator.migrateIfNeeded(this)
    }
}
