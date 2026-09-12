import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';

// ════════════════════════════════════════════════════════════════
//  App Guide Screen — دليل استخدام التطبيق
// ════════════════════════════════════════════════════════════════

class AppGuideScreen extends StatelessWidget {
  const AppGuideScreen({super.key});

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
              _buildHeader(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    const SizedBox(height: 16),

                    // مقدمة
                    _buildIntroSection(),
                    const SizedBox(height: 24),

                    // الشاشة الرئيسية
                    _buildSectionTitle('الشاشة الرئيسية'),
                    _buildFeatureCard(
                      title: 'التاريخ الهجري والميلادي',
                      description:
                          'يعرض التطبيق التاريخ الهجري والميلادي في أعلى الشاشة الرئيسية مع اليوم والشهر والسنة بشكل واضح.',
                    ),
                    _buildFeatureCard(
                      title: 'العد التنازلي للصلاة القادمة',
                      description:
                          'يظهر اسم الصلاة القادمة مع الوقت المتبقي لها بالساعات والدقائق، بالإضافة إلى شريط تقدم يوضح المدة المنقضية بين الصلاة الحالية والقادمة.',
                    ),
                    _buildFeatureCard(
                      title: 'الموقع الحالي',
                      description:
                          'يعرض اسم مدينتك الحالية، ويمكنك الضغط على أيقونة الموقع لتحديث موقعك تلقائياً باستخدام GPS أو اختيار مدينة يدوياً من القائمة.',
                    ),
                    _buildFeatureCard(
                      title: 'آية اليوم',
                      description:
                          'يعرض آية قرآنية مختارة يومياً مع اسم السورة ورقم الآية، يتم تحديثها تلقائياً كل يوم من خلال الخادم الخاص بنا.',
                    ),
                    _buildFeatureCard(
                      title: 'الإجراءات السريعة',
                      description:
                          'مجموعة من الأزرار السريعة للوصول المباشر إلى: القرآن الكريم، الأذكار، الأدعية، القبلة، أوقات الصلاة، ليلة القدر، السبحة، والإعدادات.',
                    ),
                    _buildFeatureCard(
                      title: 'ملخص التقدم',
                      description:
                          'يعرض إحصائيات تقدمك الشاملة: عدد الأيام المكتملة في رمضان، السور المقروءة، الأدعية المقروءة، وعدد التسبيحات. يحفظ التطبيق تقدمك على مدار العام ليرافقك في رحلتك الإيمانية.',
                    ),

                    const SizedBox(height: 24),

                    // القرآن الكريم
                    _buildSectionTitle('القرآن الكريم'),
                    _buildFeatureCard(
                      title: 'قراءة القرآن',
                      description:
                          'يوفر التطبيق قراءة كاملة للقرآن الكريم بخط عثماني واضح مع إمكانية التنقل بين السور والأجزاء والأحزاب.',
                    ),
                    _buildFeatureCard(
                      title: 'وضع القراءة',
                      description:
                          'يمكنك الاختيار بين وضع القراءة العادي (سطر سطر) أو وضع المصحف (صفحة كاملة) حسب تفضيلك.',
                    ),
                    _buildFeatureCard(
                      title: 'الاستماع للقرآن',
                      description:
                          'يمكنك الاستماع لتلاوة القرآن الكريم بصوت مشايخ مختلفين، مع إمكانية اختيار الشيخ المفضل من الإعدادات.',
                    ),
                    _buildFeatureCard(
                      title: 'تتبع الختمة',
                      description:
                          'يحفظ التطبيق تقدمك في قراءة القرآن ويعرض السور التي قرأتها، مع إمكانية تحديد السور كمقروءة أو غير مقروءة.',
                    ),
                    _buildFeatureCard(
                      title: 'البحث في القرآن',
                      description:
                          'يمكنك البحث عن أي كلمة أو آية في القرآن الكريم بسهولة، مع عرض النتائج مع السورة ورقم الآية.',
                    ),

                    const SizedBox(height: 24),

                    // المكتبة
                    _buildSectionTitle('المكتبة'),
                    _buildFeatureCard(
                      title: 'مكتبة الأحاديث الشاملة',
                      description:
                          'تحتوي المكتبة على مجموعة ضخمة من كتب الأحاديث النبوية الشريفة: صحيح البخاري (7563 حديث)، صحيح مسلم (7563 حديث)، سنن الترمذي (3956 حديث)، سنن أبي داود (5274 حديث)، سنن ابن ماجه (4341 حديث)، سنن النسائي (5758 حديث)، موطأ مالك (1594 حديث)، الأربعون القدسية (40 حديث)، ورياض الصالحين (1896 حديث).',
                    ),
                    _buildFeatureCard(
                      title: 'البحث في الأحاديث',
                      description:
                          'يمكنك البحث في أي حديث بسهولة عبر كتابة كلمة أو جملة، وسيعرض التطبيق جميع الأحاديث المطابقة مع اسم الكتاب والباب.',
                    ),
                    _buildFeatureCard(
                      title: 'التصفح حسب الأبواب',
                      description:
                          'كل كتاب مقسم إلى أبواب وفصول لتسهيل التصفح والوصول إلى الموضوع الذي تبحث عنه.',
                    ),
                    _buildFeatureCard(
                      title: 'نسخ الأحاديث',
                      description:
                          'يمكنك نسخ أي حديث بضغطة واحدة لمشاركته أو حفظه.',
                    ),
                    _buildFeatureCard(
                      title: 'التحميل التلقائي',
                      description:
                          'يتم تحميل الأحاديث تلقائياً عند فتح أي كتاب، مع نظام ذكي للتخزين المؤقت لتسريع التصفح.',
                    ),
                    _buildFeatureCard(
                      title: 'التقسيم الذكي',
                      description:
                          'يعرض التطبيق 20 حديثاً في كل صفحة مع إمكانية التمرير لتحميل المزيد تلقائياً، لضمان سرعة الأداء حتى مع الكتب الضخمة.',
                    ),

                    const SizedBox(height: 24),

                    // الأذكار والأدعية
                    _buildSectionTitle('الأذكار والأدعية'),
                    _buildFeatureCard(
                      title: 'أذكار الصباح والمساء',
                      description:
                          'مجموعة كاملة من أذكار الصباح والمساء مع عدد التكرار لكل ذكر، ويمكنك تحديد الأذكار المكتملة.',
                    ),
                    _buildFeatureCard(
                      title: 'أذكار متنوعة',
                      description:
                          'أذكار النوم، الاستيقاظ، دخول المسجد، الخروج من المسجد، الوضوء، وأذكار أخرى مهمة.',
                    ),
                    _buildFeatureCard(
                      title: 'أدعية رمضان',
                      description:
                          'مجموعة من الأدعية المأثورة الخاصة بشهر رمضان المبارك، مع إمكانية تحديد الأدعية المقروءة.',
                    ),
                    _buildFeatureCard(
                      title: 'أدعية القرآن',
                      description:
                          'الأدعية الواردة في القرآن الكريم مع ذكر السورة ورقم الآية.',
                    ),
                    _buildFeatureCard(
                      title: 'أدعية الأنبياء',
                      description:
                          'أدعية الأنبياء والرسل عليهم السلام كما وردت في القرآن والسنة.',
                    ),

                    const SizedBox(height: 24),

                    // أوقات الصلاة
                    _buildSectionTitle('أوقات الصلاة'),
                    _buildFeatureCard(
                      title: 'حساب دقيق لأوقات الصلاة',
                      description:
                          'يحسب التطبيق أوقات الصلاة الخمس بدقة عالية بناءً على موقعك الجغرافي باستخدام الطريقة المصرية للحساب.',
                    ),
                    _buildFeatureCard(
                      title: 'عرض جميع الأوقات',
                      description:
                          'يعرض أوقات الفجر، الشروق، الظهر، العصر، المغرب، والعشاء مع الوقت المتبقي لكل صلاة.',
                    ),
                    _buildFeatureCard(
                      title: 'الأذان التلقائي',
                      description:
                          'يؤذن التطبيق تلقائياً عند دخول وقت كل صلاة، مع إمكانية اختيار صوت المؤذن المفضل من الإعدادات.',
                    ),
                    _buildFeatureCard(
                      title: 'تذكير قبل الصلاة',
                      description:
                          'يمكنك تفعيل تذكير قبل كل صلاة بـ 15 دقيقة من الإعدادات.',
                    ),
                    _buildFeatureCard(
                      title: 'تنبيه السحور والإفطار',
                      description:
                          'يمكنك تفعيل تنبيه السحور (قبل الفجر بساعة) وتنبيه الإفطار (عند أذان المغرب) من الإعدادات.',
                    ),

                    const SizedBox(height: 24),

                    // القبلة
                    _buildSectionTitle('اتجاه القبلة'),
                    _buildFeatureCard(
                      title: 'البوصلة الذكية',
                      description:
                          'يوفر التطبيق بوصلة دقيقة تحدد اتجاه القبلة بناءً على موقعك الحالي باستخدام حساسات الجهاز.',
                    ),
                    _buildFeatureCard(
                      title: 'المسافة إلى الكعبة',
                      description:
                          'يعرض المسافة بينك وبين الكعبة المشرفة بالكيلومترات.',
                    ),
                    _buildFeatureCard(
                      title: 'معايرة البوصلة',
                      description:
                          'إذا كانت البوصلة غير دقيقة، يمكنك معايرتها بتحريك الجهاز على شكل رقم 8 في الهواء.',
                    ),

                    const SizedBox(height: 24),

                    // السبحة الإلكترونية
                    _buildSectionTitle('السبحة الإلكترونية'),
                    _buildFeatureCard(
                      title: 'العد التلقائي',
                      description:
                          'اضغط على الشاشة للعد، ويحفظ التطبيق عدد التسبيحات تلقائياً.',
                    ),
                    _buildFeatureCard(
                      title: 'الاهتزاز',
                      description:
                          'يهتز الجهاز عند كل ضغطة لتأكيد العد، مع إمكانية تعطيل الاهتزاز من الإعدادات.',
                    ),
                    _buildFeatureCard(
                      title: 'إعادة التعيين',
                      description:
                          'يمكنك إعادة تعيين العداد إلى الصفر في أي وقت.',
                    ),
                    _buildFeatureCard(
                      title: 'الإحصائيات',
                      description:
                          'يحفظ التطبيق إجمالي عدد التسبيحات على مدار الوقت.',
                    ),

                    const SizedBox(height: 24),

                    // ليلة القدر
                    _buildSectionTitle('ليلة القدر'),
                    _buildFeatureCard(
                      title: 'تتبع الليالي الوترية',
                      description:
                          'يعرض التطبيق الليالي الوترية المحتملة لليلة القدر (21، 23، 25، 27، 29) مع تمييز الليلة الحالية.',
                    ),
                    _buildFeatureCard(
                      title: 'أدعية ليلة القدر',
                      description:
                          'يوفر مجموعة من الأدعية المستحبة في ليلة القدر.',
                    ),
                    _buildFeatureCard(
                      title: 'فضائل ليلة القدر',
                      description:
                          'معلومات عن فضل ليلة القدر وعلاماتها.',
                    ),

                    const SizedBox(height: 24),

                    // التقدم والإحصائيات
                    _buildSectionTitle('التقدم والإحصائيات'),
                    _buildFeatureCard(
                      title: 'تتبع تقدم رمضان',
                      description:
                          'يعرض عدد الأيام المكتملة من رمضان مع نسبة الإنجاز، ويحفظ تقدمك للسنوات القادمة.',
                    ),
                    _buildFeatureCard(
                      title: 'إحصائيات القرآن',
                      description:
                          'عدد السور المقروءة من أصل 114 سورة، يحفظ التطبيق تقدمك على مدار العام.',
                    ),
                    _buildFeatureCard(
                      title: 'إحصائيات الأدعية',
                      description:
                          'عدد الأدعية التي قرأتها، يتم حفظها بشكل دائم.',
                    ),
                    _buildFeatureCard(
                      title: 'إحصائيات التسبيح',
                      description:
                          'إجمالي عدد التسبيحات على مدار الوقت، يرافقك في رحلتك الإيمانية طوال العام.',
                    ),

                    const SizedBox(height: 24),

                    // الرسائل
                    _buildSectionTitle('الرسائل والإشعارات'),
                    _buildFeatureCard(
                      title: 'رسائل يومية',
                      description:
                          'يرسل التطبيق رسائل تحفيزية ونصائح دينية يومية من خلال السيرفر الخاص بنا.',
                    ),
                    _buildFeatureCard(
                      title: 'رسائل المساعدة الإنسانية',
                      description:
                          'قد نرسل مستقبلاً رسائل عن حالات إنسانية حقيقية وموثوقة تحتاج للمساعدة، لمن أراد التواصل معهم مباشرة والمساهمة في دعمهم.',
                    ),
                    _buildFeatureCard(
                      title: 'الإشعارات',
                      description:
                          'تصلك إشعارات عند دخول وقت الصلاة، وتذكيرات السحور والإفطار، والرسائل اليومية.',
                    ),

                    const SizedBox(height: 24),

                    // فلسفة التطبيق
                    _buildSectionTitle('فلسفة التطبيق'),
                    _buildFeatureCard(
                      title: 'رفيقك طوال العام',
                      description:
                          'نور رمضان ليس مجرد تطبيق لشهر رمضان، بل هو صديقك المخلص الذي يرافقك في رحلة التقرب إلى الله على مدار العام. يحفظ تقدمك في رمضان ويواصل تذكيرك بالعبادات حتى يأتي رمضان القادم.',
                    ),
                    _buildFeatureCard(
                      title: 'تصميم عصري وممتع',
                      description:
                          'صُمم التطبيق بعناية فائقة ليكون عصرياً وممتعاً في الاستخدام، مع واجهة جميلة ورسوم متحركة سلسة، حتى لا تمل من استخدامه اليومي.',
                    ),
                    _buildFeatureCard(
                      title: 'مجاني بالكامل وغير ربحي',
                      description:
                          'التطبيق مجاني تماماً وغير ربحي، هدفنا الوحيد هو مساعدتك في التقرب إلى الله وتسهيل عباداتك.',
                    ),
                    _buildFeatureCard(
                      title: 'خصوصيتك أولاً',
                      description:
                          'جميع بياناتك محفوظة محلياً على جهازك فقط، لا نشارك أي معلومات مع أطراف خارجية.',
                    ),

                    const SizedBox(height: 24),

                    // الإعدادات
                    _buildSectionTitle('الإعدادات'),
                    _buildFeatureCard(
                      title: 'اختيار المؤذن',
                      description:
                          'يمكنك اختيار صوت المؤذن المفضل من بين عدة مؤذنين: عبد الباسط عبد الصمد، محمد الجازي، ناصر القطامي.',
                    ),
                    _buildFeatureCard(
                      title: 'اختيار القارئ',
                      description:
                          'يمكنك اختيار صوت القارئ المفضل للاستماع للقرآن من بين عدة قراء مشهورين.',
                    ),
                    _buildFeatureCard(
                      title: 'التذكيرات',
                      description:
                          'تفعيل أو تعطيل: تذكير قبل الصلاة بـ 15 دقيقة، تنبيه السحور، تنبيه الإفطار.',
                    ),
                    _buildFeatureCard(
                      title: 'تغيير الموقع',
                      description:
                          'يمكنك تغيير موقعك في أي وقت من خلال الضغط على أيقونة الموقع في الشاشة الرئيسية.',
                    ),

                    const SizedBox(height: 24),

                    // نصائح الاستخدام
                    _buildSectionTitle('نصائح للاستخدام الأمثل'),
                    _buildTipCard(
                      'تأكد من تفعيل الإشعارات للحصول على تنبيهات الصلاة والأذان في الوقت المحدد.',
                    ),
                    _buildTipCard(
                      'حدد موقعك بدقة باستخدام GPS للحصول على أوقات صلاة دقيقة.',
                    ),
                    _buildTipCard(
                      'استخدم وضع عدم الإزعاج في الجهاز بحذر، فقد يمنع وصول إشعارات الأذان.',
                    ),
                    _buildTipCard(
                      'تأكد من عدم تفعيل توفير الطاقة للتطبيق لضمان عمل الأذان في الخلفية.',
                    ),
                    _buildTipCard(
                      'يمكنك استخدام التطبيق بدون إنترنت بعد التحميل الأولي، ما عدا الرسائل اليومية وآية اليوم التي تحتاج اتصال بالإنترنت للتحديث.',
                    ),
                    _buildTipCard(
                      'التطبيق يحفظ تقدمك تلقائياً، لا تقلق من فقدان بياناتك.',
                    ),
                    _buildTipCard(
                      'استخدم التطبيق يومياً ليصبح جزءاً من روتينك الإيماني.',
                    ),

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
              'دليل الاستخدام',
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
          const Text(
            'مرحباً بك في تطبيق نور رمضان',
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
            'صديقك المخلص في رحلة التقرب إلى الله. تطبيق شامل ومجاني بالكامل يرافقك في شهر رمضان المبارك وما بعده، يحفظ تقدمك ويذكرك بالعبادات على مدار العام. مصمم بشكل عصري وممتع ليكون رفيقك الدائم في طريق الخير.',
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

  Widget _buildFeatureCard({
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
          const SizedBox(height: 8),
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
    );
  }

  Widget _buildTipCard(String tip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFC8922A).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFC8922A).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
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
              tip,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13,
                color: const Color(0xFFE8D5B0).withValues(alpha: 0.8),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
