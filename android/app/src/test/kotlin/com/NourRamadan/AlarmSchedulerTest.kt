package com.NourRamadan

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

// ════════════════════════════════════════════════════════════════
//  AlarmSchedulerTest — تدقيق المرحلة 2 (plan_azan_reliability.md)
//
//  يختبر AlarmScheduler.computeStaleIds() — الدالة الصِرفة (pure) التي
//  يستخدمها refresh() فعلياً لتحديد ما يُلغى. اختبار JVM عادي بلا
//  Robolectric ولا Context/AlarmManager: الدالة لا تلمس أياً منهما.
//
//  السيناريو الذي يُثبته: دورة تحديث تخطِّط N منبهاً بنجاح
//  (computeSchedule) لكن يفشل تسليح M منها فعلياً (استثناء عابر في
//  setAlarmClock، أو فشل حساب يوم واحد). يجب أن تبقى M منبهات صالحة
//  من السجلّ القديم دون إلغاء — بينما تُلغى المعرّفات الخارجة عن
//  النافذة الجديدة كلياً فعلاً.
// ════════════════════════════════════════════════════════════════
class AlarmSchedulerTest {

    // ────────────────────────────────────────────────────────────
    //  السيناريو الكامل: فشل جزئي في التسليح لا يُلغي منبهات صالحة
    // ────────────────────────────────────────────────────────────
    @Test
    fun `partial arm failure does not cancel still-valid previously-armed alarms`() {
        // ── دورة سابقة ناجحة: 7 معرّفات مُسلَّحة ──────────────────
        //  A1..A5: أذانات لا تزال ضمن النافذة الجديدة هذه الدورة
        //  S1, S2: أذانات خرجت من النافذة الجديدة (ماضية فعلاً)
        val a1 = 1_000_100; val a2 = 1_000_101; val a3 = 1_000_102
        val a4 = 1_000_103; val a5 = 1_000_104
        val s1 = 999_998; val s2 = 999_999 // خارج النافذة الجديدة تماماً
        val oldLedger = setOf(a1, a2, a3, a4, a5, s1, s2)

        // ── هذه الدورة: computeSchedule() خطّطت 7 معرّفات (N=7) ──
        //  (نفس A1..A5 + معرّفان جديدان — S1/S2 غابا لأنهما خارج النافذة)
        val a6 = 1_000_105; val a7 = 1_000_110
        val plannedIds = setOf(a1, a2, a3, a4, a5, a6, a7)
        assertEquals("N=7 مخطَّطة هذه الدورة", 7, plannedIds.size)

        // ── محاكاة فشل التسليح: M=2 من السبعة (A3, A4) فشل تسليحها ──
        //  (استثناء SecurityException/IllegalStateException وغيرها في
        //  scheduleAzan()/scheduleReminder() — نفس ما يُنتج nowArmed
        //  الفعلي في refresh())
        val failedThisPass = setOf(a3, a4)
        val nowArmed = plannedIds - failedThisPass // ما نجح تسليحه فعلاً (M=2 فشل، 5 نجح)
        assertEquals("5 نجح تسليحها، 2 فشل", 5, nowArmed.size)

        // ══════════════════════════════════════════════════════
        //  ✅ السلوك بعد الإصلاح: يُقارَن بـ plannedIds
        // ══════════════════════════════════════════════════════
        val staleAfterFix = AlarmScheduler.computeStaleIds(oldLedger, plannedIds)

        // A3, A4 فشل تسليحهما هذه الدورة، لكنهما ما زالا ضمن plannedIds
        // (النافذة الجديدة) — فلا يُعتبران متقادمين ولا يُلغيان.
        assertFalse("A3 (فشل تسليحه) يجب ألا يُلغى", staleAfterFix.contains(a3))
        assertFalse("A4 (فشل تسليحه) يجب ألا يُلغى", staleAfterFix.contains(a4))

        // A1, A2, A5 (نجح تسليحها) بالتأكيد ليست متقادمة أيضاً
        assertFalse(staleAfterFix.contains(a1))
        assertFalse(staleAfterFix.contains(a2))
        assertFalse(staleAfterFix.contains(a5))

        // S1, S2 خارج النافذة الجديدة تماماً (ليسا في plannedIds
        // إطلاقاً، بصرف النظر عن أي تسليح) — يجب أن يُلغيا فعلاً.
        assertTrue("S1 (خارج النافذة فعلاً) يجب أن يُلغى", staleAfterFix.contains(s1))
        assertTrue("S2 (خارج النافذة فعلاً) يجب أن يُلغى", staleAfterFix.contains(s2))

        // النتيجة الوحيدة المتقادمة فعلاً: S1 و S2 فقط
        assertEquals(setOf(s1, s2), staleAfterFix)

        // ══════════════════════════════════════════════════════
        //  🐛 توضيح الخلل قبل الإصلاح: لو قُورن بـ nowArmed بدلاً من
        //  plannedIds، كان A3 و A4 (منبهان صالحان من دورة سابقة) سيُلغيان
        //  خطأً لمجرّد فشل إعادة تسليحهما هذه الدورة فقط.
        // ══════════════════════════════════════════════════════
        val staleBeforeFixWouldHaveBeen = oldLedger - nowArmed
        assertTrue(
            "قبل الإصلاح: A3 كان سيُلغى خطأً — هذا ما يمنعه الإصلاح",
            staleBeforeFixWouldHaveBeen.contains(a3),
        )
        assertTrue(
            "قبل الإصلاح: A4 كان سيُلغى خطأً — هذا ما يمنعه الإصلاح",
            staleBeforeFixWouldHaveBeen.contains(a4),
        )
    }

