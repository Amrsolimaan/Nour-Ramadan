import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/services/hifz_service.dart';
import '../../../core/theme/app_colors.dart';
import '../logic/hifz_scheduler.dart';
import '../models/hifz_models.dart';
import '../providers/hifz_provider.dart';
import '../providers/hifz_settings_provider.dart';
import '../widgets/hifz_app_bar.dart';
import '../widgets/hifz_toast.dart';

// ════════════════════════════════════════════════════════════════
//  HifzSettingsScreen — إعدادات الحفظ (المرحلة 5 — plan_hifz.md §4.6)
//  كل عنصر تحكّم يكتب في hifzSettingsProvider فوراً (بلا زر "حفظ"
//  منفصل) عبر HifzSettingsNotifier.update — الذي يستدعي بدوره
//  HifzScheduler.onSettingsChanged (§3.4) ويُعيد تحميل hifzProvider
//  تلقائياً. هذه الشاشة تُثبت متطلّب "الورد القابل للتعديل الحر" —
//  انظر test/hifz_scheduler_test.dart لإثباته الآلي على مستوى المحرّك.
// ════════════════════════════════════════════════════════════════

class HifzSettingsScreen extends ConsumerWidget {
  const HifzSettingsScreen({super.key});

  static String _unitLabel(HifzPortionUnit unit) => switch (unit) {
    HifzPortionUnit.page => 'صفحة',
    HifzPortionUnit.quarterHizb => 'ربع حزب',
    HifzPortionUnit.halfHizb => 'نصف حزب',
    HifzPortionUnit.hizb => 'حزب',
  };

  static int _approxPages(HifzPortionUnit unit, double count) =>
      HifzScheduler.pagesForPortion(unit, count, startCursor: 1).length;

  Future<void> _apply(BuildContext context, WidgetRef ref, HifzSettings next) async {
    await ref.read(hifzSettingsProvider.notifier).update(next);
    if (!context.mounted) return;
    showHifzToast(context, 'تم الحفظ — سيظهر الأثر في ورد الغد');
  }

  /// تفعيل/تعطيل تذكير الورد — يمرّ عبر setWirdReminder (يطلب إذن
  /// الإشعارات تلقائياً عند التفعيل إن لم يكن ممنوحاً بعد).
  Future<void> _toggleReminder(BuildContext context, WidgetRef ref, bool enabled) async {
    final ok = await ref.read(hifzSettingsProvider.notifier).setWirdReminder(enabled: enabled);
    if (!context.mounted) return;
    if (!ok) {
      showHifzToast(context, 'يلزم إذن الإشعارات لتفعيل التذكير');
      return;
    }
    showHifzToast(context, enabled ? 'تم تفعيل تذكير الورد اليومي' : 'تم إيقاف تذكير الورد اليومي');
  }

