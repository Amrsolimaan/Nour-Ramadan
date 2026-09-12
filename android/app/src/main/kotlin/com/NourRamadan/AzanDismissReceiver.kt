package com.NourRamadan

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * AzanDismissReceiver — يُستدعى عند مسح إشعار الأذان (dismiss)
 * 
 * ✅ الوظيفة: إيقاف الأذان فوراً عند مسح المستخدم للإشعار
 * يرسل أمر ACTION_STOP إلى AzanForegroundService لإيقاف MediaPlayer
 */
class AzanDismissReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "AzanDismissReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "🗑️ Azan notification dismissed by user - stopping azan")
        
        // إيقاف AzanForegroundService عند مسح الإشعار
        val stopIntent = Intent(context, AzanForegroundService::class.java).apply {
            action = AzanForegroundService.ACTION_STOP
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(stopIntent)
        } else {
            context.startService(stopIntent)
        }
        
        Log.d(TAG, "✅ Stop command sent to AzanForegroundService")
    }
}