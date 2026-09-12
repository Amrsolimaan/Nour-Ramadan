package com.NourRamadan

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log

/**
 * ManufacturerHelper — يتعامل مع قيود المصنّعين الخاصة
 * 
 * ✅ Xiaomi (MIUI) - Autostart, Battery Saver, MIUI Optimization
 * ✅ Vivo (Funtouch OS) - iManager, Background restrictions
 * ✅ Oppo (ColorOS) - Startup Manager, Battery Optimization
 * ✅ Huawei (EMUI) - App Launch, Protected Apps
 * ✅ Samsung (One UI) - Battery Optimization
 * 
 * المشكلة:
 * المصنّعون مثل Xiaomi و Vivo يضيفون قيوداً إضافية على التطبيقات
 * تعمل في الخلفية، مما يمنع الأذان من العمل بشكل موثوق.
 * 
 * الحل:
 * توجيه المستخدم لإعدادات المصنّع الخاصة لتعطيل هذه القيود.
 */
object ManufacturerHelper {
    private const val TAG = "ManufacturerHelper"
    
    enum class Manufacturer {
        XIAOMI, VIVO, OPPO, HUAWEI, SAMSUNG, OTHER
    }
    
    /**
     * اكتشاف المصنّع الحالي
     */
    fun detect(): Manufacturer {
        val manufacturer = Build.MANUFACTURER.lowercase()
        return when {
            manufacturer.contains("xiaomi") || manufacturer.contains("redmi") -> Manufacturer.XIAOMI
            manufacturer.contains("vivo") -> Manufacturer.VIVO
            manufacturer.contains("oppo") || manufacturer.contains("realme") -> Manufacturer.OPPO
            manufacturer.contains("huawei") || manufacturer.contains("honor") -> Manufacturer.HUAWEI
            manufacturer.contains("samsung") -> Manufacturer.SAMSUNG
            else -> Manufacturer.OTHER
        }
    }
    
    /**
     * فتح إعدادات Autostart حسب المصنّع
     * 
     * @return true إذا تم فتح الإعدادات بنجاح
     */
    fun openAutostartSettings(context: Context): Boolean {
        Log.d(TAG, "Opening autostart settings for: ${detect()}")
        return when (detect()) {
            Manufacturer.XIAOMI -> openXiaomiAutostart(context)
            Manufacturer.VIVO -> openVivoAutostart(context)
            Manufacturer.OPPO -> openOppoAutostart(context)
            Manufacturer.HUAWEI -> openHuaweiAutostart(context)
            else -> openGenericSettings(context)
        }
    }
    
    /**
     * فتح إعدادات Battery Optimization حسب المصنّع
     * 
     * @return true إذا تم فتح الإعدادات بنجاح
     */
    fun openBatterySettings(context: Context): Boolean {
        Log.d(TAG, "Opening battery settings for: ${detect()}")
        return when (detect()) {
            Manufacturer.XIAOMI -> openXiaomiBattery(context)
            Manufacturer.VIVO -> openVivoBattery(context)
            Manufacturer.OPPO -> openOppoBattery(context)
            Manufacturer.HUAWEI -> openHuaweiBattery(context)
            else -> openGenericBatterySettings(context)
        }
    }
    
