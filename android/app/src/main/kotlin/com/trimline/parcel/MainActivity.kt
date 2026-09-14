package com.trimline.parcel

import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.OutputStream

private const val APPLICATION_ID = "com.trimline.parcel"
const val ACTION_INSTALL_RESULT = "com.trimline.parcel.INSTALL_RESULT"
const val EXTRA_APK_PATH = "apkPath"

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.trimline.parcel/installer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        launchInstallPrompt(path)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARG", "Path is null", null)
                    }
                }
                "installApkSilent" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        installApkSilent(path, result)
                    } else {
                        result.error("INVALID_ARG", "Path is null", null)
                    }
                }
                "canInstallPackages" -> result.success(canInstallPackages())
                "openInstallSettings" -> {
                    openInstallSettings()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** True when this app is allowed to install packages (Android 8+). */
    private fun canInstallPackages(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()

    /** Sends the user to "Install unknown apps" for this app. */
    private fun openInstallSettings() {
        try {
            startActivity(
                Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                    data = Uri.parse("package:$APPLICATION_ID")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            )
        } catch (_: Exception) {
            try {
                startActivity(
                    Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                )
            } catch (_: Exception) {
            }
        }
    }

    /** Visible install prompt through the system package installer. */
    private fun launchInstallPrompt(filePath: String) {
        val file = File(filePath)
        if (!file.exists()) return
        try {
            val uri: Uri = FileProvider.getUriForFile(
                this, "${APPLICATION_ID}.fileprovider", file
            )
            startActivity(
                Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "application/vnd.android.package-archive")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            )
        } catch (_: Exception) {
            // Legacy installer package as a last resort
            try {
                val uri: Uri = FileProvider.getUriForFile(
                    this, "${APPLICATION_ID}.fileprovider", file
                )
                startActivity(
                    Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "application/vnd.android.package-archive")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        setPackage("com.android.packageinstaller")
                    }
                )
            } catch (_: Exception) {
            }
        }
    }

    /**
     * Silent install via PackageInstaller session. Resolves to true when the
     * install flow was started (session committed or system prompt shown), and
     * false when the user must first allow installs from this source.
     */
    private fun installApkSilent(filePath: String, result: MethodChannel.Result) {
        val file = File(filePath)
        if (!file.exists()) {
            result.success(false)
            return
        }

        if (!canInstallPackages()) {
            openInstallSettings()
            result.success(false)
            return
        }

        try {
            val installer = packageManager.packageInstaller
            val params = PackageInstaller.SessionParams(
                PackageInstaller.SessionParams.MODE_FULL_INSTALL
            )
            val sessionId = installer.createSession(params)

            installer.openSession(sessionId).use { session ->
                FileInputStream(file).use { input ->
                    session.openWrite("package", 0, file.length()).use { out: OutputStream ->
                        input.copyTo(out)
                    }
                }

                // Results go to InstallResultReceiver, which launches the system
                // confirmation prompt when the user must approve the install.
                val callback = Intent(this, InstallResultReceiver::class.java)
                    .setAction(ACTION_INSTALL_RESULT)
                    .putExtra(EXTRA_APK_PATH, filePath)

                val pendingIntent = PendingIntent.getBroadcast(
                    this, sessionId, callback,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                session.commit(pendingIntent.intentSender)
            }
            result.success(true)
        } catch (e: Exception) {
            // Session could not run — fall back to the visible prompt.
            launchInstallPrompt(filePath)
            result.success(true)
        }
    }
}

