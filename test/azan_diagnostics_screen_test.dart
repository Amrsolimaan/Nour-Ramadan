// اختبارات widget لشاشة تشخيص الأذان (المرحلة 8) — تحقن snapshotLoader
// مزيّفاً لتفادي SharedPreferences/MethodChannel الحقيقيين، وتتحقّق من
// عرض حالة الأفق الصحيحة (healthy/shrinking/critical/unknown) وعدد
// المنبهات وآخر أذان أُطلق.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nour_ramadan/core/services/system_diagnostics_service.dart';
import 'package:nour_ramadan/features/diagnostics/screens/azan_diagnostics_screen.dart';

void main() {
  Widget wrap(Future<AzanHealthSnapshot> Function() loader) {
    return MaterialApp(
      home: AzanDiagnosticsScreen(snapshotLoader: loader),
    );
  }

  testWidgets('أفق سليم (healthy) ⇒ يعرض "الأفق سليم" ويُخفي تحذيرات', (
    tester,
  ) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      wrap(
        () async => AzanHealthSnapshot(
          isAndroid: true,
          androidArmedCount: 58,
          androidLastRefreshAt: now,
          horizonEndAt: now.add(const Duration(days: 20)),
          horizonThresholdDays: 7,
          hasExactAlarmPermission: true,
          isBatteryOptimizationDisabled: true,
          hasNotificationPermission: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الأفق سليم'), findsOneWidget);
    expect(find.text('58'), findsOneWidget);
  });

  testWidgets('أفق يتقلّص (shrinking) ⇒ يعرض رسالة التحذير الصحيحة', (
    tester,
  ) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      wrap(
        () async => AzanHealthSnapshot(
          isAndroid: true,
          androidArmedCount: 12,
          androidLastRefreshAt: now.subtract(const Duration(hours: 2)),
          horizonEndAt: now.add(const Duration(days: 3)),
          horizonThresholdDays: 7,
          hasExactAlarmPermission: true,
          isBatteryOptimizationDisabled: true,
          hasNotificationPermission: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الأفق يتقلّص — يحتاج تجديداً قريباً'), findsOneWidget);
  });

  testWidgets('أفق منتهٍ (critical) ⇒ يعرض رسالة الخطر', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      wrap(
        () async => AzanHealthSnapshot(
          isAndroid: true,
          androidArmedCount: 0,
          androidLastRefreshAt: now.subtract(const Duration(days: 10)),
          horizonEndAt: now.subtract(const Duration(hours: 1)),
          horizonThresholdDays: 7,
          hasExactAlarmPermission: true,
          isBatteryOptimizationDisabled: true,
          hasNotificationPermission: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الأفق منتهٍ — لا تغطية من الآن'), findsOneWidget);
  });

  testWidgets('لا بيانات أفق محفوظة (unknown) ⇒ يعرض رسالة "لا بيانات"', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        () async => const AzanHealthSnapshot(
          isAndroid: true,
          horizonEndAt: null,
          horizonThresholdDays: 7,
          hasExactAlarmPermission: false,
          isBatteryOptimizationDisabled: false,
          hasNotificationPermission: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('لا بيانات أفق محفوظة بعد'), findsOneWidget);
  });

  testWidgets('iOS: يُخفي أعمدة أندرويد الخاصة (عدد المنبهات/آخر تحديث)', (
    tester,
  ) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      wrap(
        () async => AzanHealthSnapshot(
          isAndroid: false,
          horizonEndAt: now.add(const Duration(days: 4)),
          horizonThresholdDays: kIosHorizonThresholdDays,
          hasExactAlarmPermission: true,
          isBatteryOptimizationDisabled: true,
          hasNotificationPermission: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('المنبهات المُسلَّحة حالياً'), findsNothing);
    expect(
      find.text('إذن المنبّه الدقيق وإعفاء البطارية خاصّان بأندرويد — لا مفهوم مطابق على iOS.'),
      findsOneWidget,
    );
  });

  testWidgets('آخر أذان أُطلق: يعرض اسم الصلاة المُمرَّر', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      wrap(
        () async => AzanHealthSnapshot(
          isAndroid: true,
          androidArmedCount: 40,
          androidLastRefreshAt: now,
          horizonEndAt: now.add(const Duration(days: 10)),
          horizonThresholdDays: 7,
          lastFiredAt: now.subtract(const Duration(minutes: 5)),
          lastFiredPrayer: 'العصر',
          hasExactAlarmPermission: true,
          isBatteryOptimizationDisabled: true,
          hasNotificationPermission: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('العصر'), findsOneWidget);
  });

  testWidgets('خطأ في التحميل ⇒ يعرض رسالة الخطأ بدل الانهيار', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(() async => throw Exception('boom')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('تعذّر تحميل بيانات التشخيص'), findsOneWidget);
  });
}