  Future<void> _pickReminderTime(BuildContext context, WidgetRef ref, HifzSettings settings) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.wirdReminderHour, minute: settings.wirdReminderMinute),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
            primary: AppColors.goldWarm,
            onPrimary: AppColors.nightDeep,
            surface: AppColors.nightCard,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !context.mounted) return;

    final ok = await ref
        .read(hifzSettingsProvider.notifier)
        .setWirdReminder(hour: picked.hour, minute: picked.minute);
    if (!context.mounted) return;
    if (ok) showHifzToast(context, 'تم تحديث وقت التذكير — سيظهر الأثر من الغد');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(hifzSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      body: SafeArea(
        child: Column(
          children: [
            const HifzAppBar(title: 'إعدادات الحفظ'),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
                children: [
                  _sectionCard(
                    title: 'مقدار ورد الحفظ اليومي',
                    child: _PortionRow(
                      unit: settings.newPortionUnit,
                      count: settings.newPortionCount,
                      onUnitChanged: (u) => _apply(context, ref, settings.copyWith(newPortionUnit: u)),
                      onCountChanged: (c) =>
                          _apply(context, ref, settings.copyWith(newPortionCount: c)),
                    ),
                  ),
                  _sectionCard(
                    title: 'مقدار ورد المراجعة اليومي',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PortionRow(
                          unit: settings.reviewPortionUnit,
                          count: settings.reviewPortionCount,
                          onUnitChanged: (u) =>
                              _apply(context, ref, settings.copyWith(reviewPortionUnit: u)),
                          onCountChanged: (c) =>
                              _apply(context, ref, settings.copyWith(reviewPortionCount: c)),
                        ),
                        SizedBox(height: 12.h),
                        _ToggleRow(
                          label: 'زيادة تلقائية لتقصير دورة المراجعة',
                          value: settings.autoEscalateReview,
                          onChanged: (v) =>
                              _apply(context, ref, settings.copyWith(autoEscalateReview: v)),
                        ),
                        SizedBox(height: 10.h),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'السقف الأقصى للتصعيد',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 12.sp,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            _UnitDropdown(
                              value: settings.reviewPortionMaxUnit,
                              onChanged: (u) =>
                                  _apply(context, ref, settings.copyWith(reviewPortionMaxUnit: u)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _sectionCard(
                    title: 'نافذة التثبيت (أيام)',
                    child: _DaysSlider(
                      value: settings.newlyMemorizedWindowDays,
                      min: 3,
                      max: 30,
                      onChanged: (v) =>
                          _apply(context, ref, settings.copyWith(newlyMemorizedWindowDays: v)),
                    ),
                  ),
                  _sectionCard(
                    title: 'عدد التقييمات القوية للترقية',
                    child: _IntStepperRow(
                      value: settings.promoteAfterConsecutiveStrong,
                      min: 2,
                      max: 20,
                      onChanged: (v) =>
                          _apply(context, ref, settings.copyWith(promoteAfterConsecutiveStrong: v)),
                    ),
                  ),
                  _sectionCard(
                    title: 'دورات المراجعة للإتقان',
                    child: _IntStepperRow(
                      value: settings.masterAfterFarCycles,
                      min: 1,
                      max: 10,
                      onChanged: (v) =>
                          _apply(context, ref, settings.copyWith(masterAfterFarCycles: v)),
                    ),
                  ),
                  _sectionCard(
                    title: 'نقطة البداية المقترحة',
                    child: Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: [
                        _choicePill(
                          label: 'من الفاتحة',
                          selected: settings.startPreference == HifzStartPreference.fromFatihah,
                          onTap: () => _apply(
                            context,
                            ref,
                            settings.copyWith(startPreference: HifzStartPreference.fromFatihah),
                          ),
                        ),
                        _choicePill(
                          label: 'من جزء عمّ',
                          selected: settings.startPreference == HifzStartPreference.fromJuzAmma,
                          onTap: () => _apply(
                            context,
                            ref,
                            settings.copyWith(startPreference: HifzStartPreference.fromJuzAmma),
                          ),
                        ),
                        _choicePill(
                          label: 'مخصّص',
                          selected: settings.startPreference == HifzStartPreference.custom,
                          onTap: () => _apply(
                            context,
                            ref,
                            settings.copyWith(startPreference: HifzStartPreference.custom),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _sectionCard(
                    title: 'أيام الراحة',
                    child: _RestWeekdaysPicker(
                      selected: settings.restWeekdays,
                      onChanged: (days) => _apply(context, ref, settings.copyWith(restWeekdays: days)),
                    ),
                  ),
                  _sectionCard(
                    title: 'ما الذي يحقّق ورد اليوم؟',
                    child: Column(
                      children: [
                        _ToggleRow(
                          label: 'الحفظ الجديد',
                          value: settings.countNewTowardWird,
                          onChanged: (v) =>
                              _apply(context, ref, settings.copyWith(countNewTowardWird: v)),
                        ),
                        SizedBox(height: 10.h),
                        _ToggleRow(
                          label: 'المراجعة',
                          value: settings.countReviewTowardWird,
                          onChanged: (v) =>
                              _apply(context, ref, settings.copyWith(countReviewTowardWird: v)),
                        ),
                      ],
                    ),
                  ),
                  _sectionCard(
                    title: 'تذكير الورد اليومي',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ToggleRow(
                          label: 'تفعيل التذكير',
                          value: settings.wirdReminderEnabled,
                          onChanged: (v) => _toggleReminder(context, ref, v),
                        ),
                        SizedBox(height: 12.h),
                        _ReminderTimeRow(
                          hour: settings.wirdReminderHour,
                          minute: settings.wirdReminderMinute,
                          onTap: () => _pickReminderTime(context, ref, settings),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 6.h),
                  _DangerZone(onTap: () => _showResetDialog(context, ref)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── قالب بطاقة قسم موحَّد ──────────────────────────────────────
  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.nightCard,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.borderGold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.goldLight,
            ),
          ),
          SizedBox(height: 10.h),
          child,
        ],
      ),
    );
  }

  Widget _choicePill({required String label, required bool selected, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        splashColor: AppColors.goldWarm.withValues(alpha: 0.15),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: selected ? AppColors.goldWarm.withValues(alpha: 0.2) : AppColors.nightSurface,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: selected ? AppColors.borderGoldStrong : AppColors.borderGold,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11.sp,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.goldLight : AppColors.textDim,
            ),
          ),
        ),
      ),
    );
  }

  // ── منطقة الخطر ──────────────────────────────────────────────
  Future<void> _showResetDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final canConfirm = controller.text.trim() == 'حذف';
            return AlertDialog(
              backgroundColor: AppColors.nightMid,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
                side: BorderSide(color: AppColors.goldWarm.withValues(alpha: 0.3)),
              ),
              title: Text(
                '⚠️ إعادة ضبط كل بيانات الحفظ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.redAccent,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'سيُحذف كل تقدّمك في الحفظ نهائياً ولا يمكن التراجع عن هذا.\n'
                    'اكتب "حذف" للتأكيد.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13.sp,
                      color: AppColors.agedPlaster,
                      height: 1.6,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: controller,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'حذف',
                      hintStyle: TextStyle(color: AppColors.textDim),
                      filled: true,
                      fillColor: AppColors.nightCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide(color: AppColors.borderGold),
                      ),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    'إلغاء',
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 13.sp, color: AppColors.textDim),
                  ),
                ),
                ElevatedButton(
                  onPressed: canConfirm
                      ? () => _confirmReset(context, dialogContext, ref)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    disabledBackgroundColor: Colors.redAccent.withValues(alpha: 0.25),
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                  ),
                  child: Text(
                    'حذف نهائياً',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmReset(
    BuildContext screenContext,
    BuildContext dialogContext,
    WidgetRef ref,
  ) async {
    Navigator.pop(dialogContext); // أغلق الحوار أولاً

    await HifzService.clearAll();
    ref.read(hifzSettingsProvider.notifier).resetToDefaults();
    await ref.read(hifzProvider.notifier).reload();

    if (!screenContext.mounted) return;
    // نعود مباشرةً إلى شاشة القرآن الرئيسية (تخطّي لوحة تحكم الحفظ
    // التي أصبحت الآن بلا محتوى ذي معنى بعد المسح الكامل) — هذه
    // الشاشة تُفتَح دائماً من لوحة التحكم، فبوّابتا رجوع تكفيان.
    final navigator = Navigator.of(screenContext);
    navigator.pop(); // أغلق شاشة الإعدادات
    navigator.pop(); // أغلق لوحة تحكم الحفظ → شاشة القرآن الرئيسية
  }
}

// ════════════════════════════════════════════════════════════════
//  صف وحدة + عدّاد مقدار الورد، مع سطر "≈ N صفحة/يوم"
// ════════════════════════════════════════════════════════════════
class _PortionRow extends StatelessWidget {
  const _PortionRow({
    required this.unit,
    required this.count,
    required this.onUnitChanged,
    required this.onCountChanged,
  });

  final HifzPortionUnit unit;
  final double count;
  final ValueChanged<HifzPortionUnit> onUnitChanged;
  final ValueChanged<double> onCountChanged;

  @override
  Widget build(BuildContext context) {
    final approxPages = HifzSettingsScreen._approxPages(unit, count);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _UnitDropdown(value: unit, onChanged: onUnitChanged),
            SizedBox(width: 12.w),
            _DoubleStepperRow(value: count, min: 0.5, max: 10, step: 0.5, onChanged: onCountChanged),
          ],
        ),
        SizedBox(height: 8.h),
        Text(
          '≈ $approxPages صفحة/يوم',
          style: TextStyle(fontFamily: 'Tajawal', fontSize: 10.sp, color: AppColors.textDim),
        ),
      ],
    );
  }
}

