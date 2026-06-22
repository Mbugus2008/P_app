package com.trimline.parcel

import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.OutputStream

private const val APPLICATION_ID = "com.trimline.parcel"

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
                        installApk(path)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARG", "Path is null", null)
                    }
                }
                "installApkSilent" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        installApkSilent(path)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARG", "Path is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Standard install — opens system package installer */
    private fun installApk(filePath: String) {
        val file = File(filePath)
        val uri: Uri = FileProvider.getUriForFile(
            this, "${APPLICATION_ID}.fileprovider", file
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
    }

    /** Silent install using PackageInstaller Session API */
    private fun installApkSilent(filePath: String) {
        try {
            val file = File(filePath)
            val installer = packageManager.packageInstaller
            val params = PackageInstaller.SessionParams(
                PackageInstaller.SessionParams.MODE_FULL_INSTALL
            )
            val sessionId = installer.createSession(params)
            val session = installer.openSession(sessionId)

            // Copy APK to session
            FileInputStream(file).use { input ->
                session.openWrite("package", 0, file.length()).use { out: OutputStream ->
                    input.copyTo(out)
                }
            }

            // Commit — triggers system install prompt
            val intent = Intent(Intent.ACTION_VIEW).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            val pendingIntent = PendingIntent.getActivity(
                this, sessionId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            session.commit(pendingIntent.intentSender)
            session.close()
        } catch (e: Exception) {
            // Fallback to standard install
            installApk(filePath)
        }
    }
}

