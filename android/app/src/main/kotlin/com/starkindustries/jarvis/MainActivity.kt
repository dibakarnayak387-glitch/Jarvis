package com.starkindustries.jarvis

import android.content.Intent
import android.net.Uri
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
                "sendSms" -> {
                    val phone = call.argument<String>("phone") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    val success = sendSmsIntent(phone, message)
                    result.success(success)
                }
                "openYouTube" -> {
                    val query = call.argument<String>("query") ?: ""
                    val success = openYouTubeSearch(query)
                    result.success(success)
                }
                "openMap" -> {
                    val query = call.argument<String>("query") ?: ""
                    val success = openMapQuery(query)
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
            val url = if (phone.isNotEmpty()) {
                "https://api.whatsapp.com/send?phone=$phone&text=${Uri.encode(message)}"
            } else {
                "https://wa.me/?text=${Uri.encode(message)}"
            }
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun openWhatsAppIntent(phone: String, message: String): Boolean = openWhatsApp(phone, message)

    private fun sendSmsIntent(phone: String, message: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("sms:$phone")).apply {
                putExtra("sms_body", message)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun openYouTubeSearch(query: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_SEARCH).apply {
                setPackage("com.google.android.youtube")
                putExtra("query", query)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                startActivity(intent)
            } catch (e: Exception) {
                val webIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://www.youtube.com/results?search_query=${Uri.encode(query)}"))
                webIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(webIntent)
            }
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun openMapQuery(query: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("geo:0,0?q=${Uri.encode(query)}")).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
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
