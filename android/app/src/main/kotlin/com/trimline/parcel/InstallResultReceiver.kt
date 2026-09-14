package com.trimline.parcel

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import androidx.core.content.FileProvider
import java.io.File

/**
 * Receives the PackageInstaller session result.
 *
 * - STATUS_PENDING_USER_ACTION: the system needs the user to confirm the install.
 *   We launch the installer intent it hands back (visible system prompt).
 * - any other failure: fall back to the classic ACTION_VIEW install prompt.
 */
class InstallResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_INSTALL_RESULT) return

        val status = intent.getIntExtra(
            PackageInstaller.EXTRA_STATUS,
            PackageInstaller.STATUS_FAILURE
        )

        if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
            @Suppress("DEPRECATION")
            val confirm = intent.getParcelableExtra(Intent.EXTRA_INTENT) as? Intent
            if (confirm != null) {
                try {
                    confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(confirm)
                    return
                } catch (_: Exception) {
                    // fall through to the generic prompt
                }
            }
        } else if (status == PackageInstaller.STATUS_SUCCESS) {
            // Installed — the system replaces/restarts the app.
            return
        }

        fallbackPrompt(context, intent.getStringExtra(EXTRA_APK_PATH))
    }

    private fun fallbackPrompt(context: Context, apkPath: String?) {
        if (apkPath.isNullOrEmpty()) return
        val file = File(apkPath)
        if (!file.exists()) return
        try {
            val uri: Uri = FileProvider.getUriForFile(
                context, "${context.packageName}.fileprovider", file
            )
            val install = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(install)
        } catch (_: Exception) {
            // Nothing more we can do from the receiver.
        }
    }
}