    // ────────────────────────────────────────────────────────────
    //  حالات حدّية بسيطة
    // ────────────────────────────────────────────────────────────
    @Test
    fun `no stale ids when old ledger is empty`() {
        assertTrue(AlarmScheduler.computeStaleIds(emptySet(), setOf(1, 2, 3)).isEmpty())
    }

    @Test
    fun `everything is stale when planned is empty`() {
        val old = setOf(1, 2, 3)
        assertEquals(old, AlarmScheduler.computeStaleIds(old, emptySet()))
    }

    @Test
    fun `identical sets produce no stale ids`() {
        val ids = setOf(10, 20, 30)
        assertTrue(AlarmScheduler.computeStaleIds(ids, ids).isEmpty())
    }

    @Test
    fun `total arm failure scenario is unaffected by this function`() {
        // ملاحظة: فشل تسليح الكل (nowArmed فارغة) يُعالَج في refresh()
        // بحارس مبكر منفصل (return قبل الوصول لهذا الحساب أصلاً) —
        // لا علاقة لـ computeStaleIds بهذه الحالة، وهذا الاختبار
        // يُوثِّق أن الدالة نفسها تبقى صحيحة رياضياً حتى لو استُدعيت
        // بغضّ النظر عن ذلك الحارس.
        val oldLedger = setOf(1, 2, 3)
        val plannedIds = setOf(1, 2, 3, 4, 5) // كل شيء "مخطَّط" رغم فشل التسليح بالكامل
        assertTrue(AlarmScheduler.computeStaleIds(oldLedger, plannedIds).isEmpty())
    }

    // ════════════════════════════════════════════════════════════
    //  المرحلة 3 — isReminderId(): توجيه المعرّف بحسب نطاقه
    // ════════════════════════════════════════════════════════════
    @Test
    fun `id below reminder offset is classified as azan`() {
        assertFalse(AlarmScheduler.isReminderId(1_000_100)) // أذان عادي
    }

    @Test
    fun `id at or above reminder offset is classified as reminder`() {
        assertTrue(AlarmScheduler.isReminderId(1_100_100)) // 1,000,100 + 100,000
        assertTrue(AlarmScheduler.isReminderId(1_199_999)) // أعلى الحدّ العملي لنطاق التذكير
    }

    @Test
    fun `boundary just below reminder offset is still azan`() {
        assertFalse(AlarmScheduler.isReminderId(1_099_999)) // آخر معرّف أذان ممكن رياضياً
    }

