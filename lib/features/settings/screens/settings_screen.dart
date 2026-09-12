import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nour_ramadan/core/theme/app_colors.dart';
import 'package:nour_ramadan/features/home/screens/home_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../core/services/prayer_notification_manager.dart';
import '../../../core/services/notification_permission_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/location_permission_service.dart';
import '../providers/settings_provider.dart';
import 'privacy_policy_screen.dart';
import 'app_guide_screen.dart';
import '../../diagnostics/screens/azan_diagnostics_screen.dart';

// ════════════════════════════════════════════════════════════════
//  Settings Screen —
// ════════════════════════════════════════════════════════════════

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _playingMuezzinId;
  bool _detectingLocation = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    
    // ✅ لا حاجة لفحص الأذونات هنا
    // النظام يجدول تلقائياً في main.dart عند resumed
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAzanPreview(String fileName, String muezzinId) async {
    try {
      // إيقاف أي تشغيل سابق
      await _audioPlayer.stop();

      // تفعيل زر الإيقاف فوراً قبل بدء التشغيل
      setState(() => _playingMuezzinId = muezzinId);

      // تحميل وتشغيل الملف
      await _audioPlayer.setAsset('assets/audio/$fileName');
      await _audioPlayer.play();

      // الاستماع لانتهاء التشغيل
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted && _playingMuezzinId == muezzinId) {
            setState(() => _playingMuezzinId = null);
          }
        }
      });
    } catch (e) {
      debugPrint('Error playing azan preview: $e');
      if (mounted) {
        setState(() => _playingMuezzinId = null);
      }
    }
  }

  Future<void> _stopAzanPreview() async {
    try {
      await _audioPlayer.stop();
      setState(() => _playingMuezzinId = null);
    } catch (e) {
      debugPrint('Error stopping azan preview: $e');
    }
  }

  // ── تحديد الموقع تلقائياً ─────────────────────────────────────────
  Future<void> _detectLocation() async {
    if (_detectingLocation) return;
    setState(() => _detectingLocation = true);

    try {
      final result = await LocationService.instance.detectCurrentLocation();

      if (!mounted) return;

      switch (result) {
        case LocationResult.success:
          final city = LocationService.instance.city;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تم تحديد الموقع بنجاح: $city',
                      style: const TextStyle(fontFamily: 'Tajawal'),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF2E7D32),
              duration: const Duration(seconds: 2),
            ),
          );

          // تأكيد تعيين الموقع
          await LocationPermissionService.markLocationAsSet();

          // إعادة جدولة الإشعارات
          try {
            ref.read(prayerNotificationManagerProvider).manualReschedule();
          } catch (e) {
            debugPrint('⚠️ Error rescheduling: $e');
          }

          // إعادة تحميل الإعدادات
          ref.read(settingsProvider.notifier).reload();
          break;

        case LocationResult.serviceDisabled:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'يرجى تفعيل GPS من الإعدادات أولاً',
                style: TextStyle(fontFamily: 'Tajawal'),
              ),
              backgroundColor: const Color(0xFFD32F2F),
              action: SnackBarAction(
                label: 'الإعدادات',
                textColor: Colors.white,
                onPressed: () => Geolocator.openLocationSettings(),
              ),
            ),
          );
          break;

        case LocationResult.permanentlyDenied:
          _showPermanentlyDeniedDialog();
          break;

        case LocationResult.denied:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'تم رفض صلاحية الوصول للموقع',
                style: TextStyle(fontFamily: 'Tajawal'),
              ),
              backgroundColor: Color(0xFFD32F2F),
            ),
          );
          break;

        case LocationResult.error:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'حدث خطأ أثناء تحديد الموقع، حاول مجدداً',
                style: TextStyle(fontFamily: 'Tajawal'),
              ),
              backgroundColor: Color(0xFFD32F2F),
            ),
          );
          break;
      }
    } finally {
      if (mounted) {
        setState(() => _detectingLocation = false);
      }
    }
  }

  void _showPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF9800)),
            SizedBox(width: 8),
            Text(
              'الوصول محظور',
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                color: Color(0xFFE8D5B0),
              ),
            ),
          ],
        ),
        content: const Text(
          'تم رفض صلاحية الموقع بشكل دائم. يرجى تفعيلها من إعدادات التطبيق لتتمكن من استخدام هذه الميزة.',
          style: TextStyle(fontFamily: 'Tajawal', color: Color(0xFFE8D5B0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: Color(0xFF9B8A6E)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text(
              'الإعدادات',
              style: TextStyle(color: Color(0xFFC8922A)),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  رسالة تنبيه: يجب تفعيل الأذونات والموقع أولاً
  // ══════════════════════════════════════════════════════════════
  void _showPermissionRequiredDialog(bool hasNotification, bool hasLocation) {
    String title;
    String message;
    IconData icon;

    if (!hasNotification && !hasLocation) {
      title = 'تفعيل الإشعارات والموقع مطلوب';
      message =
          'لاستخدام هذه الميزة، يجب عليك السماح بإرسال الإشعارات وتحديد موقعك أولاً.';
      icon = Icons.notifications_off_rounded;
    } else if (!hasNotification) {
      title = 'تفعيل الإشعارات مطلوب';
      message = 'لاستخدام هذه الميزة، يجب عليك السماح بإرسال الإشعارات أولاً.';
      icon = Icons.notifications_off_rounded;
    } else {
      title = 'تحديد الموقع مطلوب';
      message =
          'لاستخدام هذه الميزة، يجب عليك تحديد موقعك أولاً لحساب أوقات الصلاة بدقة.';
      icon = Icons.location_off_rounded;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: const Color(0xFFC8922A).withOpacity(0.3),
            width: 1,
          ),
        ),
        title: Row(
          children: [
            Icon(icon, color: const Color(0xFFC8922A), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 18,
                  color: Color(0xFFE8D5B0),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 14,
            color: Color(0xFFE8D5B0),
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إلغاء',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14,
                color: Color(0xFF9B8A6E),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              // تفعيل الإشعارات إذا لم تكن مفعلة
              if (!hasNotification) {
                final granted =
                    await NotificationPermissionService.requestPermission();
                if (granted && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تفعيل الإشعارات بنجاح'),
                      backgroundColor: Color(0xFFC8922A),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  // إعادة تحميل الإعدادات
                  ref.read(settingsProvider.notifier).reload();

                  // إعادة جدولة الإشعارات فوراً
                  if (LocationService.instance.hasLocation) {
                    try {
                      await ref
                          .read(prayerNotificationManagerProvider)
                          .manualReschedule();
                      debugPrint(
                        '✅ Notifications rescheduled after granting permission',
                      );
                    } catch (e) {
                      debugPrint('⚠️ Error rescheduling: $e');
                    }
                  }
                }
              }

              // تفعيل الموقع إذا لم يكن محدداً
              if (!hasLocation && mounted) {
                await _detectLocation();
              }
            },
            child: const Text(
              'تفعيل الآن',
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 15,
                color: Color(0xFFC8922A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 3),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF08061A), Color(0xFF130F2A), Color(0xFF1A1020)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────
              _buildHeader(context),

              // ── Content ─────────────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    const SizedBox(height: 8),

                    // ═══ التذكيرات ═══
                    _buildSectionTitle('التذكيرات'),
                    _buildToggleRow(
                      icon: '',
                      title: 'تذكير قبل الصلاة 15 دقيقة',
                      value: settings.prayerReminderEnabled,
                      onChanged: (val) async {
                        if (val) {
                          final hasPermission =
                              await NotificationPermissionService.hasPermission();
                          final hasLocation =
                              LocationService.instance.hasLocation;

                          if (!hasPermission || !hasLocation) {
                            _showPermissionRequiredDialog(
                              hasPermission,
                              hasLocation,
                            );
                            return;
                          }
                        }
                        notifier.setPrayerReminder(val);

                        // ✅ إعادة جدولة الإشعارات فوراً
                        // ملاحظة: عند إلغاء التفعيل، يتم التحقق من الإعداد في Kotlin قبل عرض التذكير
                        if (val) {
                          try {
                            await ref
                                .read(prayerNotificationManagerProvider)
                                .manualReschedule();
                            debugPrint(
                              '✅ Notifications rescheduled after enabling prayer reminder',
                            );
                          } catch (e) {
                            debugPrint('⚠️ Error rescheduling: $e');
                          }
                        }
                      },
                    ),
                    _buildToggleRow(
                      icon: '',
                      title: 'تنبيه السحور',
                      subtitle: 'قبل الفجر بساعة',
                      value: settings.suhoorReminderEnabled,
                      onChanged: (val) async {
                        if (val) {
                          final hasPermission =
                              await NotificationPermissionService.hasPermission();
                          final hasLocation =
                              LocationService.instance.hasLocation;

                          if (!hasPermission || !hasLocation) {
                            _showPermissionRequiredDialog(
                              hasPermission,
                              hasLocation,
                            );
                            return;
                          }
                        }
                        notifier.setSuhoorReminder(val);

                        // إعادة جدولة الإشعارات فوراً
                        if (val) {
                          try {
                            await ref
                                .read(prayerNotificationManagerProvider)
                                .manualReschedule();
                            debugPrint(
                              '✅ Notifications rescheduled after enabling suhoor reminder',
                            );
                          } catch (e) {
                            debugPrint('⚠️ Error rescheduling: $e');
                          }
                        }
                      },
                    ),
                    _buildToggleRow(
                      icon: '',
                      title: 'تنبيه الإفطار',
                      subtitle: 'عند أذان المغرب',
                      value: settings.iftarReminderEnabled,
                      onChanged: (val) async {
                        if (val) {
                          final hasPermission =
                              await NotificationPermissionService.hasPermission();
                          final hasLocation =
                              LocationService.instance.hasLocation;

                          if (!hasPermission || !hasLocation) {
                            _showPermissionRequiredDialog(
                              hasPermission,
                              hasLocation,
                            );
                            return;
                          }
                        }
                        notifier.setIftarReminder(val);

                        // إعادة جدولة الإشعارات فوراً
                        if (val) {
                          try {
                            await ref
                                .read(prayerNotificationManagerProvider)
                                .manualReschedule();
                            debugPrint(
                              '✅ Notifications rescheduled after enabling iftar reminder',
                            );
                          } catch (e) {
                            debugPrint('⚠️ Error rescheduling: $e');
                          }
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // ═══ الأذان ═══
                    _buildSectionTitle('الأذان'),
                    _buildMuezzinSelector(settings, notifier),

                    const SizedBox(height: 16),

                    // ═══ القرآن الكريم ═══
                    _buildSectionTitle('القرآن الكريم'),
                    _buildSheikhSelector(settings, notifier),

                    const SizedBox(height: 16),

                    // ═══ معلومات التطبيق ═══
                    _buildSectionTitle('معلومات التطبيق'),
                    _buildAppGuideButton(),
                    _buildAzanDiagnosticsButton(),
                    _buildPrivacyPolicyButton(),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  UI Components
  // ══════════════════════════════════════════════════════════════

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomeScreen()),
            ),
            child: Container(
              width: 36.r,
              height: 36.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderGold),
                color: AppColors.goldWarm.withValues(alpha: 0.08),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.goldLight,
                size: 14.sp,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'الإعدادات',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 20,
                color: Color(0xFFE8D5B0),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 2,
              color: Color(0xFFC8922A),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFC8922A).withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required String icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF221A40).withOpacity(0.8),
        border: Border.all(color: const Color(0xFFC8922A).withOpacity(0.12)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFE8D5B0),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: const Color(0xFF9B8A6E).withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 50,
              height: 28,
              decoration: BoxDecoration(
                color: value
                    ? const Color(0xFFC8922A)
                    : const Color(0xFF9B8A6E).withOpacity(0.3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMuezzinSelector(
    SettingsState settings,
    SettingsNotifier notifier,
  ) {
    return Column(
      children: kMuezzins.map((muezzin) {
        final isSelected = settings.muezzinId == muezzin.id;
        return GestureDetector(
          onTap: () async {
            await notifier.setMuezzin(muezzin.id);
            
            // ✅ FIX: إعادة جدولة الأذانات فوراً بعد تغيير المؤذن
            if (LocationService.instance.hasLocation) {
              try {
                await ref
                    .read(prayerNotificationManagerProvider)
                    .manualReschedule();
                debugPrint('✅ Azans rescheduled after muezzin change');
              } catch (e) {
                debugPrint('⚠️ Error rescheduling after muezzin change: $e');
              }
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFC8922A).withOpacity(0.1)
                  : const Color(0xFF221A40).withOpacity(0.8),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFC8922A)
                    : const Color(0xFFC8922A).withOpacity(0.12),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFC8922A),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFFC8922A),
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    muezzin.name,
                    style: const TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 15,
                      color: Color(0xFFE8D5B0),
                    ),
                  ),
                ),
                // زر التشغيل
                IconButton(
                  onPressed: () =>
                      _playAzanPreview(muezzin.fileName, muezzin.id),
                  icon: const Icon(
                    Icons.play_circle_outline,
                    color: Color(0xFFC8922A),
                    size: 24,
                  ),
                ),
                // زر الإيقاف
                IconButton(
                  onPressed: _playingMuezzinId == muezzin.id
                      ? _stopAzanPreview
                      : null,
                  icon: Icon(
                    Icons.stop_circle_outlined,
                    color: _playingMuezzinId == muezzin.id
                        ? const Color(0xFFC8922A)
                        : const Color(0xFF9B8A6E).withValues(alpha: 0.3),
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSheikhSelector(
    SettingsState settings,
    SettingsNotifier notifier,
  ) {
    // حساب ارتفاع 3 مشايخ تقريباً
    const itemHeight = 70.0; // ارتفاع كل عنصر تقريباً
    const spacing = 8.0; // المسافة بين العناصر
    const maxVisibleItems = 3;
    final maxHeight =
        (itemHeight * maxVisibleItems) + (spacing * (maxVisibleItems - 1));

    return Stack(
      children: [
        // القائمة القابلة للتمرير
        Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFC8922A).withOpacity(0.12),
            ),
          ),
          child: Scrollbar(
            thumbVisibility: true,
            thickness: 4,
            radius: const Radius.circular(8),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: kSheikhs.length,
              itemBuilder: (context, index) {
                final sheikh = kSheikhs[index];
                final isSelected = settings.sheikId == sheikh.id;
                final isLast = index == kSheikhs.length - 1;

                return GestureDetector(
                  onTap: () => notifier.setSheikh(sheikh.id),
                  child: Container(
                    margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFC8922A).withOpacity(0.1)
                          : const Color(0xFF221A40).withOpacity(0.8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFC8922A)
                            : const Color(0xFFC8922A).withOpacity(0.12),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFC8922A),
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? Center(
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFC8922A),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sheikh.name,
                                style: const TextStyle(
                                  fontFamily: 'NotoNaskhArabic',
                                  fontSize: 15,
                                  color: Color(0xFFE8D5B0),
                                ),
                              ),
                              Text(
                                sheikh.style,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: const Color(
                                    0xFF9B8A6E,
                                  ).withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // تدرج في الأسفل يوحي بوجود محتوى إضافي
        if (kSheikhs.length > maxVisibleItems)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF130F2A).withOpacity(0.3),
                      const Color(0xFF130F2A).withOpacity(0.6),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFFC8922A),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  زر دليل الاستخدام
  // ══════════════════════════════════════════════════════════════
  Widget _buildAppGuideButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2640)),
      ),
      child: ListTile(
        leading: const Icon(
          Icons.menu_book_outlined,
          color: Color(0xFFC8922A),
          size: 24,
        ),
        title: const Text(
          'دليل الاستخدام',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: const Text(
          'تعرف على جميع مميزات التطبيق وكيفية استخدامها',
          style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Color(0xFF9E9E9E),
          size: 16,
        ),
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AppGuideScreen()));
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  زر تشخيص الأذان — المرحلة 8 (plan_azan_reliability.md)
  // ══════════════════════════════════════════════════════════════
  Widget _buildAzanDiagnosticsButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2640)),
      ),
      child: ListTile(
        leading: const Icon(
          Icons.health_and_safety_outlined,
          color: Color(0xFFC8922A),
          size: 24,
        ),
        title: const Text(
          'تشخيص الأذان',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: const Text(
          'حالة الجدولة، الأذونات، وآخر أذان أُطلق',
          style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Color(0xFF9E9E9E),
          size: 16,
        ),
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AzanDiagnosticsScreen()));
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  زر سياسة الخصوصية
  // ══════════════════════════════════════════════════════════════
  Widget _buildPrivacyPolicyButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2640)),
      ),
      child: ListTile(
        leading: const Icon(
          Icons.privacy_tip_outlined,
          color: Color(0xFFC8922A),
          size: 24,
        ),
        title: const Text(
          'سياسة الخصوصية',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: const Text(
          'اطلع على كيفية حماية بياناتك وخصوصيتك',
          style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Color(0xFF9E9E9E),
          size: 16,
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
          );
        },
      ),
    );
  }
}
