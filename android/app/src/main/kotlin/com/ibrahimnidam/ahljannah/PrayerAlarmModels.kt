package com.ibrahimnidam.ahljannah

import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

data class PrayerAlarm(
    val id: Int,
    val triggerAtMillis: Long,
    val prayerKey: String,
    val kind: String,
    val title: String,
    val body: String,
    val sound: String,
    val group: String,
) {
    companion object {
        fun readAll(file: File): List<PrayerAlarm> {
            if (!file.exists()) return emptyList()
            val text = file.readText()
            if (text.isBlank()) return emptyList()
            return try {
                val array = JSONArray(text)
                val out = ArrayList<PrayerAlarm>(array.length())
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    out.add(
                        PrayerAlarm(
                            id = obj.optInt("id"),
                            triggerAtMillis = obj.optLong("triggerAtMillis"),
                            prayerKey = obj.optString("prayerKey"),
                            kind = obj.optString("kind", "adhan"),
                            title = obj.optString("title"),
                            body = obj.optString("body"),
                            sound = obj.optString("sound", "none"),
                            group = obj.optString("group", "prayer"),
                        ),
                    )
                }
                out
            } catch (e: Exception) {
                Log.e("PrayerAlarm", "Failed to parse ${file.absolutePath}", e)
                emptyList()
            }
        }
    }
}