class _UnitDropdown extends StatelessWidget {
  const _UnitDropdown({required this.value, required this.onChanged});

  final HifzPortionUnit value;
  final ValueChanged<HifzPortionUnit> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      decoration: BoxDecoration(
        color: AppColors.nightSurface,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.borderGold),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<HifzPortionUnit>(
          value: value,
          dropdownColor: AppColors.nightCard,
          icon: Icon(Icons.expand_more_rounded, color: AppColors.goldWarm, size: 18.sp),
          style: TextStyle(fontFamily: 'Tajawal', fontSize: 12.sp, color: AppColors.textPrimary),
          items: HifzPortionUnit.values
              .map(
                (u) => DropdownMenuItem(
                  value: u,
                  child: Text(
                    HifzSettingsScreen._unitLabel(u),
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12.sp,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

Widget _stepperButton({required IconData icon, required VoidCallback? onTap}) {
  final enabled = onTap != null;
  return Material(
    color: Colors.transparent,
    shape: const CircleBorder(),
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 28.r,
        height: 28.r,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.goldWarm.withValues(alpha: enabled ? 0.12 : 0.04),
          border: Border.all(color: AppColors.goldWarm.withValues(alpha: enabled ? 0.4 : 0.15)),
        ),
        child: Icon(icon, size: 15.sp, color: enabled ? AppColors.goldWarm : AppColors.textDim),
      ),
    ),
  );
}

class _DoubleStepperRow extends StatelessWidget {
  const _DoubleStepperRow({
    required this.value,
    required this.onChanged,
    this.min = 0.5,
    this.max = 10,
    this.step = 0.5,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final double step;

  @override
  Widget build(BuildContext context) {
    final display = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepperButton(
          icon: Icons.remove_rounded,
          onTap: value > min ? () => onChanged(double.parse((value - step).toStringAsFixed(2))) : null,
        ),
        SizedBox(
          width: 40.w,
          child: Text(
            display,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.goldWarm,
            ),
          ),
        ),
        _stepperButton(
          icon: Icons.add_rounded,
          onTap: value < max ? () => onChanged(double.parse((value + step).toStringAsFixed(2))) : null,
        ),
      ],
    );
  }
}

class _IntStepperRow extends StatelessWidget {
  const _IntStepperRow({
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _stepperButton(icon: Icons.remove_rounded, onTap: value > min ? () => onChanged(value - 1) : null),
        SizedBox(
          width: 44.w,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.goldWarm,
            ),
          ),
        ),
        _stepperButton(icon: Icons.add_rounded, onTap: value < max ? () => onChanged(value + 1) : null),
      ],
    );
  }
}

