package com.NourRamadan

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val NOTIFICATION_CHANNEL = "com.nour_ramadan/notification_actions"
    private val AZAN_CHANNEL         = "com.nour_ramadan/azan_service"

    private var pendingRescheduleRequest: Boolean = false
    private var notificationMethodChannel: MethodChannel? = null

    // ── Handler لتأخير الإرسال حتى يكون Flutter جاهزاً ──────────
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        flutterEngine.plugins.add(AzanPlugin())

        notificationMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NOTIFICATION_CHANNEL
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                Log.d("MainActivity", "NotificationChannel: ${call.method}")
                when (call.method) {
                    "onNotificationAction" -> {
                        val actionId = call.arguments as? String ?: ""
                        sendActionToFlutter(actionId)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        if (pendingRescheduleRequest) {
            Log.d("MainActivity", "� Processing pending reschedule")
            mainHandler.postDelayed({
                MethodChannel(
                    flutterEngine.dartExecutor.binaryMessenger,
                    AZAN_CHANNEL
                ).invokeMethod("rescheduleFromTimeChange", null)
            }, 500L)
            pendingRescheduleRequest = false
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("MainActivity", "onCreate - intent: ${intent?.extras?.keySet()}")
        extractAndSavePendingAction(intent)
        handleRescheduleIntent(intent)

        // ✅ PHASE 1 FIX: تسجيل نبضة AzanWorker عند فتح التطبيق
        // السبب: النبضة كانت تُسجّل فقط من المستقبلات (إقلاع/أذان)
        // فإذا لم يحدث أي منهما لا توجد أي استمرارية
        try {
            AzanWorker.schedule(this)
            Log.d("MainActivity", "✅ AzanWorker heartbeat scheduled at app start")
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ Failed to schedule AzanWorker: ${e.message}")
        }

        // ✅ PHASE 2 FIX: الحساب الذاتي فور فتح التطبيق
        // Kotlin يحسب 7 أيام كاملة ويجدول النافذة المنزلقة بنفسه
        try {
            AlarmScheduler.refresh(this)
            Log.d("MainActivity", "✅ AlarmScheduler.refresh() at app start")
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ AlarmScheduler.refresh() failed: ${e.message}")
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d("MainActivity", "onNewIntent - navigate_to: ${intent.getStringExtra("navigate_to")}")
        setIntent(intent)
        handleIntent(intent)
        handleRescheduleIntent(intent)
    }

    private fun handleRescheduleIntent(intent: Intent?) {
        if (intent?.action != "RESCHEDULE_NOTIFICATIONS") return
        Log.d("MainActivity", "🔄 Reschedule intent received (time change detected)")

        val engine = flutterEngine
        if (engine == null) {
            pendingRescheduleRequest = true
            Log.d("MainActivity", "⏳ Flutter engine not ready - will reschedule when ready")
            return
        }

        try {
            MethodChannel(
                engine.dartExecutor.binaryMessenger,
                AZAN_CHANNEL
            ).invokeMethod("rescheduleFromTimeChange", null)
            Log.d("MainActivity", "✅ Reschedule signal sent to Flutter")
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ Reschedule failed: ${e.message}")
        }
    }

    private fun extractAndSavePendingAction(intent: Intent?) {
        if (intent == null) return

        Log.d("MainActivity", "🔍 DEBUG: extractAndSavePendingAction called")
        
        val navigateTo = intent.getStringExtra("navigate_to")
        if (navigateTo != null && navigateTo != "main") {
            savePendingNavigationToPrefs(navigateTo)
            Log.d("MainActivity", "💾 navigate_to saved: $navigateTo")
            return
        }

        val action = intent.action ?: return
        Log.d("MainActivity", "🔍 DEBUG: intent.action = $action")
        
        val mappedAction = when {
            action == "OPEN_ATHKAR"       -> "open_athkar"
            action == "OPEN_DUA"          -> "open_dua"
            action == "OPEN_QIBLA"        -> "open_qibla"
            action == "OPEN_PRAYER_TIMES" -> "open_prayer_times"
            action == "OPEN_TASBIH"       -> "open_tasbih"
            action.startsWith("NOTIFICATION_ACTION_") ->
                action.replace("NOTIFICATION_ACTION_", "").lowercase()
            else -> null
        } ?: return

        Log.d("MainActivity", "🔍 DEBUG: mappedAction = $mappedAction")
        savePendingNavigationToPrefs(mappedAction)
        Log.d("MainActivity", "💾 action saved: $mappedAction")
    }

    private fun savePendingNavigationToPrefs(actionId: String) {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            // ✅ FIX #2: استخدام commit() المتزامن بدلاً من apply() غير المتزامن
            // commit() يضمن حفظ البيانات فوراً قبل قتل التطبيق من Battery Optimization
            prefs.edit().putString("flutter.pending_navigation", actionId).commit()
            Log.d("MainActivity", "✅ Saved to SharedPreferences: pending_navigation=$actionId")
            
            // ✅ DEBUG: Verify it was saved
            val verified = prefs.getString("flutter.pending_navigation", null)
            Log.d("MainActivity", "🔍 DEBUG: Verified read back: pending_navigation=$verified")
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ Failed to save to SharedPreferences: ${e.message}")
        }
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return

        Log.d("MainActivity", "handleIntent - action: ${intent.action}, navigate_to: ${intent.getStringExtra("navigate_to")}")

        // onNewIntent = التطبيق مفتوح بالفعل → Flutter جاهز → أرسل فوراً
        val navigateTo = intent.getStringExtra("navigate_to")
        if (navigateTo != null && navigateTo != "main") {
            Log.d("MainActivity", "📤 Sending navigate_to action immediately: $navigateTo")
            sendActionToFlutter(navigateTo)
            return
        }

        when {
            intent.action == "OPEN_ATHKAR"       -> sendActionToFlutter("open_athkar")
            intent.action == "OPEN_DUA"          -> sendActionToFlutter("open_dua")
            intent.action == "OPEN_QIBLA"        -> sendActionToFlutter("open_qibla")
            intent.action == "OPEN_PRAYER_TIMES" -> sendActionToFlutter("open_prayer_times")
            intent.action == "OPEN_TASBIH"       -> sendActionToFlutter("open_tasbih")
            intent.action?.startsWith("NOTIFICATION_ACTION_") == true -> {
                val actionId = intent.action!!.replace("NOTIFICATION_ACTION_", "").lowercase()
                sendActionToFlutter(actionId)
            }
        }
    }

    private fun sendActionToFlutter(actionId: String) {
        Log.d("MainActivity", "sendActionToFlutter: $actionId")
        notificationMethodChannel?.invokeMethod("onNotificationAction", actionId)
            ?: Log.w("MainActivity", "⚠️ MethodChannel not ready for: $actionId")
    }

    override fun onDestroy() {
        super.onDestroy()
        mainHandler.removeCallbacksAndMessages(null)
    }
}