    /**
     * الحصول على رسالة توجيهية مفصلة حسب المصنّع
     * 
     * @return نص توجيهي بالعربية يشرح الخطوات المطلوبة
     */
    fun getInstructions(context: Context): String {
        return when (detect()) {
            Manufacturer.XIAOMI -> """
                📱 إعدادات Xiaomi المطلوبة:
                
                1️⃣ Autostart (تشغيل تلقائي):
                   الإعدادات → التطبيقات → إدارة التطبيقات → نور رمضان → Autostart → تفعيل
                
                2️⃣ Battery Saver (توفير الطاقة):
                   الإعدادات → البطارية → توفير الطاقة → نور رمضان → بدون قيود
                
                3️⃣ MIUI Optimization:
                   الإعدادات → إعدادات إضافية → الخصوصية → إدارة الأذونات الخاصة → نور رمضان → السماح بكل شيء
                
                4️⃣ Background Restrictions:
                   الإعدادات → التطبيقات → إدارة التطبيقات → نور رمضان → تقييد الخلفية → لا قيود
            """.trimIndent()
            
            Manufacturer.VIVO -> """
                📱 إعدادات Vivo المطلوبة:
                
                1️⃣ Background App (تطبيقات الخلفية):
                   iManager → إدارة التطبيقات → نور رمضان → السماح بالعمل في الخلفية
                
                2️⃣ High Background Battery Consumption:
                   الإعدادات → البطارية → استهلاك البطارية العالي → نور رمضان → السماح
                
                3️⃣ Autostart (تشغيل تلقائي):
                   iManager → Autostart → نور رمضان → تفعيل
                
                4️⃣ Background Freeze:
                   الإعدادات → البطارية → تجميد الخلفية → نور رمضان → لا تجمّد
            """.trimIndent()
            
            Manufacturer.OPPO -> """
                📱 إعدادات Oppo المطلوبة:
                
                1️⃣ Startup Manager (إدارة بدء التشغيل):
                   الإعدادات → التطبيقات → إدارة التطبيقات → نور رمضان → Startup Manager → تفعيل
                
                2️⃣ Battery Optimization (تحسين البطارية):
                   الإعدادات → البطارية → توفير الطاقة → نور رمضان → لا تحسّن
                
                3️⃣ Background Freeze:
                   الإعدادات → البطارية → تجميد الخلفية → نور رمضان → لا تجمّد
            """.trimIndent()
            
            Manufacturer.HUAWEI -> """
                📱 إعدادات Huawei المطلوبة:
                
                1️⃣ App Launch (تشغيل التطبيق):
                   الإعدادات → التطبيقات → App Launch → نور رمضان → إدارة يدوياً → تفعيل كل شيء
                
                2️⃣ Protected Apps (التطبيقات المحمية):
                   الإعدادات → البطارية → App Launch → نور رمضان → إدارة يدوياً
                
                3️⃣ Battery Optimization:
                   الإعدادات → البطارية → تحسين البطارية → نور رمضان → لا تحسّن
            """.trimIndent()
            
            Manufacturer.SAMSUNG -> """
                📱 إعدادات Samsung المطلوبة:
                
                1️⃣ Battery Optimization:
                   الإعدادات → التطبيقات → نور رمضان → البطارية → غير محسّن
                
                2️⃣ Sleeping Apps:
                   الإعدادات → العناية بالجهاز → البطارية → حدود استخدام الخلفية → التطبيقات النائمة → إزالة نور رمضان
                
                3️⃣ Deep Sleeping Apps:
                   الإعدادات → العناية بالجهاز → البطارية → حدود استخدام الخلفية → التطبيقات النائمة بعمق → إزالة نور رمضان
            """.trimIndent()
            
            else -> """
                📱 إعدادات عامة مطلوبة:
                
                1️⃣ تعطيل Battery Optimization
                2️⃣ السماح بالعمل في الخلفية
                3️⃣ منح جميع الأذونات المطلوبة
                4️⃣ تفعيل التشغيل التلقائي (إن وُجد)
            """.trimIndent()
        }
    }
    
    /**
     * التحقق من وجود قيود خاصة بالمصنّع
     * 
     * @return true إذا كان المصنّع معروف بقيوده الصارمة
     */
    fun hasStrictRestrictions(): Boolean {
        return when (detect()) {
            Manufacturer.XIAOMI, Manufacturer.VIVO, Manufacturer.OPPO, Manufacturer.HUAWEI -> true
            else -> false
        }
    }
    
    // ════════════════════════════════════════════════════════════
    //  Xiaomi-specific
    // ════════════════════════════════════════════════════════════
    
    private fun openXiaomiAutostart(context: Context): Boolean {
        // محاولة 1: MIUI Permission Editor
        if (tryIntent(context, Intent().apply {
            action = "miui.intent.action.APP_PERM_EDITOR"
            putExtra("extra_pkgname", context.packageName)
        })) return true
        
        // محاولة 2: Security Center Autostart
        if (tryIntent(context, Intent().apply {
            component = android.content.ComponentName(
                "com.miui.securitycenter",
                "com.miui.permcenter.autostart.AutoStartManagementActivity"
            )
        })) return true
        
        // Fallback
        return openGenericSettings(context)
    }
    
