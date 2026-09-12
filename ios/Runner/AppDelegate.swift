import Flutter
import UIKit
import UserNotifications
import workmanager

@main
@objc class AppDelegate: FlutterAppDelegate {
  // ✅ المرحلة 7: معرّف مهمّة الخلفية — يجب أن يطابق حرفياً:
  //   • القيمة في IosNotificationWindow.backgroundTaskUniqueName (Dart)
  //   • السطر المُضاف في BGTaskSchedulerPermittedIdentifiers (Info.plist)
  private let iosWindowTopUpTaskIdentifier = "ios_notification_window_topup"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // ══════════════════════════════════════════════════════════
    // إعداد Notification Categories للأذان
    // ══════════════════════════════════════════════════════════
    if #available(iOS 10.0, *) {
      let azanCategory = UNNotificationCategory(
        identifier: "azan_category",
        actions: [],
        intentIdentifiers: [],
        options: [.customDismissAction]
      )

      UNUserNotificationCenter.current().setNotificationCategories([azanCategory])
    }

    // ══════════════════════════════════════════════════════════
    // ✅ المرحلة 7 (iOS): تسجيل معالج BGAppRefreshTask — يجب أن يحدث
    // هنا حصراً (قبل انتهاء didFinishLaunchingWithOptions)، وليس من
    // Dart بعد إقلاع Flutter؛ Apple تُوثِّق هذا كشرط صارم لصحّة
    // BGTaskScheduler.register(forTaskWithIdentifier:...).
    //
    // الفاصل (12 ساعة) هو ما يحكم إعادة الجدولة الفعلية داخل معالج
    // workmanager نفسه (schedulePeriodicTask يُعاد استدعاؤها من داخل
    // handlePeriodicTask في كل مرّة يُطلَق المعالج) — قيمة Dart-side
    // frequency في IosNotificationWindow.registerBackgroundTask() لا
    // تُستخدَم لهذا المسار، هذه القيمة هنا هي الفعلية.
    //
    // ⚠️ BGAppRefreshTaskRequest.earliestBeginDate هو حدّ أدنى فقط —
    // iOS يقرِّر بنفسه (فرصويّاً) متى يُشغِّل المهمّة فعلياً بحسب
    // نمط استخدام المستخدم والبطارية، وقد يتأخّر كثيراً عن 12 ساعة أو
    // لا يعمل لأيام إن لم يُفتَح التطبيق. هذا احتياط ثانوي — الآلية
    // الأساسية للموثوقية هي النافذة المتدرّجة نفسها (5 أيام مُسبَقة).
    if #available(iOS 13.0, *) {
      SwiftWorkmanagerPlugin.registerPeriodicTask(
        withIdentifier: iosWindowTopUpTaskIdentifier,
        frequency: NSNumber(value: 12 * 60 * 60)
      )
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
