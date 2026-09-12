package com.NourRamadan

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

class AzanForegroundService : Service() {

    // ══════════════════════════════════════════════════════════════
    //  ✅ PHASE 4: MediaPlayer State Machine
    //  
    //  Prevents IllegalStateException by tracking player state
    //  Ensures operations only happen in valid states
    //  
    //  State Transitions:
    //  IDLE → PREPARING → STARTED → STOPPED → IDLE
    //                   ↓
    //                 ERROR → IDLE
    // ══════════════════════════════════════════════════════════════
    private enum class MediaPlayerState {
        IDLE,       // Initial state or after reset/release
        PREPARING,  // prepare() called, waiting for onPrepared
        STARTED,    // start() called, audio playing
        STOPPED,    // stop() called, can be prepared again
        ERROR       // Error occurred, needs reset
    }
    
    private var mediaPlayer: MediaPlayer? = null
    private var playerState: MediaPlayerState = MediaPlayerState.IDLE
    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var currentSoundFile: String = ""  // ✅ PHASE 1: Track current sound file

    // ══════════════════════════════════════════════════════════════
    //  ✅ PHASE 3: Enhanced Audio Focus Listener with Ducking
    //  ✅ PHASE 4: Improved with pause/resume instead of stop
    //  
    //  Handles all audio focus scenarios:
    //  1. LOSS: Permanent loss (incoming call) → Stop azan
    //  2. LOSS_TRANSIENT: Temporary loss (notification) → Pause azan
    //  3. LOSS_TRANSIENT_CAN_DUCK: Should lower volume → Duck volume
    //  4. GAIN: Focus regained → Resume or restore volume
    //  
    //  This ensures professional audio behavior on all devices
    // ══════════════════════════════════════════════════════════════
    private var isDucked = false  // Track if audio is currently ducked
    private var wasPausedTransiently = false  // Track if paused by transient loss
    
    private val audioFocusListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
        Log.d(TAG, "🎵 Audio focus change: $focusChange")
        
        when (focusChange) {
            // ── Permanent loss (incoming call, another alarm) ──────
            AudioManager.AUDIOFOCUS_LOSS -> {
                Log.d(TAG, "🔇 Audio focus LOSS — stopping azan (permanent)")
                stopAzan()
            }
            
            // ── Temporary loss (notification sound) ────────────────
            // ✅ PHASE 4: Pause instead of stop (can resume)
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                Log.d(TAG, "⏸️ Audio focus LOSS_TRANSIENT — pausing azan (temporary)")
                pauseAzan()
                wasPausedTransiently = true
            }
            
            // ── Should duck (lower volume for other audio) ─────────
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                Log.d(TAG, "🔉 Audio focus DUCK — lowering volume")
                try {
                    if (playerState == MediaPlayerState.STARTED) {
                        mediaPlayer?.setVolume(0.3f, 0.3f)
                        isDucked = true
                        Log.d(TAG, "✅ Volume ducked to 30%")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Failed to duck volume: ${e.message}")
                    // If ducking fails, stop azan to be safe
                    stopAzan()
                }
            }
            
