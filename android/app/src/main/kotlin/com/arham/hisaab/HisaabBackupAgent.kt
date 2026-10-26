package com.arham.hisaab

import android.app.backup.BackupAgentHelper
import android.app.backup.FullBackupDataOutput
import android.database.sqlite.SQLiteDatabase
import java.io.File

/**
 * Writes pending SQLite pages into the main database file before Android
 * copies app data. The phone can then restore transactions after a reinstall.
 */
class HisaabBackupAgent : BackupAgentHelper() {
    override fun onFullBackup(data: FullBackupDataOutput) {
        checkpointSpendTracker()
        super.onFullBackup(data)
    }

    private fun checkpointSpendTracker() {
        val file = File(filesDir, "spend_tracker.sqlite")
        if (!file.exists()) return
        try {
            val db = SQLiteDatabase.openDatabase(
                file.absolutePath,
                null,
                SQLiteDatabase.OPEN_READWRITE,
            )
            try {
                db.execSQL("PRAGMA busy_timeout = 3000")
                db.rawQuery("PRAGMA wal_checkpoint(TRUNCATE)", null)?.use { cursor ->
                    cursor.moveToFirst()
                }
            } finally {
                db.close()
            }
        } catch (_: Exception) {
        }
    }
}
