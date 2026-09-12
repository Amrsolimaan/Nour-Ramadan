package com.NourRamadan

import android.app.KeyguardManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.util.Log
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

/**
 * AdhanActivity - Full-Screen Alarm UI
 * 
 * PHASE 5 GLOBAL: Universal OEM Protection
 * Purpose: Display full-screen alarm UI when device is locked
 * Wakes screen and shows over lockscreen (Android 10+)
 * BINDS to AzanForegroundService to prevent OEM kills
 * Solid theme (not transparent) for maximum reliability
 * 
 * Architecture:
 * - Launched by AzanAlarmReceiver when alarm fires
 * - Triggered via setFullScreenIntent from AzanForegroundService notification
 * - BINDS to service to prevent Vivo/Xiaomi/Oppo kills
 * - Works alongside existing audio playback (doesn't replace it)
 * - Respects existing WakeLock management
 * 
 * Android Compatibility:
 * - Android 10+ (API 29+): Uses setShowWhenLocked + setTurnScreenOn
 * - Android 8-9 (API 26-28): Uses window flags
 * - Handles both locked and unlocked states
 * 
 * OEM Compatibility:
 * - Vivo/Xiaomi/Oppo: Service binding prevents activity kill
 * - Huawei/Honor: Solid theme prevents transparent activity issues
 * - Samsung/OnePlus: Standard implementation works reliably
 * 
 * UI Design:
 * - Matches app's color palette (nightDeep, goldWarm, goldLight)
 * - Uses app's fonts (Tajawal, NotoNaskhArabic)
 * - Static design (no animations) for reliability
 * - Prominent dismiss button for easy interaction
 */
class AdhanActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "AdhanActivity"
        const val EXTRA_PRAYER_NAME = "prayer_name"
        const val EXTRA_SOUND_FILE = "sound_file"
    }
    
    // PHASE 5 GLOBAL: Service Binding for OEM Protection
    // Binding to AzanForegroundService prevents aggressive OEMs
    // (Vivo/Xiaomi/Oppo) from killing this activity during Doze
    // The service keeps the activity alive through the binding
    private var serviceBound = false
    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            serviceBound = true
            Log.d(TAG, "Bound to AzanForegroundService (OEM protection active)")
        }
        
        override fun onServiceDisconnected(name: ComponentName?) {
            serviceBound = false
            Log.w(TAG, "Unbound from AzanForegroundService")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        Log.d(TAG, "AdhanActivity created")
        
        // CRITICAL: Screen Wake & Lockscreen Display
        // This is the PRIMARY PURPOSE of this Activity
        setupLockscreenDisplay()
        
        // Extract alarm data from intent
        val prayerName = intent?.getStringExtra(EXTRA_PRAYER_NAME) ?: "الصلاة"
        val soundFile = intent?.getStringExtra(EXTRA_SOUND_FILE) ?: ""
        
        Log.d(TAG, "Prayer: $prayerName | Sound: $soundFile")
        
        // PHASE 5 GLOBAL: Bind to Service (Universal OEM Fix)
        // Binding to AzanForegroundService prevents OEM kills on:
        // - Vivo V23, V25, V27 (aggressive background restrictions)
        // - Xiaomi 12, 13, 14 (MIUI battery optimization)
        // - Oppo Find X5, Reno series (ColorOS restrictions)
        // - Realme (same as Oppo)
        // The service binding keeps this activity alive even when
        // the device enters Doze Mode or OEM kills background tasks
        bindToAzanService()
        
        // PHASE 5 GLOBAL: Professional UI Setup
        // Load custom layout and bind UI elements
        setupUI(prayerName)
        
        // Integration with existing architecture
        // WakeLock is already acquired by AzanAlarmReceiver
        // Audio is already playing via AzanForegroundService
        // This Activity provides the visual wake-up + UI
        Log.d(TAG, "AdhanActivity ready - screen should be ON")
    }
    
    /**
     * PHASE 5 GLOBAL: Bind to AzanForegroundService
     * 
     * Creates a service binding that prevents OEM task killers
     * from terminating this activity during alarm display
     * 
     * This is the UNIVERSAL FIX for all aggressive OEMs
     */
    private fun bindToAzanService() {
        try {
            val serviceIntent = Intent(this, AzanForegroundService::class.java)
            val bound = bindService(
                serviceIntent,
                serviceConnection,
                Context.BIND_AUTO_CREATE or Context.BIND_IMPORTANT
            )
            
            if (bound) {
                Log.d(TAG, "Service binding initiated (OEM protection)")
            } else {
                Log.w(TAG, "Service binding failed - activity may be killed on aggressive OEMs")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to bind to service: ${e.message}")
        }
    }
    
    /**
     * Setup lockscreen display and screen wake
     * 
     * This method handles the critical Android APIs to:
     * 1. Turn screen ON from sleep
     * 2. Show activity OVER lockscreen
     * 3. Keep screen ON while activity is visible
     * 
     * Uses different APIs based on Android version for maximum compatibility
     */
    private fun setupLockscreenDisplay() {
        // Android 10+ (API 27+) Modern Approach
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            
            // Request to show over keyguard (lockscreen)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
            
            Log.d(TAG, "Modern lockscreen flags set (API ${Build.VERSION.SDK_INT})")
        }
        // Android 8-9 (API 26-27) Legacy Approach
        else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
            
            Log.d(TAG, "Legacy lockscreen flags set (API ${Build.VERSION.SDK_INT})")
        }
        
        // Keep Screen ON (All Versions)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        Log.d(TAG, "Screen wake flags applied")
    }
    
    /**
     * PHASE 4: Setup Professional UI
     * 
     * Loads custom layout (activity_adhan.xml) and binds UI elements
     * Matches app's visual identity from loading_screen.dart
     * 
     * UI Elements:
     * - Prayer name (dynamic, large, gold)
     * - Dismiss button (prominent, gold gradient)
     * - Crescent moon icon
     * - App branding
     */
    private fun setupUI(prayerName: String) {
        try {
            // Load custom layout
            setContentView(R.layout.activity_adhan)
            
            // Bind UI elements
            val textPrayerName = findViewById<TextView>(R.id.text_prayer_name)
            val btnDismiss = findViewById<Button>(R.id.btn_dismiss)
            
            // Set prayer name
            textPrayerName?.text = prayerName
            
            // Setup dismiss button
            btnDismiss?.setOnClickListener {
                Log.d(TAG, "Dismiss button clicked")
                stopAlarmAndFinish()
            }
            
            Log.d(TAG, "Professional UI loaded for: $prayerName")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to setup UI: ${e.message}")
            // Fallback: Activity still works without UI (transparent)
            // This ensures alarm still wakes screen even if UI fails
        }
    }
    
    /**
     * Handle back button press
     * 
     * When user presses back, we want to:
     * 1. Stop the alarm (via AzanForegroundService)
     * 2. Close this activity
     * 3. Return to home screen or lockscreen
     */
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        Log.d(TAG, "Back pressed - stopping alarm")
        @Suppress("DEPRECATION")
        super.onBackPressed()
        stopAlarmAndFinish()
    }
    
    /**
     * Stop alarm and close activity
     * 
     * Sends stop command to AzanForegroundService
     * Then finishes this activity
     */
    private fun stopAlarmAndFinish() {
        try {
            // Send stop command to AzanForegroundService
            val stopIntent = Intent(this, AzanForegroundService::class.java)
            stopIntent.action = AzanForegroundService.ACTION_STOP
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(stopIntent)
            } else {
                startService(stopIntent)
            }
            
            Log.d(TAG, "Stop command sent to AzanForegroundService")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop alarm: ${e.message}")
        }
        
        // Close this activity
        finish()
    }
    
    /**
     * Activity lifecycle: onDestroy
     * 
     * Clean up when activity is destroyed
     * WakeLock is managed by WakeLockHelper (already in architecture)
     */
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "AdhanActivity destroyed")
        
        // PHASE 5 GLOBAL: Unbind from Service
        // Clean up service binding to prevent memory leaks
        try {
            if (serviceBound) {
                unbindService(serviceConnection)
                serviceBound = false
                Log.d(TAG, "Unbound from AzanForegroundService")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to unbind service: ${e.message}")
        }
        
        // WakeLock cleanup is handled by WakeLockHelper
        // No need to duplicate that logic here
    }
}
