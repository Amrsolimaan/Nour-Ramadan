import 'package:flutter/material.dart';

import '../../../core/services/system_diagnostics_service.dart';
import '../../../core/theme/app_colors.dart';

// ════════════════════════════════════════════════════════════════
//  AzanDiagnosticsScreen — المرحلة 8 (plan_azan_reliability.md)
//
//  لوحة قراءة فقط — لا تُشغِّل أي جدولة، لا تُغيِّر أي إعداد. كل ما
//  تعرضه يأتي من loadAzanHealthSnapshot() (نفس الملف: system_
//  diagnostics_service.dart) الذي يقرأ مصادر حقيقية موجودة فعلاً.
// ════════════════════════════════════════════════════════════════

class AzanDiagnosticsScreen extends StatefulWidget {
  /// [snapshotLoader] قابل للحقن — يُستخدَم في الاختبارات لتفادي
  /// SharedPreferences/MethodChannel الحقيقيين؛ الافتراضي (الإنتاجي)
  /// هو loadAzanHealthSnapshot() الحقيقية من system_diagnostics_service.dart.
  const AzanDiagnosticsScreen({super.key, this.snapshotLoader});

  final Future<AzanHealthSnapshot> Function()? snapshotLoader;

  @override
  State<AzanDiagnosticsScreen> createState() => _AzanDiagnosticsScreenState();
}

class _AzanDiagnosticsScreenState extends State<AzanDiagnosticsScreen> {
  late Future<AzanHealthSnapshot> _future;

  Future<AzanHealthSnapshot> _load() =>
      (widget.snapshotLoader ?? loadAzanHealthSnapshot)();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      appBar: AppBar(
        backgroundColor: AppColors.nightMid,
        title: const Text(
          'تشخيص الأذان',
          style: TextStyle(fontFamily: 'NotoNaskhArabic', color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, color: AppColors.goldLight),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: FutureBuilder<AzanHealthSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.goldWarm),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'تعذّر تحميل بيانات التشخيص:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textDim, fontFamily: 'Tajawal'),
              ),
            );
          }
          final data = snapshot.requireData;
          final now = DateTime.now();
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            color: AppColors.goldWarm,
            backgroundColor: AppColors.nightSurface,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _horizonCard(data, now),
                const SizedBox(height: 12),
                _sectionCard(
                  title: 'الجدولة',
                  children: [
                    if (data.isAndroid)
                      _row('المنبهات المُسلَّحة حالياً', '${data.androidArmedCount ?? 0}'),
                    if (data.isAndroid)
                      _row(
                        'آخر تحديث ناجح',
                        formatRelativeTimeLabel(data.androidLastRefreshAt, now),
                      ),
                    _row(
                      'نهاية الأفق المُسلَّح',
                      data.horizonEndAt == null
                          ? 'غير معروف'
                          : _formatDate(data.horizonEndAt!),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  title: 'آخر أذان أُطلق',
                  children: [
                    _row('الصلاة', data.lastFiredPrayer ?? '—'),
                    _row('الوقت', formatRelativeTimeLabel(data.lastFiredAt, now)),
                    if (!data.isAndroid)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          '⚠️ على iOS: هذا "آخر أذان نُقر عليه"، لا "آخر أذان سلَّمه النظام" —'
                          ' iOS لا يمنح التطبيق أي إشارة عند تسليم إشعار محلي بينما'
                          ' التطبيق في الخلفية أو مُغلَق (يتطلّب Notification Service'
                          ' Extension منفصلاً، خارج نطاق هذه المرحلة). على أندرويد القيمة'
                          ' دقيقة فعلاً: تُكتب عند نقطة الإطلاق الحقيقية في الكود الناتيف.',
                          style: TextStyle(
                            color: AppColors.textDim,
                            fontFamily: 'Tajawal',
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  title: 'الأذونات',
                  children: [
                    _permissionRow(
                      'إشعارات مفعّلة',
                      data.hasNotificationPermission,
                    ),
                    if (data.isAndroid) ...[
                      _permissionRow(
                        'إذن المنبّه الدقيق',
                        data.hasExactAlarmPermission,
                      ),
                      _permissionRow(
                        'إعفاء من توفير البطارية',
                        data.isBatteryOptimizationDisabled,
                      ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(top: 4, bottom: 4),
                        child: Text(
                          'إذن المنبّه الدقيق وإعفاء البطارية خاصّان بأندرويد — لا مفهوم مطابق على iOS.',
                          style: TextStyle(
                            color: AppColors.textDim,
                            fontFamily: 'Tajawal',
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _horizonCard(AzanHealthSnapshot data, DateTime now) {
    final health = data.horizonHealth(now);
    final (color, icon, label) = switch (health) {
      HorizonHealth.healthy => (Colors.green, Icons.check_circle, 'الأفق سليم'),
      HorizonHealth.shrinking => (
        Colors.orange,
        Icons.warning_amber_rounded,
        'الأفق يتقلّص — يحتاج تجديداً قريباً',
      ),
      HorizonHealth.critical => (
        Colors.red,
        Icons.error_outline,
        'الأفق منتهٍ — لا تغطية من الآن',
      ),
      HorizonHealth.unknown => (
        AppColors.textDim,
        Icons.help_outline,
        'لا بيانات أفق محفوظة بعد',
      ),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.nightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.nightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.goldLight,
              fontFamily: 'NotoNaskhArabic',
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textDim, fontFamily: 'Tajawal', fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Tajawal',
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _permissionRow(String label, bool granted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textDim, fontFamily: 'Tajawal', fontSize: 13),
          ),
          Icon(
            granted ? Icons.check_circle : Icons.cancel,
            color: granted ? Colors.green : Colors.red,
            size: 18,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
