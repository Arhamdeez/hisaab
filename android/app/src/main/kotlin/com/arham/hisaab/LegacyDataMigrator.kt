package com.arham.hisaab

import android.content.Context
import android.content.pm.PackageManager
import java.io.File

/**
 * One-time copy of on-device data from the original dev package id
 * (`com.example.spend_tracker`) to the production id (`com.arham.hisaab`).
 *
 * Android sandboxes each package — a normal update cannot read the old folder.
 * When the legacy app is still installed and the OS allows it, we copy the
 * SQLite database and Flutter SharedPreferences before Flutter starts.
 */
object LegacyDataMigrator {
    private const val TAG = "LegacyDataMigrator"
    const val LEGACY_PACKAGE = "com.example.spend_tracker"
    private const val MIGRATION_PREFS = "hisaab_legacy_migration"
    private const val KEY_ATTEMPTED = "legacy_package_v1_attempted"
    private const val KEY_SUCCEEDED = "legacy_package_v1_succeeded"
    private const val DB_NAME = "spend_tracker.sqlite"
    private const val FLUTTER_PREFS = "FlutterSharedPreferences.xml"

    data class Result(
        val status: String,
        val legacyInstalled: Boolean = false,
        val bytesCopied: Long = 0,
        val message: String? = null,
    ) {
        fun toMap(): Map<String, Any?> = mapOf(
            "status" to status,
            "legacyInstalled" to legacyInstalled,
            "bytesCopied" to bytesCopied,
            "message" to message,
        )
    }

    @Volatile
    private var lastResult: Result? = null

    fun lastMigrationResult(): Result? = lastResult

    fun migrateIfNeeded(context: Context): Result {
        lastResult?.let { return it }

        val appContext = context.applicationContext
        val prefs = appContext.getSharedPreferences(MIGRATION_PREFS, Context.MODE_PRIVATE)
        if (prefs.getBoolean(KEY_SUCCEEDED, false)) {
            return Result("already_migrated").also { lastResult = it }
        }

        val legacyInstalled = isPackageInstalled(appContext, LEGACY_PACKAGE)
        val targetDb = flutterDbFile(appContext)

        if (targetDb.exists() && targetDb.length() > 512) {
            prefs.edit()
                .putBoolean(KEY_ATTEMPTED, true)
                .putBoolean(KEY_SUCCEEDED, true)
                .apply()
            return Result(
                status = "target_has_data",
                legacyInstalled = legacyInstalled,
                message = "Current app already has a database",
            ).also { lastResult = it }
        }

        val legacyDb = resolveLegacyDbFile(appContext)
        if (legacyDb == null || !legacyDb.exists() || legacyDb.length() < 64) {
            prefs.edit().putBoolean(KEY_ATTEMPTED, true).apply()
            return Result(
                status = if (legacyInstalled) "legacy_locked" else "legacy_not_found",
                legacyInstalled = legacyInstalled,
                message = if (legacyInstalled) {
                    "Old HISAAB is installed but its data could not be read automatically. " +
                        "Open the old app and export a backup, or restore a .sqlite file in Settings."
                } else {
                    "No data found from the previous app install (com.example.spend_tracker)."
                },
            ).also { lastResult = it }
        }

        return try {
            targetDb.parentFile?.mkdirs()
            legacyDb.copyTo(targetDb, overwrite = false)
            copyLegacyFlutterPrefs(appContext)
            prefs.edit()
                .putBoolean(KEY_ATTEMPTED, true)
                .putBoolean(KEY_SUCCEEDED, true)
                .apply()
            PrivacyLog.i(TAG, "migrated ${legacyDb.length()} bytes from $LEGACY_PACKAGE")
            Result(
                status = "migrated",
                legacyInstalled = legacyInstalled,
                bytesCopied = legacyDb.length(),
            ).also { lastResult = it }
        } catch (e: Exception) {
            prefs.edit().putBoolean(KEY_ATTEMPTED, true).apply()
            PrivacyLog.w(TAG, "legacy migration failed", e)
            Result(
                status = "failed",
                legacyInstalled = legacyInstalled,
                message = e.message,
            ).also { lastResult = it }
        }
    }

    private fun resolveLegacyDbFile(context: Context): File? {
        if (isPackageInstalled(context, LEGACY_PACKAGE)) {
            try {
                val legacyCtx = context.createPackageContext(
                    LEGACY_PACKAGE,
                    Context.CONTEXT_IGNORE_SECURITY,
                )
                val db = File(File(legacyCtx.applicationInfo.dataDir, "app_flutter"), DB_NAME)
                if (db.exists() && db.canRead()) return db
            } catch (e: Exception) {
                PrivacyLog.w(TAG, "createPackageContext db read failed", e)
            }
        }

        val direct = File("/data/data/$LEGACY_PACKAGE/app_flutter/$DB_NAME")
        return if (direct.exists() && direct.canRead()) direct else null
    }

    private fun copyLegacyFlutterPrefs(context: Context) {
        val targetPrefs = File(
            File(context.applicationInfo.dataDir, "shared_prefs"),
            FLUTTER_PREFS,
        )
        if (targetPrefs.exists() && targetPrefs.length() > 32) return

        val legacyPrefs = resolveLegacyPrefsFile(context) ?: return
        targetPrefs.parentFile?.mkdirs()
        legacyPrefs.copyTo(targetPrefs, overwrite = true)
        PrivacyLog.d(TAG, "copied FlutterSharedPreferences from legacy package")
    }

    private fun resolveLegacyPrefsFile(context: Context): File? {
        if (isPackageInstalled(context, LEGACY_PACKAGE)) {
            try {
                val legacyCtx = context.createPackageContext(
                    LEGACY_PACKAGE,
                    Context.CONTEXT_IGNORE_SECURITY,
                )
                val prefs = File(
                    File(legacyCtx.applicationInfo.dataDir, "shared_prefs"),
                    FLUTTER_PREFS,
                )
                if (prefs.exists() && prefs.canRead()) return prefs
            } catch (e: Exception) {
                PrivacyLog.w(TAG, "createPackageContext prefs read failed", e)
            }
        }

        val direct = File(
            "/data/data/$LEGACY_PACKAGE/shared_prefs/$FLUTTER_PREFS",
        )
        return if (direct.exists() && direct.canRead()) direct else null
    }

    private fun flutterDbFile(context: Context): File =
        File(File(context.applicationInfo.dataDir, "app_flutter"), DB_NAME)

    private fun isPackageInstalled(context: Context, packageName: String): Boolean {
        return try {
            context.packageManager.getPackageInfo(packageName, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }
}
