package com.assetheeper.asset_management

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    private val INSTALLER_CHANNEL = "com.assetheeper.asset_management/installer"
    private val NOTIFICATION_CHANNEL = "com.assetheeper.asset_management/notification"
    private var installResultReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALLER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val apkPath = call.arguments as? String
                    if (apkPath != null) {
                        installApk(apkPath, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "APK path is null", null)
                    }
                }
                "canRequestPackageInstalls" -> {
                    val canRequest = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        packageManager.canRequestPackageInstalls()
                    } else {
                        true
                    }
                    result.success(canRequest)
                }
                "openInstallUnknownAppsSettings" -> {
                    openInstallUnknownAppsSettings()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openNotificationSettings" -> {
                    openNotificationSettings()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun installApk(apkPath: String, result: MethodChannel.Result) {
        try {
            val file = File(apkPath)
            if (!file.exists()) {
                result.success(false)
                return
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                if (packageManager.canRequestPackageInstalls()) {
                    installWithPackageInstaller(apkPath, result)
                } else {
                    result.error("PERMISSION_DENIED", "Please grant install permission in settings", null)
                }
            } else {
                installWithIntent(apkPath, result)
            }
        } catch (e: Exception) {
            e.printStackTrace()
            result.success(false)
        }
    }

    private fun installWithPackageInstaller(apkPath: String, result: MethodChannel.Result) {
        try {
            val packageInstaller = packageManager.packageInstaller
            val sessionParams = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
            
            val sessionId = packageInstaller.createSession(sessionParams)
            val session = packageInstaller.openSession(sessionId)

            val outputStream = session.openWrite("base.apk", 0, File(apkPath).length())
            val fileInputStream = FileInputStream(File(apkPath))
            
            fileInputStream.use { input ->
                outputStream.use { output ->
                    input.copyTo(output)
                }
            }

            val intentSender = PendingIntent.getBroadcast(
                this,
                0,
                Intent(Intent.ACTION_VIEW),
                PendingIntent.FLAG_IMMUTABLE
            ).intentSender

            session.commit(intentSender)
            result.success(true)
        } catch (e: Exception) {
            e.printStackTrace()
            installWithIntent(apkPath, result)
        }
    }

    private fun installWithIntent(apkPath: String, result: MethodChannel.Result) {
        try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(Uri.fromFile(File(apkPath)), "application/vnd.android.package-archive")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            e.printStackTrace()
            result.success(false)
        }
    }

    private fun openInstallUnknownAppsSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                // 尝试直接跳转到应用特定的未知来源设置
                val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                    data = Uri.parse("package:$packageName")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(intent)
            } catch (e: Exception) {
                e.printStackTrace()
                // 如果失败，尝试跳转到应用信息页面
                try {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.parse("package:$packageName")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(intent)
                } catch (e2: Exception) {
                    e2.printStackTrace()
                    // 如果仍然失败，跳转到通用安全设置
                    val intent = Intent(Settings.ACTION_SECURITY_SETTINGS).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(intent)
                }
            }
        } else {
            val intent = Intent(Settings.ACTION_SECURITY_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
        }
    }

    private fun openNotificationSettings() {
        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
    }
}