class _DaysSlider extends StatelessWidget {
  const _DaysSlider({
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.goldWarm,
            inactiveTrackColor: AppColors.borderGold,
            thumbColor: AppColors.goldWarm,
            overlayColor: AppColors.goldWarm.withValues(alpha: 0.2),
            valueIndicatorColor: AppColors.nightCard,
            valueIndicatorTextStyle: TextStyle(fontFamily: 'Tajawal', color: AppColors.goldLight),
          ),
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            label: '$value يوم',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        Center(
          child: Text(
            '$value يوم',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.goldLight,
            ),
          ),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 12.sp, color: AppColors.textPrimary),
          ),
        ),
        _ToggleSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}

/// صف عرض/اختيار وقت التذكير — يفتح showTimePicker الرسمي (بصبغة
/// ألوان التطبيق عبر Theme override) بدل اختراع منتقي وقت مخصَّص.
class _ReminderTimeRow extends StatelessWidget {
  const _ReminderTimeRow({required this.hour, required this.minute, required this.onTap});

  final int hour;
  final int minute;
  final VoidCallback onTap;

  static String _format(int hour, int minute) {
    final period = hour < 12 ? 'ص' : 'م';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '${h12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'وقت التذكير',
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 12.sp, color: AppColors.textPrimary),
          ),
        ),
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10.r),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10.r),
            splashColor: AppColors.goldWarm.withValues(alpha: 0.15),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppColors.nightSurface,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: AppColors.borderGold),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time_rounded, color: AppColors.goldWarm, size: 15.sp),
                  SizedBox(width: 6.w),
                  Text(
                    _format(hour, minute),
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.goldWarm,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// مفتاح تبديل مُعاد بناؤه بنفس نمط المفتاح المخصَّص في
/// settings_screen.dart (حاوية بيضاوية متحرِّكة اللون + قرص أبيض
/// منزلق) — خاص بذلك الملف فأُعيد إنتاجه هنا محلياً.
class _ToggleSwitch extends StatelessWidget {
  const _ToggleSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46.w,
        height: 26.h,
        decoration: BoxDecoration(
          color: value ? AppColors.goldWarm : AppColors.textDim.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(13.r),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20.w,
            height: 20.w,
            margin: EdgeInsets.symmetric(horizontal: 3.w),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

class _RestWeekdaysPicker extends StatelessWidget {
  const _RestWeekdaysPicker({required this.selected, required this.onChanged});

  final List<int> selected;
  final ValueChanged<List<int>> onChanged;

  static const _labels = {
    1: 'الإثنين',
    2: 'الثلاثاء',
    3: 'الأربعاء',
    4: 'الخميس',
    5: 'الجمعة',
    6: 'السبت',
    7: 'الأحد',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        for (final entry in _labels.entries)
          _WeekdayChip(
            label: entry.value,
            selected: selected.contains(entry.key),
            onTap: () {
              final next = [...selected];
              if (next.contains(entry.key)) {
                next.remove(entry.key);
              } else {
                next.add(entry.key);
              }
              next.sort();
              onChanged(next);
            },
          ),
      ],
    );
  }
}

class _WeekdayChip extends StatelessWidget {
  const _WeekdayChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        splashColor: AppColors.goldWarm.withValues(alpha: 0.15),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
          decoration: BoxDecoration(
            color: selected ? AppColors.goldWarm.withValues(alpha: 0.2) : AppColors.nightSurface,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: selected ? AppColors.borderGoldStrong : AppColors.borderGold,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11.sp,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.goldLight : AppColors.textDim,
            ),
          ),
        ),
      ),
    );
  }
}

class _DangerZone extends StatelessWidget {
  const _DangerZone({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        splashColor: Colors.redAccent.withValues(alpha: 0.15),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'إعادة ضبط كل بيانات الحفظ',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.redAccent,
                  ),
                ),
              ),
              Icon(Icons.arrow_back_ios_new, color: Colors.redAccent.withValues(alpha: 0.6), size: 12.sp),
            ],
          ),
        ),
      ),
    );
  }
}