            // ── Focus regained (restore normal volume or resume) ───
            AudioManager.AUDIOFOCUS_GAIN -> {
                Log.d(TAG, "🔊 Audio focus GAIN — restoring")
                try {
                    // If was ducked, restore volume
                    if (isDucked && playerState == MediaPlayerState.STARTED) {
                        mediaPlayer?.setVolume(1.0f, 1.0f)
                        isDucked = false
                        Log.d(TAG, "✅ Volume restored to 100%")
                    }
                    // If was paused transiently, resume
                    else if (wasPausedTransiently && playerState == MediaPlayerState.STOPPED) {
                        resumeAzan()
                        wasPausedTransiently = false
                        Log.d(TAG, "✅ Azan resumed after transient loss")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Failed to restore: ${e.message}")
                }
            }
        }
    }

    companion object {
        const val TAG = "AzanForegroundService"

        const val ACTION_PLAY = "PLAY_AZAN"
        const val ACTION_STOP = "STOP_AZAN"

        const val EXTRA_SOUND_FILE  = "sound_file"
        const val EXTRA_PRAYER_NAME = "prayer_name"

        const val CHANNEL_ID = "azan_foreground_channel"
        const val NOTIF_ID   = 9001
    }

    // ════════════════════════════════════════════════════════════
    //  onStartCommand
    // ════════════════════════════════════════════════════════════
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand: action=${intent?.action}")

        when (intent?.action) {
            ACTION_PLAY -> {
                val soundFile  = intent.getStringExtra(EXTRA_SOUND_FILE)  ?: return START_NOT_STICKY
                val prayerName = intent.getStringExtra(EXTRA_PRAYER_NAME) ?: "الصلاة"
                startAzan(soundFile, prayerName)
            }
            ACTION_STOP -> stopAzan()
        }
        return START_NOT_STICKY
    }

    // ════════════════════════════════════════════════════════════
    //  تشغيل الأذان
    // ════════════════════════════════════════════════════════════
    private fun startAzan(soundFile: String, prayerName: String) {
        Log.d(TAG, "startAzan: $soundFile / $prayerName")
        currentSoundFile = soundFile  // ✅ PHASE 1: Store for fullScreenIntent
        createNotificationChannel()
        startForegroundWithNotification(prayerName)
        requestAudioFocus()
        playSound(soundFile)
    }
    
    // ✅ PHASE 1: Helper to get current sound file
    private fun getCurrentSoundFile(): String = currentSoundFile

    // ── إشعار الـ ForegroundService مع أزرار القبلة والأدعية وتأكيد الصلاة ──
    private fun startForegroundWithNotification(prayerName: String) {

        // ✅ تحديد ما إذا كان هذا إشعار الشروق
        val isShurooq = prayerName.contains("شروق") || prayerName.contains("الشروق")
        
        // ✅ PHASE 1: Store soundFile for fullScreenIntent
        // We need to pass it to AdhanActivity via the intent
        val soundFile = getCurrentSoundFile()

        // ── زر التسبيح (للشروق فقط - يحل محل زر الإيقاف) ──
        val tasbihIntent = Intent(this, MainActivity::class.java).apply {
            action = "OPEN_TASBIH"
            flags  = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val tasbihPending = PendingIntent.getActivity(
            this, 16, tasbihIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ── زر الأذكار (للشروق فقط) ──
        val athkarIntent = Intent(this, MainActivity::class.java).apply {
            action = "OPEN_ATHKAR"
            flags  = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val athkarPending = PendingIntent.getActivity(
            this, 17, athkarIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ── زر القبلة (للصلوات الخمس فقط) ──
        val qiblaIntent = Intent(this, MainActivity::class.java).apply {
            action = "OPEN_QIBLA"
            flags  = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val qiblaPending = PendingIntent.getActivity(
            this, 10, qiblaIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ── زر تأكيد الصلاة (للصلوات الخمس فقط) ──
        val prayerConfirmIntent = Intent(this, MainActivity::class.java).apply {
            action = "OPEN_PRAYER_TIMES"
            flags  = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val prayerConfirmPending = PendingIntent.getActivity(
            this, 11, prayerConfirmIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ── زر الأدعية (للجميع) ──
        val duaIntent = Intent(this, MainActivity::class.java).apply {
            action = "OPEN_DUA"
            flags  = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val duaPending = PendingIntent.getActivity(
            this, 12, duaIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ── الضغط على الإشعار نفسه ──
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val openAppPending = PendingIntent.getActivity(
            this, 13, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ══════════════════════════════════════════════════════════
        //  ✅ PHASE 1 INJECTION: Full-Screen Intent
        //  
        //  CRITICAL: This is what makes the screen wake up
        //  Without this, notification shows but screen stays OFF
        //  
        //  How it works:
        //  1. Creates intent to launch AdhanActivity
        //  2. Attaches to notification as full-screen intent
        //  3. Android automatically launches activity when alarm fires
        //  4. Activity uses setTurnScreenOn() to wake screen
        //  
        //  Result: Screen turns ON and shows alarm UI
        // ══════════════════════════════════════════════════════════
        val fullScreenIntent = Intent(this, AdhanActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(AdhanActivity.EXTRA_PRAYER_NAME, prayerName)
            putExtra(AdhanActivity.EXTRA_SOUND_FILE, soundFile)
        }
        val fullScreenPending = PendingIntent.getActivity(
            this, 9999, fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ── زر إيقاف الأذان (للصلوات الخمس فقط) ──
        val stopIntent = Intent(this, AzanForegroundService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPending = PendingIntent.getService(
            this, 14, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ✅ CRITICAL FIX: استخدام BroadcastReceiver لضمان تشغيل العداد حتى عند مسح الإشعار
        val dismissIntent = Intent(this, AzanDismissReceiver::class.java)
        val dismissPending = PendingIntent.getBroadcast(
            this, 15, dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // ✅ تخصيص النص والأزرار حسب نوع الإشعار
        val notificationTitle = if (isShurooq) "وقت الشروق" else "أذان $prayerName"
        val notificationText = if (isShurooq) "انقضاء وقت الفجر" else "حان الآن وقت صلاة $prayerName"

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(notificationTitle)
            .setContentText(notificationText)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(false)
            .setAutoCancel(true)
            .setContentIntent(openAppPending)
            .setDeleteIntent(dismissPending)
            .setFullScreenIntent(fullScreenPending, true)  // ✅ PHASE 1: Screen wake injection

        // ✅ إضافة الأزرار حسب نوع الإشعار
        if (isShurooq) {
            // الشروق: تسبيح + أذكار + أدعية
            builder.addAction(0, "📿 التسبيح", tasbihPending)
            builder.addAction(0, "📿 الأذكار", athkarPending)
            builder.addAction(0, "🤲 أدعية", duaPending)
        } else {
            // الصلوات الخمس: إيقاف + قبلة + تأكيد + أدعية
            builder.addAction(0, "🛑 إيقاف الأذان", stopPending)
            builder.addAction(0, "🧭 القبلة", qiblaPending)
            builder.addAction(0, "✅ تأكيد الصلاة", prayerConfirmPending)
            builder.addAction(0, "🤲 أدعية", duaPending)
        }

        val notification = builder.build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIF_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTIF_ID, notification)
        }

        Log.d(TAG, "✅ Foreground started with notification")
    }

    // ════════════════════════════════════════════════════════════
    //  تشغيل الصوت
    //  ✅ PHASE 3: Enhanced error handling for OEM compatibility
    //  ✅ PHASE 4: State machine implementation
    // ════════════════════════════════════════════════════════════
    private fun playSound(soundFile: String) {
        try {
            // ── Clean up existing player ───────────────────────────
            releaseMediaPlayer()

            // ── Verify sound file exists ───────────────────────────
            val resId = resources.getIdentifier(soundFile, "raw", packageName)
            if (resId == 0) {
                Log.e(TAG, "❌ Sound file not found: $soundFile")
                stopAzan()
                return
            }

            // ── Create and configure MediaPlayer ───────────────────
            playerState = MediaPlayerState.IDLE
            
            mediaPlayer = MediaPlayer().apply {
                try {
                    // Set audio attributes
                    val attrs = AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                    setAudioAttributes(attrs)

                    // Load audio file
                    val afd = resources.openRawResourceFd(resId)
                    setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                    afd.close()

                    // Set listeners
                    setOnCompletionListener { 
                        Log.d(TAG, "✅ Azan playback completed")
                        playerState = MediaPlayerState.IDLE
                        stopAzan() 
                    }
                    
                    setOnErrorListener { _, what, extra ->
                        Log.e(TAG, "❌ MediaPlayer error: what=$what extra=$extra")
                        playerState = MediaPlayerState.ERROR
                        stopAzan()
                        true  // Return true to indicate error was handled
                    }
                    
                    setOnPreparedListener {
                        Log.d(TAG, "✅ MediaPlayer prepared")
                        playerState = MediaPlayerState.STARTED
                        start()
                        Log.d(TAG, "✅ Playing: $soundFile (duration: ${duration}ms)")
                    }

                    // Prepare asynchronously (state machine)
                    playerState = MediaPlayerState.PREPARING
                    prepareAsync()
                    
                } catch (e: Exception) {
                    Log.e(TAG, "❌ MediaPlayer setup error: ${e.message}", e)
                    playerState = MediaPlayerState.ERROR
                    throw e  // Re-throw to outer catch
                }
            }

        } catch (e: IllegalStateException) {
            Log.e(TAG, "❌ MediaPlayer IllegalStateException: ${e.message}", e)
            playerState = MediaPlayerState.ERROR
            stopAzan()
        } catch (e: IllegalArgumentException) {
            Log.e(TAG, "❌ MediaPlayer IllegalArgumentException: ${e.message}", e)
            playerState = MediaPlayerState.ERROR
            stopAzan()
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ MediaPlayer SecurityException (OEM restriction?): ${e.message}", e)
            playerState = MediaPlayerState.ERROR
            stopAzan()
        } catch (e: Exception) {
            Log.e(TAG, "❌ MediaPlayer unexpected error: ${e.message}", e)
            playerState = MediaPlayerState.ERROR
            stopAzan()
        }
    }
    
    // ════════════════════════════════════════════════════════════
    //  ✅ PHASE 4: Pause Azan (for transient audio focus loss)
    // ════════════════════════════════════════════════════════════
    private fun pauseAzan() {
        try {
            if (playerState == MediaPlayerState.STARTED) {
                mediaPlayer?.pause()
                playerState = MediaPlayerState.STOPPED
                Log.d(TAG, "⏸️ Azan paused")
            }
        } catch (e: IllegalStateException) {
            Log.e(TAG, "❌ Pause error (wrong state): ${e.message}")
            playerState = MediaPlayerState.ERROR
            stopAzan()
        } catch (e: Exception) {
            Log.e(TAG, "❌ Pause error: ${e.message}")
            stopAzan()
        }
    }
    
    // ════════════════════════════════════════════════════════════
    //  ✅ PHASE 4: Resume Azan (after transient audio focus loss)
    // ════════════════════════════════════════════════════════════
    private fun resumeAzan() {
        try {
            if (playerState == MediaPlayerState.STOPPED) {
                mediaPlayer?.start()
                playerState = MediaPlayerState.STARTED
                Log.d(TAG, "▶️ Azan resumed")
            }
        } catch (e: IllegalStateException) {
            Log.e(TAG, "❌ Resume error (wrong state): ${e.message}")
            playerState = MediaPlayerState.ERROR
            stopAzan()
        } catch (e: Exception) {
            Log.e(TAG, "❌ Resume error: ${e.message}")
            stopAzan()
        }
    }
    
    // ════════════════════════════════════════════════════════════
    //  ✅ PHASE 4: Safe MediaPlayer Release
    //  Handles all states safely
    // ════════════════════════════════════════════════════════════
    private fun releaseMediaPlayer() {
        try {
            mediaPlayer?.let { player ->
                // Stop if playing
                if (playerState == MediaPlayerState.STARTED) {
                    try {
                        player.stop()
                    } catch (e: IllegalStateException) {
                        Log.w(TAG, "⚠️ Stop failed (already stopped): ${e.message}")
                    }
                }
                
                // Reset to clear state
                try {
                    player.reset()
                } catch (e: IllegalStateException) {
                    Log.w(TAG, "⚠️ Reset failed: ${e.message}")
                }
                
                // Release resources
                player.release()
            }
            mediaPlayer = null
            playerState = MediaPlayerState.IDLE
            isDucked = false
            wasPausedTransiently = false
            Log.d(TAG, "✅ MediaPlayer released safely")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Release error: ${e.message}")
            mediaPlayer = null
            playerState = MediaPlayerState.IDLE
        }
    }

    // ════════════════════════════════════════════════════════════
    //  AudioFocus
    // ════════════════════════════════════════════════════════════
    private fun requestAudioFocus() {
        audioManager = getSystemService(AUDIO_SERVICE) as AudioManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                .setOnAudioFocusChangeListener(audioFocusListener) // ✅ FIX M6
                .setAcceptsDelayedFocusGain(false)                 // ✅ لا تأخير — الأذان فوري
                .build()
            audioFocusRequest = req
            audioManager?.requestAudioFocus(req)
        } else {
            @Suppress("DEPRECATION")
            // ✅ FIX M6: audioFocusListener بدلاً من null
            audioManager?.requestAudioFocus(
                audioFocusListener,
                AudioManager.STREAM_ALARM,
                AudioManager.AUDIOFOCUS_GAIN
            )
        }
    }

    private fun abandonAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let { audioManager?.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            // ✅ FIX M6: audioFocusListener بدلاً من null
            audioManager?.abandonAudioFocus(audioFocusListener)
        }
    }

    // ════════════════════════════════════════════════════════════
    //  إيقاف الأذان
    //  ✅ PHASE 3: Enhanced error handling
    //  ✅ PHASE 4: Uses safe release method
    // ════════════════════════════════════════════════════════════
    private fun stopAzan() {
        Log.d(TAG, "🛑 stopAzan")
        
        // ── Stop MediaPlayer (using safe release) ──────────────
        releaseMediaPlayer()

        // ── Abandon Audio Focus ────────────────────────────────
        try {
            abandonAudioFocus()
        } catch (e: Exception) {
            Log.e(TAG, "❌ Abandon audio focus error: ${e.message}")
        }

        // ── Stop Foreground Service ────────────────────────────
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            Log.d(TAG, "✅ Foreground service stopped")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Stop foreground error: ${e.message}")
        }
        
        // ── Stop Service ───────────────────────────────────────
        try {
            stopSelf()
        } catch (e: Exception) {
            Log.e(TAG, "❌ Stop self error: ${e.message}")
        }
    }

    // ════════════════════════════════════════════════════════════
    //  ✅ PHASE 4: تم تعطيل إعادة تشغيل العداد التنازلي
    //  لا حاجة له - الأذان يعمل مباشرة من AlarmManager
    // ════════════════════════════════════════════════════════════
    private fun restartCountdownAfterAzan() {
        Log.d(TAG, "⚠️ restartCountdownAfterAzan deprecated - countdown feature disabled")
    }

    // ════════════════════════════════════════════════════════════
    //  Notification Channel
    // ════════════════════════════════════════════════════════════
    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "أذان الصلاة",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "قناة تشغيل الأذان"
            setSound(null, null)
            enableVibration(false)
            setBypassDnd(true)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        try {
            releaseMediaPlayer()
        } catch (e: Exception) {
            Log.e(TAG, "onDestroy error: ${e.message}")
        }
    }
}