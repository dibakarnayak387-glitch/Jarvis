package com.starkindustries.jarvis

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.ContactsContract
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val channelName = "com.starkindustries.jarvis/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "openWhatsApp" -> {
                        val phone = call.argument<String>("phone") ?: ""
                        val message = call.argument<String>("message") ?: ""
                        result.success(openWhatsApp(phone, message))
                    }
                    "openWhatsAppForContact" -> {
                        val name = call.argument<String>("contactName") ?: ""
                        val message = call.argument<String>("message") ?: ""
                        result.success(openWhatsAppForContact(name, message))
                    }
                    "openAppPackage" -> {
                        result.success(openAppByPackage(call.argument<String>("packageName") ?: ""))
                    }
                    "openCamera" -> result.success(openCamera())
                    "openAppByName" -> result.success(openAppByName(call.argument<String>("name") ?: ""))
                    "getInstalledAppsList" -> result.success(getInstalledAppsList())
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("NATIVE_ERROR", e.message, null)
            }
        }
    }

    private fun openWhatsApp(phone: String, message: String): Boolean {
        return try {
            val intent = if (phone.isNotBlank()) {
                val clean = phone.replace("+", "").replace(" ", "").replace("-", "")
                Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/$clean?text=${Uri.encode(message)}"))
            } else {
                packageManager.getLaunchIntentForPackage("com.whatsapp") ?: return false
            }
            intent.setPackage(if (phone.isBlank()) "com.whatsapp" else "com.whatsapp")
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun openWhatsAppForContact(name: String, message: String): Map<String, Any> {
        val number = findContactNumber(name)
            ?: return mapOf("success" to false, "status" to "not_found")

        if (packageManager.getLaunchIntentForPackage("com.whatsapp") == null) {
            return mapOf("success" to false, "status" to "not_installed")
        }

        return try {
            val clean = number.filter { it.isDigit() || it == '+' }
            val uri = Uri.parse("https://wa.me/${clean.replace("+", "")}?text=${Uri.encode(message)}")
            val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                setPackage("com.whatsapp")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            mapOf("success" to true, "status" to "opened")
        } catch (_: Exception) {
            mapOf("success" to false, "status" to "error")
        }
    }

    private fun findContactNumber(contactName: String): String? {
        if (contactName.isBlank()) return null
        val resolver = contentResolver
        val projection = arrayOf(
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER
        )
        val selection = "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} LIKE ?"
        val args = arrayOf("%$contactName%")
        resolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            projection,
            selection,
            args,
            "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC"
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val numberIndex = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                if (numberIndex >= 0) return cursor.getString(numberIndex)
            }
        }
        return null
    }

    private fun openAppByPackage(packageName: String): Boolean {
        if (packageName.isBlank()) return false
        return try {
            val intent = packageManager.getLaunchIntentForPackage(packageName) ?: return false
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun openCamera(): Boolean {
        return try {
            val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
            if (intent.resolveActivity(packageManager) == null) return false
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun openAppByName(name: String): Boolean {
        val query = name.trim().lowercase(Locale.getDefault())
        if (query.isBlank() || query in setOf("open", "launch", "start", "chalao", "khol", "kholo")) return false

        val apps = getInstalledAppsList()
        val exact = apps.firstOrNull {
            it["name"]?.toString()?.lowercase(Locale.getDefault()) == query
        }
        val partial = apps.firstOrNull {
            val label = it["name"]?.toString()?.lowercase(Locale.getDefault()) ?: ""
            label.contains(query) || query.contains(label)
        }
        val target = exact ?: partial ?: return false
        return openAppByPackage(target["packageName"]?.toString() ?: "")
    }

    private fun getInstalledAppsList(): List<Map<String, String>> {
        val launcherIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val resolved = packageManager.queryIntentActivities(launcherIntent, 0)
        return resolved
            .mapNotNull { info ->
                val appInfo = info.activityInfo?.applicationInfo ?: return@mapNotNull null
                val name = appInfo.loadLabel(packageManager)?.toString()?.trim().orEmpty()
                val packageName = appInfo.packageName.orEmpty()
                if (name.isBlank() || packageName.isBlank()) null
                else mapOf("name" to name, "packageName" to packageName)
            }
            .distinctBy { it["packageName"] }
            .sortedBy { it["name"]?.lowercase(Locale.getDefault()) }
    }
}
