package com.example.spend_tracker

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log

/**
 * Durable queue for payment alerts captured while Flutter is not running.
 * Drained into the main app database on the next launch.
 */
object CapturedEventStore {
    private const val TAG = "CapturedEventStore"
    private const val DB_NAME = "captured_ingest.db"
    private const val DB_VERSION = 1
    private const val MAX_ROWS = 500

    private class QueueDb(context: Context) :
        SQLiteOpenHelper(context.applicationContext, DB_NAME, null, DB_VERSION) {
        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL(
                """
                CREATE TABLE captured_events (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    source TEXT NOT NULL,
                    text TEXT NOT NULL,
                    package TEXT,
                    sender TEXT,
                    timestamp INTEGER NOT NULL,
                    captured_at INTEGER NOT NULL
                )
                """.trimIndent(),
            )
        }

        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {}
    }

    fun pendingCount(context: Context): Int {
        return try {
            val db = QueueDb(context).readableDatabase
            db.compileStatement("SELECT COUNT(*) FROM captured_events")
                .simpleQueryForLong()
                .toInt()
        } catch (_: Exception) {
            0
        }
    }

    fun enqueue(context: Context, event: Map<String, Any?>) {
        val text = event["text"] as? String ?: return
        if (text.isBlank()) return
        val timestamp = (event["timestamp"] as? Number)?.toLong()
            ?: System.currentTimeMillis()
        val pkg = event["package"] as? String
        val normalized = normalizeQueueText(text)

        try {
            val db = QueueDb(context).writableDatabase
            db.beginTransaction()
            try {
                // Skip duplicate rows — same package + normalized body (rescans).
                val cursor = db.rawQuery(
                    """
                    SELECT text FROM captured_events
                    WHERE IFNULL(package, '') = IFNULL(?, '')
                    """.trimIndent(),
                    arrayOf(pkg ?: ""),
                )
                while (cursor.moveToNext()) {
                    val existing = cursor.getString(0) ?: continue
                    if (normalizeQueueText(existing) == normalized) {
                        cursor.close()
                        return
                    }
                }
                cursor.close()

                db.execSQL(
                    """
                    INSERT INTO captured_events
                    (source, text, package, sender, timestamp, captured_at)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """.trimIndent(),
                    arrayOf(
                        event["source"] as? String ?: "notification",
                        text,
                        event["package"] as? String,
                        event["sender"] as? String,
                        timestamp,
                        System.currentTimeMillis(),
                    ),
                )
                trimOldRows(db)
                db.setTransactionSuccessful()
                Log.d(TAG, "queued capture (${text.take(48)}…)")
                if (!IngestPlugin.isLiveIngestAttached()) {
                    BackgroundIngestRunner.schedule(context)
                }
            } finally {
                db.endTransaction()
                db.close()
            }
        } catch (e: Exception) {
            Log.e(TAG, "enqueue failed", e)
        }
    }

    private fun normalizeQueueText(text: String): String =
        text.replace("\\s+".toRegex(), " ").trim().lowercase()

    fun drain(context: Context): List<Map<String, Any?>> {
        return try {
            val db = QueueDb(context).writableDatabase
            db.beginTransaction()
            try {
                val cursor = db.rawQuery(
                    "SELECT source, text, package, sender, timestamp FROM captured_events ORDER BY id ASC",
                    null,
                )
                val out = ArrayList<Map<String, Any?>>(cursor.count.coerceAtLeast(0))
                while (cursor.moveToNext()) {
                    out.add(
                        mapOf(
                            "source" to cursor.getString(0),
                            "text" to cursor.getString(1),
                            "package" to cursor.getString(2),
                            "sender" to cursor.getString(3),
                            "timestamp" to cursor.getLong(4),
                        ),
                    )
                }
                cursor.close()
                db.execSQL("DELETE FROM captured_events")
                db.setTransactionSuccessful()
                Log.d(TAG, "drained ${out.size} queued capture(s)")
                out
            } finally {
                db.endTransaction()
                db.close()
            }
        } catch (e: Exception) {
            Log.e(TAG, "drain failed", e)
            emptyList()
        }
    }

    private fun trimOldRows(db: SQLiteDatabase) {
        val count = db.compileStatement("SELECT COUNT(*) FROM captured_events")
            .simpleQueryForLong()
        if (count <= MAX_ROWS) return
        val excess = count - MAX_ROWS
        db.execSQL(
            """
            DELETE FROM captured_events WHERE id IN (
                SELECT id FROM captured_events ORDER BY id ASC LIMIT ?
            )
            """.trimIndent(),
            arrayOf(excess),
        )
    }
}
