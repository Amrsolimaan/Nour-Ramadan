import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/alarm_permission_service.dart';
import '../../../core/services/battery_prompt_service.dart';
import '../../../core/services/unified_azan_service.dart';

// ════════════════════════════════════════════════════════════════
//  BatteryPermissionScreen — المرحلة 4
//
//  ⚠️ النصوص أدناه المُعلَّمة "DRAFT" هي مسودة للمراجعة فقط — لم
//  تُعتمد بعد. راجع تقرير المرحلة 4 في المحادثة قبل النشر.
//
//  السلوك:
//  • تُفتح من BatteryPromptService.maybeShow() بعد أول تفعيل أذان،
//    وفقط إن كان الإعفاء غير ممنوح أصلاً ولم يُرفض العرض خلال 30 يوماً.
//  • زر "منح الصلاحية": يفحص هل الجهاز من مصنّع بقيود صارمة
//    (Xiaomi/Vivo/Oppo/Huawei) عبر hasStrictOemRestrictions() —
//    إن كان: يفتح إعداداته الخاصة (ManufacturerHelper، ناتيف بالكامل)؛
//    وإلا: يطلب الإعفاء العام المباشر من نظام Android.
//  • النتيجة المُعادة عند pop: true فقط إذا تأكّد منح الإعفاء فعلياً
//    (بعد إعادة الفحص)، وإلا null/false — الطرف المستدعي
//    (BatteryPromptService.maybeShow) يُسجّل أي نتيجة غير true كرفض.
// ════════════════════════════════════════════════════════════════

class BatteryPermissionScreen extends StatefulWidget {
  const BatteryPermissionScreen({super.key});

  @override
  State<BatteryPermissionScreen> createState() =>
      _BatteryPermissionScreenState();
}

class _BatteryPermissionScreenState extends State<BatteryPermissionScreen> {
  bool _isChecking = true;
  bool _isOptimized = true;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => _isChecking = true);

    final azanService = UnifiedAzanService();
    final isOptimized = !(await azanService.isBatteryOptimizationDisabled());

    if (!mounted) return;
    setState(() {
      _isOptimized = isOptimized;
      _isChecking = false;
    });
  }

  // ════════════════════════════════════════════════════════════
  //  زر "منح الصلاحية" — يوجّه حسب المصنّع (المرحلة 4، البند 4)
  // ════════════════════════════════════════════════════════════
  Future<void> _requestExemption() async {
    setState(() => _isRequesting = true);

    final action = await BatteryPromptService.instance.resolveGrantAction();

    switch (action) {
      case BatteryGrantAction.manufacturerSpecific:
        await AlarmPermissionService.instance.openManufacturerSettings();
      case BatteryGrantAction.generic:
        await UnifiedAzanService().requestBatteryExemption();
    }

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _isRequesting = false);
    await _checkStatus();
  }

  // ════════════════════════════════════════════════════════════
  //  الخطوات اليدوية — نص المصنّع الفعلي من ManufacturerHelper
  //  (كان هذا Dialog يعرض نصاً عاماً ثابتاً بغض النظر عن الجهاز؛
  //  الآن يعرض تعليمات Xiaomi/Vivo/Oppo/Huawei/Samsung الحقيقية
  //  المكتوبة أصلاً في ManufacturerHelper.getInstructions())
  // ════════════════════════════════════════════════════════════
  Future<void> _showManualStepsDialog() async {
    final instructions = await AlarmPermissionService.instance
        .getManufacturerInstructions();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الخطوات اليدوية'), // DRAFT
        content: SingleChildScrollView(
          child: Text(
            instructions.isNotEmpty
                ? instructions
                : '١. افتح الإعدادات\n' // DRAFT — fallback إن فشل القناة
                      '٢. اذهب إلى التطبيقات\n'
                      '٣. ابحث عن "نور رمضان"\n'
                      '٤. اضغط على البطارية\n'
                      '٥. اختر "غير مقيّد"',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'), // DRAFT
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  زر "لاحقاً" — خروج صريح دون منح؛ الطرف المستدعي يُسجّل الرفض
  // ════════════════════════════════════════════════════════════
  void _declineNow() => Navigator.pop(context, false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('إعدادات البطارية'), // DRAFT
      ),
      body: _isChecking
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    _isOptimized ? Icons.battery_alert : Icons.battery_full,
                    size: 80.sp,
                    color: _isOptimized ? Colors.orange : Colors.green,
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    // DRAFT — عنوان الحالة الرئيسي
                    _isOptimized
                        ? 'الأذان لن يعمل عند إغلاق التطبيق'
                        : 'الإعدادات صحيحة ✓',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: _isOptimized ? Colors.orange : Colors.green,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppColors.goldWarm.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.goldWarm.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'لماذا نحتاج هذه الصلاحية؟', // DRAFT
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.goldLight,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          // DRAFT — نص الشرح الأساسي (body)
                          '• لتشغيل الأذان في الوقت المحدد بدقة\n'
                          '• لإرسال إشعارات التذكير قبل الصلاة\n'
                          '• لعمل التطبيق حتى عندما يكون مغلقاً\n'
                          '• لضمان عدم تفويت أي صلاة',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),
                  if (_isOptimized) ...[
                    ElevatedButton(
                      onPressed: _isRequesting ? null : _requestExemption,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.goldWarm,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: _isRequesting
                          ? SizedBox(
                              height: 20.h,
                              width: 20.h,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'منح الصلاحية الآن', // DRAFT — زر أساسي
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.nightDeep,
                              ),
                            ),
                    ),
                    SizedBox(height: 12.h),
                    TextButton(
                      onPressed: _showManualStepsDialog,
                      child: const Text('عرض الخطوات اليدوية'), // DRAFT
                    ),
                    SizedBox(height: 4.h),
                    TextButton(
                      onPressed: _declineNow,
                      child: Text(
                        'لاحقاً', // DRAFT — زر الرفض/التأجيل
                        style: TextStyle(color: AppColors.textDim),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              // DRAFT — رسالة النجاح
                              'الأذان والإشعارات ستعمل بشكل صحيح حتى عند إغلاق التطبيق',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.goldWarm,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        'متابعة', // DRAFT — زر تأكيد الإغلاق بعد المنح
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.nightDeep,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
