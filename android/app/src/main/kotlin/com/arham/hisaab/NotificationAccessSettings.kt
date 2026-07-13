package com.arham.hisaab

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings

/**
 * Opens the OS screen where the user grants notification-listener access.
 *
 * Tries standard Android intents first, then OEM-specific routes (Samsung, Xiaomi,
 * Oppo/ColorOS, Huawei, OnePlus), and falls back to this app's system settings page.
 */
object NotificationAccessSettings {
    data class OpenResult(
        val opened: Boolean,
        val via: String? = null,
        val manufacturer: String = Build.MANUFACTURER,
        val model: String = Build.MODEL,
        val sdkInt: Int = Build.VERSION.SDK_INT,
    ) {
        fun toMap(): Map<String, Any?> = mapOf(
            "opened" to opened,
            "via" to via,
            "manufacturer" to manufacturer,
            "model" to model,
            "sdkInt" to sdkInt,
        )
    }

    fun open(context: Context): OpenResult {
        val launchContext = resolveLaunchContext(context)
        val packageName = context.packageName
        val listenerComponent = ComponentName(context, NotificationCaptureService::class.java)
        val flattened = listenerComponent.flattenToString()
        val manufacturer = Build.MANUFACTURER.orEmpty().lowercase()
        val pm = context.packageManager

        val candidates = buildList {
            // --- Standard Android (best for Play Store / Pixel / most devices) ---
            add(
                labeled("ACTION_NOTIFICATION_LISTENER_SETTINGS") {
                    Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                },
            )
            add(
                labeled("NOTIFICATION_LISTENER_DETAIL") {
                    Intent("android.settings.NOTIFICATION_LISTENER_DETAIL_SETTINGS").apply {
                        putExtra(":settings:fragment_args_key", flattened)
                        putExtra(":settings:show_fragment_args", flattened)
                    }
                },
            )

            // Pin to the system Settings package when multiple handlers exist.
            for (settingsPkg in settingsPackages(manufacturer)) {
                add(
                    labeled("NOTIFICATION_LISTENER@$settingsPkg") {
                        Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                            setPackage(settingsPkg)
                        }
                    },
                )
            }

            // --- AOSP explicit activity (works on some stock builds) ---
            add(
                labeled("AOSP_NOTIFICATION_ACCESS_ACTIVITY") {
                    Intent().setComponent(
                        ComponentName(
                            "com.android.settings",
                            "com.android.settings.Settings\$NotificationAccessSettingsActivity",
                        ),
                    )
                },
            )

            // --- Samsung One UI (SM-S931U1 and similar) ---
            if (manufacturer.contains("samsung")) {
                addAll(samsungIntents(flattened, packageName))
            }

            // --- Xiaomi / Redmi / POCO (MIUI / HyperOS) ---
            if (manufacturer.contains("xiaomi") ||
                manufacturer.contains("redmi") ||
                manufacturer.contains("poco")
            ) {
                addAll(xiaomiIntents(packageName))
            }

            // --- Oppo / Realme / OnePlus (ColorOS / OxygenOS variants) ---
            if (manufacturer.contains("oppo") ||
                manufacturer.contains("realme") ||
                manufacturer.contains("oneplus")
            ) {
                addAll(colorOsIntents(packageName))
            }

            // --- Huawei / Honor ---
            if (manufacturer.contains("huawei") || manufacturer.contains("honor")) {
                addAll(huaweiIntents(packageName))
            }

            // --- Fallbacks: app info → general settings ---
            add(
                labeled("APPLICATION_DETAILS") {
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.fromParts("package", packageName, null)
                    }
                },
            )
            add(
                labeled("ACTION_SETTINGS") {
                    Intent(Settings.ACTION_SETTINGS)
                },
            )
        }

        for ((label, intent) in candidates) {
            if (!canResolve(pm, intent)) continue
            if (startActivity(launchContext, intent)) {
                PrivacyLog.d(
                    INGEST_TAG,
                    "notification access opened via $label (manufacturer=$manufacturer)",
                )
                return OpenResult(opened = true, via = label)
            }
        }

        PrivacyLog.w(
            INGEST_TAG,
            "notification access settings could not be opened " +
                "(manufacturer=$manufacturer model=${Build.MODEL} sdk=${Build.VERSION.SDK_INT})",
        )
        return OpenResult(opened = false)
    }

    private fun resolveLaunchContext(context: Context): Context {
        if (context is Activity) return context
        ForegroundActivity.activity?.let { return it }
        return context
    }

    private fun settingsPackages(manufacturer: String): List<String> {
        val packages = linkedSetOf("com.android.settings")
        if (manufacturer.contains("samsung")) {
            packages.add("com.samsung.android.settings")
        }
        return packages.toList()
    }

    private fun samsungIntents(flattened: String, packageName: String): List<LabeledIntent> =
        listOf(
            labeled("SAMSUNG_NOTIFICATION_LISTENER") {
                Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
            },
            labeled("SAMSUNG_NOTIFICATION_LISTENER_SETTINGS_PKG") {
                Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                    setPackage("com.android.settings")
                }
            },
            labeled("SAMSUNG_NOTIFICATION_LISTENER_DETAIL") {
                Intent("android.settings.NOTIFICATION_LISTENER_DETAIL_SETTINGS").apply {
                    putExtra(":settings:fragment_args_key", flattened)
                    putExtra(":settings:show_fragment_args", flattened)
                    setPackage("com.android.settings")
                }
            },
            labeled("SAMSUNG_APP_DETAILS") {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.fromParts("package", packageName, null)
                    setPackage("com.android.settings")
                }
            },
        )

    private fun xiaomiIntents(packageName: String): List<LabeledIntent> =
        listOf(
            labeled("MIUI_PERMISSION_EDITOR") {
                Intent("miui.intent.action.APP_PERM_EDITOR").apply {
                    putExtra("extra_pkgname", packageName)
                }
            },
            labeled("MIUI_SECURITY_CENTER") {
                Intent().setClassName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.permissions.PermissionsEditorActivity",
                ).apply {
                    putExtra("extra_pkgname", packageName)
                }
            },
        )

    private fun colorOsIntents(packageName: String): List<LabeledIntent> =
        listOf(
            labeled("COLOROS_SAFE_CENTER") {
                Intent().setClassName(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.permission.PermissionManagerActivity",
                )
            },
            labeled("OPPO_SAFE_CENTER") {
                Intent().setClassName(
                    "com.oplus.safecenter",
                    "com.oplus.safecenter.permission.PermissionManagerActivity",
                )
            },
            labeled("ONEPLUS_SECURITY") {
                Intent().setClassName(
                    "com.oneplus.security",
                    "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
                ).apply {
                    putExtra("packageName", packageName)
                }
            },
        )

    private fun huaweiIntents(packageName: String): List<LabeledIntent> =
        listOf(
            labeled("HUAWEI_SYSTEM_MANAGER") {
                Intent().setClassName(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
                ).apply {
                    putExtra("packageName", packageName)
                }
            },
        )

    private data class LabeledIntent(val label: String, val intent: Intent)

    private fun labeled(label: String, builder: () -> Intent): LabeledIntent =
        LabeledIntent(label, builder())

    private fun canResolve(pm: PackageManager, intent: Intent): Boolean {
        return pm.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY) != null
    }

    private fun startActivity(context: Context, intent: Intent): Boolean {
        return try {
            intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            if (context !is Activity) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            PrivacyLog.w(INGEST_TAG, "ActivityNotFound for ${intent.action}", e)
            false
        } catch (e: SecurityException) {
            PrivacyLog.w(INGEST_TAG, "SecurityException for ${intent.action}", e)
            false
        } catch (e: Exception) {
            PrivacyLog.w(INGEST_TAG, "startActivity failed for ${intent.action}", e)
            false
        }
    }
}

private const val INGEST_TAG = "HisaabIngest"