    private fun openXiaomiBattery(context: Context): Boolean {
        // محاولة 1: MIUI Power Hide Mode
        if (tryIntent(context, Intent().apply {
            action = "miui.intent.action.POWER_HIDE_MODE_APP_LIST"
            putExtra("package_name", context.packageName)
            putExtra("package_label", getAppName(context))
        })) return true
        
        // Fallback
        return openGenericBatterySettings(context)
    }
    
    // ════════════════════════════════════════════════════════════
    //  Vivo-specific
    // ════════════════════════════════════════════════════════════
    
    private fun openVivoAutostart(context: Context): Boolean {
        // محاولة 1: Vivo Permission Manager
        if (tryIntent(context, Intent().apply {
            component = android.content.ComponentName(
                "com.vivo.permissionmanager",
                "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"
            )
        })) return true
        
        // محاولة 2: iQOO Secure
        if (tryIntent(context, Intent().apply {
            component = android.content.ComponentName(
                "com.iqoo.secure",
                "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager"
            )
        })) return true
        
        // Fallback
        return openGenericSettings(context)
    }
    
    private fun openVivoBattery(context: Context): Boolean {
        // محاولة 1: Vivo ABE (Application Behavior Engine)
        if (tryIntent(context, Intent().apply {
            component = android.content.ComponentName(
                "com.vivo.abe",
                "com.vivo.applicationbehaviorengine.ui.ExcessivePowerManagerActivity"
            )
        })) return true
        
        // Fallback
        return openGenericBatterySettings(context)
    }
    
    // ════════════════════════════════════════════════════════════
    //  Oppo-specific
    // ════════════════════════════════════════════════════════════
    
    private fun openOppoAutostart(context: Context): Boolean {
        // محاولة 1: ColorOS Safe Center
        if (tryIntent(context, Intent().apply {
            component = android.content.ComponentName(
                "com.coloros.safecenter",
                "com.coloros.safecenter.permission.startup.StartupAppListActivity"
            )
        })) return true
        
        // محاولة 2: Oppo Safe
        if (tryIntent(context, Intent().apply {
            component = android.content.ComponentName(
                "com.oppo.safe",
                "com.oppo.safe.permission.startup.StartupAppListActivity"
            )
        })) return true
        
        // Fallback
        return openGenericSettings(context)
    }
    
    private fun openOppoBattery(context: Context): Boolean {
        // محاولة 1: ColorOS Power Manager
        if (tryIntent(context, Intent().apply {
            component = android.content.ComponentName(
                "com.coloros.oppoguardelf",
                "com.coloros.powermanager.fuelgaue.PowerUsageModelActivity"
            )
        })) return true
        
        // Fallback
        return openGenericBatterySettings(context)
    }
    
    // ════════════════════════════════════════════════════════════
    //  Huawei-specific
    // ════════════════════════════════════════════════════════════
    
    private fun openHuaweiAutostart(context: Context): Boolean {
        // Huawei System Manager - Startup Manager
        return tryIntent(context, Intent().apply {
            component = android.content.ComponentName(
                "com.huawei.systemmanager",
                "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
            )
        }) || openGenericSettings(context)
    }
    
    private fun openHuaweiBattery(context: Context): Boolean {
        // Huawei System Manager - Protected Apps
        return tryIntent(context, Intent().apply {
            component = android.content.ComponentName(
                "com.huawei.systemmanager",
                "com.huawei.systemmanager.optimize.process.ProtectActivity"
            )
        }) || openGenericBatterySettings(context)
    }
    
    // ════════════════════════════════════════════════════════════
    //  Generic fallbacks
    // ════════════════════════════════════════════════════════════
    
    private fun openGenericSettings(context: Context): Boolean {
        return tryIntent(context, Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:${context.packageName}")
        })
    }
    
    private fun openGenericBatterySettings(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            tryIntent(context, Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        } else {
            openGenericSettings(context)
        }
    }
    
    // ════════════════════════════════════════════════════════════
    //  Helpers
    // ════════════════════════════════════════════════════════════
    
    private fun tryIntent(context: Context, intent: Intent): Boolean {
        return try {
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            context.startActivity(intent)
            Log.d(TAG, "✅ Opened settings: ${intent.component?.className ?: intent.action}")
            true
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ Failed to open settings: ${e.message}")
            false
        }
    }
    
    private fun getAppName(context: Context): String {
        return try {
            val appInfo = context.packageManager.getApplicationInfo(context.packageName, 0)
            context.packageManager.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            "Nour Ramadan"
        }
    }
}