    // ════════════════════════════════════════════════════════════
    //  المرحلة 3 — decideNeedsRefresh(): منطق التدقيق الصِرف
    // ════════════════════════════════════════════════════════════
    private val sevenDaysMs = 7 * 24 * 60 * 60 * 1000L
    private val thirtyDaysMs = 30 * 24 * 60 * 60 * 1000L

    @Test
    fun `empty ledger always needs refresh`() {
        val r = AlarmScheduler.decideNeedsRefresh(
            ledgerSize = 0, missingFromOsCount = 0, horizonRemainingMs = thirtyDaysMs,
        )
        assertTrue("سجلّ فارغ يجب أن يُطلق إعادة الحساب دائماً", r.shouldRefresh)
    }

    @Test
    fun `expired horizon needs refresh even with a fully intact ledger`() {
        val r = AlarmScheduler.decideNeedsRefresh(
            ledgerSize = 231, missingFromOsCount = 0, horizonRemainingMs = 0L,
        )
        assertTrue(r.shouldRefresh)

        val rNegative = AlarmScheduler.decideNeedsRefresh(
            ledgerSize = 231, missingFromOsCount = 0, horizonRemainingMs = -1L,
        )
        assertTrue("أفق سالب (منتهٍ فعلاً) يجب أن يُطلق إعادة الحساب", rNegative.shouldRefresh)
    }

    @Test
    fun `any mismatch between ledger and OS triggers refresh regardless of horizon`() {
        val r = AlarmScheduler.decideNeedsRefresh(
            ledgerSize = 231, missingFromOsCount = 1, horizonRemainingMs = thirtyDaysMs,
        )
        assertTrue(
            "معرّف واحد مفقود من نظام التشغيل كافٍ لإطلاق إعادة الحساب — رغم أفق وافر",
            r.shouldRefresh,
        )
        assertTrue(r.reason.contains("1"))
    }

    @Test
    fun `horizon strictly below threshold triggers refresh even with a perfectly intact ledger`() {
        val r = AlarmScheduler.decideNeedsRefresh(
            ledgerSize = 231,
            missingFromOsCount = 0,
            horizonRemainingMs = sevenDaysMs - 1,
            horizonThresholdMs = sevenDaysMs,
        )
        assertTrue(r.shouldRefresh)
    }

    @Test
    fun `horizon exactly at threshold does not trigger refresh`() {
        val r = AlarmScheduler.decideNeedsRefresh(
            ledgerSize = 231,
            missingFromOsCount = 0,
            horizonRemainingMs = sevenDaysMs,
            horizonThresholdMs = sevenDaysMs,
        )
        assertFalse("الحدّ نفسه ليس \"دون\" الحدّ — لا حاجة لإعادة الحساب", r.shouldRefresh)
    }

    @Test
    fun `healthy ledger with ample horizon does not trigger refresh`() {
        val r = AlarmScheduler.decideNeedsRefresh(
            ledgerSize = 231, missingFromOsCount = 0, horizonRemainingMs = thirtyDaysMs,
        )
        assertFalse(r.shouldRefresh)
        assertEquals(0, r.missingFromOs)
        assertEquals(231, r.ledgerSize)
    }

    @Test
    fun `default threshold is one third of the 21-day horizon (7 days)`() {
        // يُثبِّت القيمة الفعلية المستخدمة في الإنتاج (لا مُمرَّرة صريحاً)
        val justBelow = AlarmScheduler.decideNeedsRefresh(
            ledgerSize = 231, missingFromOsCount = 0, horizonRemainingMs = sevenDaysMs - 1,
        )
        val justAtOrAbove = AlarmScheduler.decideNeedsRefresh(
            ledgerSize = 231, missingFromOsCount = 0, horizonRemainingMs = sevenDaysMs,
        )
        assertTrue("6 أيام و23:59:59 دون الحدّ الافتراضي 7 أيام", justBelow.shouldRefresh)
        assertFalse("7 أيام كاملة تساوي الحدّ الافتراضي — لا حاجة", justAtOrAbove.shouldRefresh)
    }
}
