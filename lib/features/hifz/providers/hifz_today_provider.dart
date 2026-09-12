import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/hifz_scheduler.dart';
import 'hifz_provider.dart';
import 'hifz_settings_provider.dart';

// ════════════════════════════════════════════════════════════════
//  hifzTodayProvider — قائمة "مراجعة اليوم" المشتقة (تثبيت + مراجعة
//  دورية)، محسوبة مباشرة عبر HifzScheduler.buildTodayQueue من حالة
//  hifzProvider + hifzSettingsProvider الحاليّة. لا تخزين خاص بها —
//  القيمة "مُشتَقّة" بالكامل (plan_hifz.md §3.4).
// ════════════════════════════════════════════════════════════════

final hifzTodayProvider = Provider<TodayQueue>((ref) {
  final hifz = ref.watch(hifzProvider);
  final settings = ref.watch(hifzSettingsProvider);

  if (hifz.isLoading) return const TodayQueue();

  return HifzScheduler.buildTodayQueue(
    pages: hifz.pages,
    settings: settings,
    meta: hifz.meta,
    today: DateTime.now(),
  );
});
