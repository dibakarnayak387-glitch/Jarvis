package com.starkindustries.jarvis

import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.starkindustries.jarvis/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    startJarvisService()
                    result.success(true)
                }
                "openWhatsApp" -> {
                    val phone = call.argument<String>("phone") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    val success = openWhatsAppIntent(phone, message)
                    result.success(success)
                }
                "openAppPackage" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    val success = openAppByPackageName(packageName)
                    result.success(success)
                }
                "getInstalledAppsList" -> {
                    val appsList = getInstalledAppsList()
                    result.success(appsList)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun startJarvisService() {
        val intent = Intent(this, JarvisService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun openWhatsApp(phone: String, message: String): Boolean {
        return try {
            val intent = if (phone.isNotEmpty()) {
                Intent(Intent.ACTION_VIEW, android.net.Uri.parse("https://api.whatsapp.com/send?phone=$phone&text=${android.net.Uri.encode(message)}"))
            } else {
                packageManager.getLaunchIntentForPackage("com.whatsapp") ?: return false
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun openWhatsAppIntent(phone: String, message: String): Boolean {
        return openWhatsApp(phone, message)
    }

    private fun openAppByPackageName(packageName: String): Boolean {
        return try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun getInstalledAppsList(): List<Map<String, String>> {
        val appsList = mutableListOf<Map<String, String>>()
        try {
            val packages = packageManager.getInstalledPackages(0)
            for (pkg in packages) {
                val appName = pkg.applicationInfo?.loadLabel(packageManager)?.toString() ?: continue
                val packageName = pkg.packageName ?: continue
                val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                if (launchIntent != null) {
                    appsList.add(mapOf("name" to appName, "packageName" to packageName))
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return appsList
    }
}
