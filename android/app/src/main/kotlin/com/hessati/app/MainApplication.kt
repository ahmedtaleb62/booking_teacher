package com.hessati.app

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.graphics.Color
import android.os.Build

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel("hajez_ustad_channel") == null) {
                val channel = NotificationChannel(
                    "hajez_ustad_channel",
                    "إشعارات حصتي",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "إشعارات التطبيق"
                    enableVibration(true)
                    enableLights(true)
                    lightColor = Color.parseColor("#4F46E5")
                }
                manager.createNotificationChannel(channel)
            }
        }
    }
}
