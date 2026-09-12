import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/remote_config_service.dart';

// ════════════════════════════════════════════════════════════════
//  Privacy Policy Screen — صفحة سياسة الخصوصية
// ════════════════════════════════════════════════════════════════

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  final _remoteConfigService = RemoteConfigService();
  String _websiteUrl = 'https://code-zeen.vercel.app/en'; // الافتراضي

  @override
  void initState() {
    super.initState();
    _loadWebsiteUrl();
    _listenToUpdates();
  }

  /// تحميل رابط الموقع من Firebase أو Cache
  Future<void> _loadWebsiteUrl() async {
    final url = await _remoteConfigService.getWebsiteUrl();
    if (mounted) {
      setState(() {
        _websiteUrl = url;
      });
    }
  }

  /// الاستماع للتحديثات الفورية من Firebase
  void _listenToUpdates() {
    _remoteConfigService.listenToUpdates((newUrl) {
      if (mounted) {
        setState(() {
          _websiteUrl = newUrl;
        });
        // إظهار رسالة للمستخدم
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'تم تحديث رابط الموقع',
              style: TextStyle(fontFamily: 'Tajawal'),
            ),
            backgroundColor: const Color(0xFFC8922A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _launchEmail(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'codezeeen@gmail.com',
      query: 'subject=${Uri.encodeComponent('استفسار عن تطبيق نور رمضان')}',
    );

    try {
      final canLaunch = await canLaunchUrl(emailUri);
      if (canLaunch) {
        await launchUrl(
          emailUri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        // إذا لم يكن هناك تطبيق بريد، انسخ البريد
        await Clipboard.setData(
          const ClipboardData(text: 'codezeeen@gmail.com'),
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'تم نسخ البريد الإلكتروني',
              style: TextStyle(fontFamily: 'Tajawal'),
            ),
            backgroundColor: const Color(0xFFC8922A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error launching email: $e');
      // في حالة الخطأ، انسخ البريد
      await Clipboard.setData(
        const ClipboardData(text: 'codezeeen@gmail.com'),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'تم نسخ البريد الإلكتروني',
            style: TextStyle(fontFamily: 'Tajawal'),
          ),
          backgroundColor: const Color(0xFFC8922A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _launchWebsite(BuildContext context) async {
    try {
      final Uri websiteUri = Uri.parse(_websiteUrl);
      debugPrint('🌐 Attempting to launch: $_websiteUrl');
      
      // محاولة فتح الرابط مباشرة
      final launched = await launchUrl(
        websiteUri,
        mode: LaunchMode.externalApplication,
      );
      
      if (!launched) {
        debugPrint('⚠️ launchUrl returned false');
        if (!context.mounted) return;
        _showErrorSnackBar(context, 'تعذر فتح الموقع');
      } else {
        debugPrint('✅ Website launched successfully');
      }
    } catch (e) {
      debugPrint('❌ Error launching website: $e');
      if (!context.mounted) return;
      _showErrorSnackBar(context, 'حدث خطأ أثناء فتح الموقع');
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Tajawal'),
        ),
        backgroundColor: const Color(0xFFC8922A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    const SizedBox(height: 16),

                    // مقدمة
                    _buildIntroSection(),
                    const SizedBox(height: 24),

                    // البيانات التي نجمعها
                    _buildSectionTitle('البيانات التي نجمعها'),
                    _buildInfoCard(
                      icon: Icons.location_on_outlined,
                      title: 'بيانات الموقع',
                      description:
                          'نستخدم موقعك الجغرافي فقط لحساب أوقات الصلاة الدقيقة واتجاه القبلة. لا نشارك هذه البيانات مع أي طرف ثالث.',
                    ),
                    _buildInfoCard(
                      icon: Icons.notifications_outlined,
                      title: 'الإشعارات',
                      description:
                          'نرسل إشعارات محلية على جهازك لتذكيرك بأوقات الصلاة والأذكار. جميع الإشعارات تتم معالجتها محلياً على جهازك.',
                    ),
                    _buildInfoCard(
                      icon: Icons.storage_outlined,
                      title: 'البيانات المحلية',
                      description:
                          'نحفظ تقدمك في قراءة القرآن والأذكار والتسبيح محلياً على جهازك فقط. لا يتم رفع هذه البيانات إلى أي خادم.',
                    ),

                    const SizedBox(height: 24),

                    // كيف نستخدم بياناتك
                    _buildSectionTitle('كيف نستخدم بياناتك'),
                    _buildBulletPoint('حساب أوقات الصلاة الدقيقة بناءً على موقعك'),
                    _buildBulletPoint('إرسال تذكيرات الصلاة والأذكار'),
                    _buildBulletPoint('حفظ تقدمك في العبادات'),
                    _buildBulletPoint('تحسين تجربة استخدام التطبيق'),

                    const SizedBox(height: 24),

                    // الأذونات المطلوبة
                    _buildSectionTitle('الأذونات المطلوبة'),
                    _buildPermissionCard(
                      icon: Icons.location_on,
                      title: 'الموقع',
                      description: 'لحساب أوقات الصلاة واتجاه القبلة',
                    ),
                    _buildPermissionCard(
                      icon: Icons.notifications,
                      title: 'الإشعارات',
                      description: 'لتذكيرك بأوقات الصلاة والأذكار',
                    ),
                    _buildPermissionCard(
                      icon: Icons.vibration,
                      title: 'الاهتزاز',
                      description: 'لتفعيل الاهتزاز عند استخدام السبحة',
                    ),

                    const SizedBox(height: 24),

                    // التواصل معنا
                    _buildSectionTitle('التواصل معنا'),
                    _buildContactCard(context),

                    const SizedBox(height: 16),

                    // رابط الموقع
                    _buildWebsiteCard(context),

                    const SizedBox(height: 24),

                    // ملاحظة ختامية
                    _buildFooterNote(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
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
              'سياسة الخصوصية',
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

  Widget _buildIntroSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF221A40).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFC8922A).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.security_rounded,
            color: const Color(0xFFC8922A),
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'خصوصيتك مهمة بالنسبة لنا',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 18,
              color: Color(0xFFE8D5B0),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'تطبيق نور رمضان يحترم خصوصيتك ويحمي بياناتك. جميع البيانات تُحفظ محلياً على جهازك ولا نشاركها مع أي طرف ثالث.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 14,
              color: const Color(0xFFE8D5B0).withValues(alpha: 0.8),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFFC8922A),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 16,
              color: Color(0xFFC8922A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF221A40).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFC8922A).withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFC8922A).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFC8922A),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'NotoNaskhArabic',
                    fontSize: 15,
                    color: Color(0xFFE8D5B0),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    color: const Color(0xFFE8D5B0).withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFFC8922A),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14,
                color: const Color(0xFFE8D5B0).withValues(alpha: 0.8),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF221A40).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFC8922A).withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFFC8922A),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'NotoNaskhArabic',
                    fontSize: 14,
                    color: Color(0xFFE8D5B0),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    color: const Color(0xFFE8D5B0).withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFC8922A).withValues(alpha: 0.15),
            const Color(0xFFC8922A).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFC8922A).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.email_outlined,
            color: Color(0xFFC8922A),
            size: 36,
          ),
          const SizedBox(height: 12),
          const Text(
            'لديك استفسار أو اقتراح؟',
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 15,
              color: Color(0xFFE8D5B0),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'نسعد بتواصلك معنا عبر البريد الإلكتروني',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 13,
              color: const Color(0xFFE8D5B0).withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _launchEmail(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFC8922A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.mail,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'codezeeen@gmail.com',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebsiteCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _launchWebsite(context),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF221A40).withValues(alpha: 0.6),
              const Color(0xFF221A40).withValues(alpha: 0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFC8922A).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.language_rounded,
              color: Color(0xFFC8922A),
              size: 24,
            ),
            const SizedBox(width: 12),
            const Text(
              'Code Zeen',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 16,
                color: Color(0xFFE8D5B0),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: const Color(0xFFC8922A).withValues(alpha: 0.6),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF221A40).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFC8922A).withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: const Color(0xFFC8922A).withValues(alpha: 0.7),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'آخر تحديث: فبراير 2025 • نحتفظ بالحق في تحديث هذه السياسة',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11,
                color: const Color(0xFFE8D5B0).withValues(alpha: 0.5),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
