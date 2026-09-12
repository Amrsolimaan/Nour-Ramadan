import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/offline_quran_service.dart';
import '../../../core/services/local_quran_service.dart';
import '../../../core/services/last_read_service.dart';
import '../../../core/services/quran_service.dart' show QuranDataService;
import '../providers/last_read_provider.dart';
import '../providers/auto_resume_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../widgets/surah_header_widget.dart';
import '../widgets/justified_quran_text.dart';
import '../widgets/paragraph_quran_text.dart';

// ════════════════════════════════════════════════════════════════
//  ModernQuranReaderV2 — قارئ المصحف Offline-First
//  ✅ إصلاح Overflow في أزرار التحكم
//  ✅ إصلاح قص النصوص — جميع النصوص تظهر كاملة
// ════════════════════════════════════════════════════════════════

class ModernQuranReaderV2 extends ConsumerStatefulWidget {
  final int surahNumber;
  final int? initialAyah;

  /// @deprecated تم إلغاء التقدّم التلقائي نهائياً — التذييل الآن يدوي فقط.
  /// الحقل مُبقى للتوافق مع مداخل الحفظ (hifz_today_review / hifz_juz_detail)
  /// التي تمرّر `disableAutoAdvance: true`، لكنه لم يعد يُستخدم.
  final bool disableAutoAdvance;

  const ModernQuranReaderV2({
    super.key,
    required this.surahNumber,
    this.initialAyah,
    this.disableAutoAdvance = false,
  });

  @override
  ConsumerState<ModernQuranReaderV2> createState() =>
      _ModernQuranReaderV2State();
}

class _ModernQuranReaderV2State extends ConsumerState<ModernQuranReaderV2> {
  final AudioPlayer _player = AudioPlayer();
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _ayahKeys = {};

  List<LocalAyah> _ayahs = [];
  SurahInfo? _surahInfo;
  bool _isLoading = true;
  String? _error;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _isParagraphMode = true;

  int? _selStart;
  int? _selEnd;

  int _playingAyah = 0;
  bool _isPlaying = false;
  bool _isLoadingAudio = false;
  bool _repeatEnabled = false;
  bool _isPaused = false;

  // ── تسلسل التشغيل الصوتي (إصلاح تداخل الصوت — Phase A) ─────────
  /// رمز الجيل: كل بدء/إيقاف يزيده. أي عملية غير متزامنة تابعة لتشغيل
  /// قديم تتحقق منه بعد كل await وتنسحب إن لم تعد هي التشغيل الحالي.
  int _playbackEpoch = 0;

  /// Future الخاص بحلقة التشغيل الجارية — يُنتظَر فعلياً عند الإيقاف/البدء.
  Future<void>? _playbackLoop;

  /// يُضبط في dispose لمنع أي وصول لاحق إلى _player بعد التخلص منه.
  bool _disposed = false;

  int? _currentVisibleAyah;

  // ── "آخر قراءة" ───────────────────────────────────────────────
  Timer? _lastReadSaveTimer;
  LastReadPosition? _pendingLastRead;

  /// الآية التي توقف عندها المستخدم آخر مرة — تُقرأ مرة واحدة عند
  /// فتح السورة وتُستخدم لعرض علامة خفيفة في القارئ
  int? _lastReadAyahMarker;

  @override
  void initState() {
    super.initState();
    _loadSurah();
  }

  @override
  void dispose() {
    _disposed = true;
    _playbackEpoch++; // إبطال أي حلقة تشغيل معلّقة قبل التخلص من المشغّل
    // ✅ إلغاء مؤقّت التأجيل مع حفظ فوري لأي موضع لم يُخزَّن بعد
    _lastReadSaveTimer?.cancel();
    _flushPendingLastRead();
    _player.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSurah() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(offlineQuranServiceProvider);
      _surahInfo = await service.getSurahInfo(widget.surahNumber);
      _ayahs = await service.getSurahAyahs(widget.surahNumber);

      if (_ayahs.isEmpty) {
        _error = 'لم يتم العثور على آيات لهذه السورة';
      } else {
        for (var ayah in _ayahs) {
          _ayahKeys[ayah.numberInSurah] = GlobalKey();
        }

        // علامة "آخر قراءة" اليدوية — للشارة والتظليل
        _lastReadAyahMarker =
            ref.read(lastReadProvider).ayahForSurah(widget.surahNumber);

        // أولوية الفتح الثابتة: initialAyah > يدوي > تلقائي لكل سورة > 1
        final autoAyah =
            ref.read(autoResumeProvider).ayahForSurah(widget.surahNumber);

        if (widget.initialAyah != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToAyah(widget.initialAyah!);
          });
        } else if (_lastReadAyahMarker != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToAyah(_lastReadAyahMarker!);
          });
        } else if (autoAyah != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToAyah(autoAyah, select: false);
          });
        }
      }
    } catch (e) {
      _error = 'خطأ في تحميل السورة: $e';
      debugPrint('❌ خطأ في تحميل السورة: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _scrollToAyah(int ayahNumber, {bool select = true}) {
    final key = _ayahKeys[ayahNumber];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.2,
      );
      if (select) {
        setState(() {
          _selStart = ayahNumber;
          _selEnd = ayahNumber;
        });
      }
    }
  }

  bool _isSelected(int ayahNum) {
    if (_selStart == null) return false;
    final end = _selEnd ?? _selStart!;
    final mn = _selStart! < end ? _selStart! : end;
    final mx = _selStart! < end ? end : _selStart!;
    return ayahNum >= mn && ayahNum <= mx;
  }

  Map<String, int> _getCurrentPageInfo() {
    if (_ayahs.isEmpty) return {'page': 0, 'juz': 0, 'hizb': 0};

    if (_playingAyah > 0 && _playingAyah <= _ayahs.length) {
      final ayah = _ayahs[_playingAyah - 1];
      return {
        'page': ayah.pageNumber,
        'juz': ayah.juzNumber,
        'hizb': ayah.hizbNumber,
      };
    }
    if (_selStart != null && _selStart! <= _ayahs.length) {
      final ayah = _ayahs[_selStart! - 1];
      return {
        'page': ayah.pageNumber,
        'juz': ayah.juzNumber,
        'hizb': ayah.hizbNumber,
      };
    }
    if (_currentVisibleAyah != null && _currentVisibleAyah! <= _ayahs.length) {
      final ayah = _ayahs[_currentVisibleAyah! - 1];
      return {
        'page': ayah.pageNumber,
        'juz': ayah.juzNumber,
        'hizb': ayah.hizbNumber,
      };
    }
    return {
      'page': _ayahs.first.pageNumber,
      'juz': _ayahs.first.juzNumber,
      'hizb': _ayahs.first.hizbNumber,
    };
  }

  void _updateVisibleAyah(int ayahNumber) {
    if (_currentVisibleAyah != ayahNumber) {
      setState(() => _currentVisibleAyah = ayahNumber);
    }
    _scheduleLastReadSave(ayahNumber);
  }

  // ══════════════════════════════════════════════════════════════
  //  حفظ تلقائي للاستئناف — تأجيل (debounce) ~800ms ثم كتابة في Hive
  //  يكتب فقط في auto_resume (لكل سورة) ولا يمس الشارة اليدوية أبداً
  // ══════════════════════════════════════════════════════════════
  void _scheduleLastReadSave(int ayahNumber) {
    if (ayahNumber < 1 || ayahNumber > _ayahs.length) return;

    final ayah = _ayahs[ayahNumber - 1];
    _pendingLastRead = LastReadPosition(
      surahNumber: widget.surahNumber,
      ayahNumber: ayah.numberInSurah,
      pageNumber: ayah.pageNumber,
      juzNumber: ayah.juzNumber,
      updatedAt: DateTime.now(),
    );

    _lastReadSaveTimer?.cancel();
    _lastReadSaveTimer = Timer(
      const Duration(milliseconds: 800),
      _flushPendingLastRead,
    );
  }

  void _flushPendingLastRead() {
    _lastReadSaveTimer?.cancel();
    _lastReadSaveTimer = null;

    final pending = _pendingLastRead;
    if (pending == null) return;
    _pendingLastRead = null;

    ref.read(autoResumeProvider.notifier).savePosition(pending);
  }

  bool _isEndOfPage(LocalAyah ayah, int index) {
    if (index >= _ayahs.length - 1)
      return false; // آخر آية نتعامل معها بشكل منفصل
    return _ayahs[index + 1].pageNumber != ayah.pageNumber;
  }

  Widget _buildPageDivider(LocalAyah currentAyah, int index) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16.h),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: AppColors.goldWarm.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: AppColors.goldWarm.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Text(
              'الصفحة ${currentAyah.pageNumber}',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13.sp,
                color: AppColors.mushafInk,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Container(
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.goldWarm.withValues(alpha: 0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          SizedBox(height: 4.h),
          Container(
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.goldWarm.withValues(alpha: 0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onAyahTap(int ayahNum) {
    if (_isPlaying) return;
    setState(() {
      if (_selStart == null) {
        _selStart = ayahNum;
        _selEnd = ayahNum;
      } else if (_selStart == ayahNum && _selEnd == ayahNum) {
        _selStart = null;
        _selEnd = null;
      } else if (_selEnd == ayahNum) {
        if (_selStart == _selEnd) {
          _selStart = null;
          _selEnd = null;
        } else {
          if (_selStart! < _selEnd!) {
            _selEnd = _selEnd! - 1;
          } else {
            _selEnd = _selEnd! + 1;
          }
        }
      } else if (_selStart == ayahNum) {
        if (_selStart == _selEnd) {
          _selStart = null;
          _selEnd = null;
        } else {
          if (_selStart! < _selEnd!) {
            _selStart = _selStart! + 1;
          } else {
            _selStart = _selStart! - 1;
          }
        }
      } else {
        _selEnd = ayahNum;
      }
    });
  }

  void _onAyahLongPress(int ayahNum) {
    if (_isPlaying) return;
    setState(() {
      _selStart = ayahNum;
      _selEnd = ayahNum;
    });
  }

  void _clearSelection() async {
    if (_isPlaying) await _stopPlayback();
    setState(() {
      _selStart = null;
      _selEnd = null;
    });
  }

  Future<void> _playFullSurah() async {
    if (_ayahs.isEmpty) return;
    if (_isPaused) {
      await _resumePlayback();
      return;
    }
    if (_isPlaying) return;
    setState(() {
      _selStart = null;
      _selEnd = null;
    });
    await _startPlayback((epoch) => _playAyahRange(1, _ayahs.length, epoch));
  }

  // مُشغّل النطاق المُحدَّد بالنقر — يحسب [from..to] من _selStart/_selEnd
  // ثم يمرّ عبر نفس المُنسّق والحلقة الموحّدة (مثل _playFullSurah تماماً).
  Future<void> _playSelection() async {
    if (_selStart == null) return;
    final end = _selEnd ?? _selStart!;
    final from = _selStart! < end ? _selStart! : end;
    final to = _selStart! < end ? end : _selStart!;
    await _startPlayback((epoch) => _playAyahRange(from, to, epoch));
  }

  Future<void> _pausePlayback() async {
    if (!_isPlaying || _isPaused) return;
    final epoch = _playbackEpoch;
    setState(() => _isPaused = true);
    try {
      await _player.pause();
    } catch (_) {}
    // إذا جرى إيقاف/بدء جديد أثناء الانتظار، تراجع عن حالة الإيقاف المؤقت
    if (epoch != _playbackEpoch && mounted) {
      setState(() => _isPaused = false);
    }
  }

  Future<void> _resumePlayback() async {
    if (!_isPaused) return;
    final epoch = _playbackEpoch;
    setState(() => _isPaused = false);
    if (epoch != _playbackEpoch || _disposed) return;
    try {
      await _player.play();
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════
  //  مُنسّق التشغيل — يوقف الحالي، ينتظر تفكيك الحلقة السابقة فعلياً،
  //  ثم يُطلق حلقة جديدة ويحفظ Future الخاص بها.
  // ══════════════════════════════════════════════════════════════
  Future<void> _startPlayback(
    Future<void> Function(int epoch) loopBuilder,
  ) async {
    final epoch = ++_playbackEpoch; // يُبطل أي حلقة قديمة فوراً
    if (_disposed) return;

    try {
      await _player.stop();
    } catch (_) {}

    // انتظار انسحاب الحلقة السابقة بالكامل قبل تشغيل مصدر جديد
    final previous = _playbackLoop;
    if (previous != null) {
      try {
        await previous;
      } catch (_) {}
    }

    // إذا بدأ تشغيل/إيقاف أحدث أثناء الانتظار، فهذه الدعوة قديمة
    if (_disposed || epoch != _playbackEpoch) return;

    _playbackLoop = loopBuilder(epoch);
  }

  /// إنهاء التشغيل من داخل الحلقة نفسها.
  /// لا ينتظر [_playbackLoop] (لأننا داخله) تفادياً للتجمّد.
  Future<void> _abortPlaybackFromLoop(int epoch) async {
    if (_disposed || epoch != _playbackEpoch) return;
    try {
      await _player.stop();
    } catch (_) {}
    if (_disposed || epoch != _playbackEpoch) return;
    _resetPlaybackState();
  }

  void _resetPlaybackState() {
    if (!mounted) return;
    setState(() {
      _playingAyah = 0;
      _isPlaying = false;
      _isLoadingAudio = false;
      _isPaused = false;
    });
  }

  // ══════════════════════════════════════════════════════════════
  //  _awaitAyahCompletion — انتظار انتهاء تلاوة الآية الحالية عبر
  //  playerStateStream، بديلاً عن استطلاع الـ 50ms في Phase A.
  //
  //  لا يمكن أن يتجمّد:
  //   • يُحلّ عند completed أو idle (idle يغطّي stop() الخارجي من _stopPlayback)
  //   • يفحص epoch/_disposed داخل مستمع البث عند كل إصدار حالة
  //   • مؤقّت أمان دوري (50ms) يفحص epoch/_disposed حتى لو لم يُصدر
  //     المشغّل أي حالة جديدة بعد إيقاف خارجي
  //   • الاشتراك يُلغى دائماً في finally
  // ══════════════════════════════════════════════════════════════
  Future<void> _awaitAyahCompletion(int epoch) async {
    if (epoch != _playbackEpoch || _disposed) return;

    final completer = Completer<void>();
    StreamSubscription<PlayerState>? sub;
    Timer? epochWatch;

    void finish() {
      if (!completer.isCompleted) completer.complete();
    }

    try {
      sub = _player.playerStateStream.listen(
        (state) {
          final ps = state.processingState;
          if (ps == ProcessingState.completed ||
              ps == ProcessingState.idle ||
              epoch != _playbackEpoch ||
              _disposed) {
            finish();
          }
        },
        onError: (_) => finish(),
        onDone: finish,
      );

      // شبكة أمان: إيقاف خارجي قد لا يُتبع بأي إصدار حالة جديد
      epochWatch = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (epoch != _playbackEpoch || _disposed) finish();
      });

      // فحص فوري لحالة نهائية سابقة لبدء الاستماع
      final current = _player.playerState.processingState;
      if (current == ProcessingState.completed ||
          current == ProcessingState.idle) {
        finish();
      }

      await completer.future;
    } finally {
      epochWatch?.cancel();
      await sub?.cancel();
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  _playAyahRange — الحلقة الموحّدة الوحيدة لتشغيل نطاق آيات.
  //  تُستدعى فقط عبر _startPlayback من _playFullSurah و _playSelection.
  //  [epoch]: أي عدم تطابق مع _playbackEpoch بعد أي await يعني أن هذه
  //  الحلقة أصبحت قديمة فتنسحب فوراً (ضمانات Phase A محفوظة كاملة).
  // ══════════════════════════════════════════════════════════════
  Future<void> _playAyahRange(int from, int to, int epoch) async {
    final service = ref.read(offlineQuranServiceProvider);
    final settings = ref.read(settingsProvider);
    final delay = settings.ayahDelay;

    bool hasShownNoInternetMessage = false;

    do {
      if (epoch != _playbackEpoch) return; // رأس كل دورة do/while
      if (mounted) {
        setState(() {
          _isPlaying = true;
          _isLoadingAudio = false;
        });
      }

      for (var i = from; i <= to; i++) {
        if (epoch != _playbackEpoch) return; // رأس كل تكرار for

        // انتظار الإيقاف المؤقت — يعمل الآن لكل الحالات (سورة كاملة أو تحديد)
        while (_isPaused) {
          if (epoch != _playbackEpoch) return;
          await Future.delayed(const Duration(milliseconds: 100));
        }
        if (epoch != _playbackEpoch) return;

        if (mounted) {
          setState(() {
            _playingAyah = i;
            _isLoadingAudio = true;
          });
        }

        _scrollToAyah(i, select: false);

        try {
          final audioResult = await service.getAyahAudio(
            surahNumber: widget.surahNumber,
            ayahNumber: i,
            reciter: settings.sheikh.reciterCode,
          );
          if (epoch != _playbackEpoch) return; // بعد getAyahAudio

          if (!audioResult.success) {
            if (audioResult.needsInternet &&
                mounted &&
                !hasShownNoInternetMessage) {
              hasShownNoInternetMessage = true;
              _showNoInternetDialog(
                i > from
                    ? 'تم تشغيل ${i - from} آية/آيات من أصل ${to - from + 1}.\n\n${audioResult.errorMessage!}'
                    : audioResult.errorMessage!,
              );
              await _abortPlaybackFromLoop(epoch);
              return;
            }
            if (audioResult.needsInternet) {
              await _abortPlaybackFromLoop(epoch);
              return;
            }
            continue;
          }

          await _player.setFilePath(audioResult.file!.path);
          if (epoch != _playbackEpoch) return; // بعد setFilePath
          if (mounted) setState(() => _isLoadingAudio = false);
          await _player.play();
          if (epoch != _playbackEpoch) return; // بعد play

          // انتظار انتهاء الآية عبر بث حالة المشغّل (قابل للإلغاء)
          await _awaitAyahCompletion(epoch);
          if (epoch != _playbackEpoch) return; // بعد _awaitAyahCompletion
        } catch (e) {
          debugPrint('❌ خطأ في تشغيل الآية $i: $e');
          if (epoch != _playbackEpoch) return;
          if (mounted) setState(() => _isLoadingAudio = false);
        }

        if (i < to && epoch == _playbackEpoch && !_isPaused) {
          await Future.delayed(Duration(milliseconds: delay));
          if (epoch != _playbackEpoch) return; // بعد فاصل الآيات
        }
      }
    } while (_repeatEnabled && epoch == _playbackEpoch);

    if (mounted && epoch == _playbackEpoch) {
      setState(() {
        _playingAyah = 0;
        _isPlaying = false;
        _isLoadingAudio = false;
      });
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  إيقاف التشغيل — تفكيك مُنتظَر بالكامل:
  //  1) رفع _playbackEpoch لإبطال أي حلقة قيد التنفيذ فوراً
  //  2) await _player.stop()
  //  3) await _playbackLoop حتى تنسحب الحلقة القديمة فعلياً
  //  4) تصفير حالة الواجهة
  // ══════════════════════════════════════════════════════════════
  Future<void> _stopPlayback() async {
    _playbackEpoch++;
    if (_disposed) return;

    try {
      await _player.stop();
    } catch (_) {}

    final loop = _playbackLoop;
    if (loop != null) {
      try {
        await loop;
      } catch (_) {}
    }

    if (_disposed) return;
    _resetPlaybackState();
  }

  void _showNoInternetDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.mushafPaper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Row(
          children: [
            Icon(
              Icons.wifi_off_rounded,
              color: AppColors.goldWarm,
              size: 24.sp,
            ),
            SizedBox(width: 8.w),
            Text(
              'لا يوجد اتصال',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.mushafInk,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 14.sp,
            color: AppColors.textDim,
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'حسناً',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14.sp,
                color: AppColors.goldWarm,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  ✅ مساعد بناء زر التحكم — يضمن ظهور النص كاملاً بدون قص
  // ════════════════════════════════════════════════════════════════

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool highlighted,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.goldWarm.withValues(alpha: 0.15)
            : AppColors.goldWarm.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: AppColors.goldWarm.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(icon, size: 17.sp, color: AppColors.goldWarm),
          SizedBox(width: 5.w),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 12.sp,
              color: AppColors.mushafInk,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  واجهة المستخدم
  // ════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final sheikh = settings.sheikh;

    return Scaffold(
      backgroundColor: AppColors.mushafPaper,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.goldWarm),
            )
          : _error != null
          ? _buildError()
          : Stack(
              children: [
                Column(
                  children: [
                    _buildHeader(sheikh),
                    Expanded(child: _buildMushafBody()),
                  ],
                ),
                if (_selStart != null) _buildAudioBar(sheikh),
              ],
            ),
    );
  }

  Widget _buildPageInfoItem(String label, int value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 9.sp,
            color: AppColors.textDim,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value > 0 ? value.toString() : '-',
          style: TextStyle(
            fontFamily: 'NotoNaskhArabic',
            fontSize: 13.sp,
            color: AppColors.goldWarm,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64.sp, color: AppColors.textDim),
          SizedBox(height: 16.h),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 16.sp,
              color: AppColors.textDim,
            ),
          ),
          SizedBox(height: 24.h),
          ElevatedButton(
            onPressed: _loadSurah,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.goldWarm,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Text(
              'إعادة المحاولة',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 14.sp),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  الرأس — ✅ إصلاح كامل للأزرار
  // ══════════════════════════════════════════════════════════════

  Widget _buildHeader(Sheikh sheikh) {
    return Container(
      color: AppColors.mushafPaper,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8.h,
        bottom: 10.h,
        left: 16.w,
        right: 16.w,
      ),
      child: Column(
        children: [
          // ── الصف الأول: رجوع، بحث، عدد الآيات، الشيخ ──
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36.r,
                  height: 36.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.goldWarm.withValues(alpha: 0.1),
                    border: Border.all(
                      color: AppColors.goldWarm.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    color: AppColors.mushafInk,
                    size: 16.sp,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: () => setState(() => _isSearching = !_isSearching),
                child: Container(
                  width: 36.r,
                  height: 36.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isSearching
                        ? AppColors.goldWarm.withValues(alpha: 0.2)
                        : AppColors.goldWarm.withValues(alpha: 0.1),
                    border: Border.all(
                      color: AppColors.goldWarm.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.search_rounded,
                    color: AppColors.mushafInk,
                    size: 18.sp,
                  ),
                ),
              ),
              const Spacer(),
              if (_surahInfo != null)
                GestureDetector(
                  onTap: _showAyahPicker,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.goldWarm.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(18.r),
                      border: Border.all(
                        color: AppColors.goldWarm.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.format_list_numbered_rounded,
                          size: 14.sp,
                          color: AppColors.goldWarm,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          '${_surahInfo!.totalVerses}',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 11.sp,
                            color: AppColors.mushafInk,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 16.sp,
                          color: AppColors.mushafInk,
                        ),
                      ],
                    ),
                  ),
                ),
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: () => _showSheikhPicker(context),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.goldWarm.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18.r),
                    border: Border.all(
                      color: AppColors.goldWarm.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.record_voice_over_rounded,
                        size: 14.sp,
                        color: AppColors.goldWarm,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        sheikh.name.split(' ').last,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11.sp,
                          color: AppColors.mushafInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 8.h),

          // ── الصف الثاني: أزرار التحكم ──
          // ✅ الإصلاح الرئيسي: عند التشغيل نستخدم صفّين منفصلين
          // لتجنب overflow وضمان ظهور جميع النصوص كاملة
          if (_isPlaying || _isPaused) ...[
            // الصف 2أ: إيقاف مؤقت/استئناف + إيقاف (كل منهما Expanded)
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _isPlaying && !_isPaused
                        ? _pausePlayback
                        : _playFullSurah,
                    child: _buildControlButton(
                      icon: _isPlaying && !_isPaused
                          ? Icons.pause_circle_outline_rounded
                          : Icons.play_circle_outline_rounded,
                      label: _isPlaying && !_isPaused
                          ? 'إيقاف مؤقت'
                          : 'استئناف',
                      highlighted: true,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: GestureDetector(
                    onTap: _stopPlayback,
                    child: _buildControlButton(
                      icon: Icons.stop_circle_outlined,
                      label: 'إيقاف',
                      highlighted: true,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            // الصف 2ب: تبديل النمط بعرض كامل
            GestureDetector(
              onTap: () => setState(() => _isParagraphMode = !_isParagraphMode),
              child: _buildControlButton(
                icon: _isParagraphMode
                    ? Icons.view_headline_rounded
                    : Icons.view_stream_rounded,
                label: _isParagraphMode ? 'نمط مسترسل' : 'نمط سطور',
                highlighted: false,
                fullWidth: true,
              ),
            ),
          ] else ...[
            // بدون تشغيل: زر تشغيل + زر نمط في صف واحد
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: _playFullSurah,
                    child: _buildControlButton(
                      icon: Icons.play_circle_outline_rounded,
                      label: 'تشغيل السورة',
                      highlighted: true,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _isParagraphMode = !_isParagraphMode),
                    child: _buildControlButton(
                      icon: _isParagraphMode
                          ? Icons.view_headline_rounded
                          : Icons.view_stream_rounded,
                      label: _isParagraphMode ? 'مسترسل' : 'سطور',
                      highlighted: false,
                    ),
                  ),
                ),
              ],
            ),
          ],

          SizedBox(height: 8.h),

          // ── الصف الثالث: الجزء / الحزب ──
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.goldWarm.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: AppColors.goldWarm.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Builder(
              builder: (context) {
                final pageInfo = _getCurrentPageInfo();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPageInfoItem('الجزء', pageInfo['juz']!),
                    Container(
                      width: 1,
                      height: 16.h,
                      color: AppColors.goldWarm.withValues(alpha: 0.2),
                    ),
                    _buildPageInfoItem('الحزب', pageInfo['hizb']!),
                  ],
                );
              },
            ),
          ),

          // ── شريط البحث ──
          if (_isSearching) ...[
            SizedBox(height: 8.h),
            Container(
              height: 40.h,
              decoration: BoxDecoration(
                color: AppColors.mushafPaper,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: AppColors.goldWarm.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _searchController,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13.sp,
                  color: AppColors.mushafInk,
                ),
                decoration: InputDecoration(
                  hintText: 'رقم الآية...',
                  hintStyle: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13.sp,
                    color: AppColors.textDim,
                  ),
                  prefixIcon: Icon(
                    Icons.tag_rounded,
                    color: AppColors.goldWarm,
                    size: 18.sp,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            color: AppColors.textDim,
                            size: 18.sp,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 10.h,
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
                onSubmitted: (value) {
                  if (value.isNotEmpty) _searchByAyahNumber(value);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAyahPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.mushafPaper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => Container(
        height: 400.h,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: AppColors.textDim),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    _selStart != null
                        ? 'اختر آية نهاية التحديد'
                        : 'اختر الآية',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.mushafInk,
                    ),
                  ),
                  SizedBox(width: 48.w),
                ],
              ),
            ),
            Divider(color: AppColors.mushafBorder),
            Expanded(
              child: ListView.builder(
                itemCount: _ayahs.length,
                itemBuilder: (context, index) {
                  final ayah = _ayahs[index];
                  return ListTile(
                    onTap: () {
                      Navigator.pop(context);
                      if (_isPlaying) return;
                      final picked = ayah.numberInSurah;
                      if (_selStart == null) {
                        // لا يوجد تحديد — القفز مع بدء تحديد آية واحدة (السلوك الحالي)
                        _scrollToAyah(picked);
                      } else {
                        // يوجد تحديد — مدّه إلى الآية المختارة (مثل _onAyahTap فرع E)
                        setState(() => _selEnd = picked);
                        _scrollToAyah(picked, select: false);
                      }
                    },
                    leading: Container(
                      width: 32.r,
                      height: 32.r,
                      decoration: BoxDecoration(
                        color: AppColors.goldWarm.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.goldWarm.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${ayah.numberInSurah}',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.goldWarm,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      ayah.text.length > 50
                          ? '${ayah.text.substring(0, 50)}...'
                          : ayah.text,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 14.sp,
                        color: AppColors.mushafInk,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _searchByAyahNumber(String query) {
    final ayahNumber = int.tryParse(query);
    if (ayahNumber == null) {
      _showErrorMessage('الرجاء إدخال رقم صحيح');
      return;
    }
    if (ayahNumber < 1 || ayahNumber > _ayahs.length) {
      _showErrorMessage(
        'الآية رقم $ayahNumber غير موجودة في هذه السورة\nالسورة تحتوي على ${_ayahs.length} آية فقط',
      );
      return;
    }
    _scrollToAyah(ayahNumber);
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _searchQuery = '';
    });
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 13.sp,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.goldWarm,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// تأكيد خفيف عائم — نفس نمط "تم النسخ" المستخدم في التطبيق
  /// (hadith_detail_screen.dart / favorites_screen.dart)
  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            color: AppColors.agedPlaster,
          ),
        ),
        backgroundColor: const Color(0xFF1A1535),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.goldWarm.withValues(alpha: 0.4)),
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  حفظ يدوي لـ "آخر قراءة" من التحديد الحالي — شارة القائمة فقط.
  //  • الهدف = آخر آية في النطاق (الأعلى من _selStart/_selEnd)
  //  • يكتب فقط في last_read_by_surah (Manual) ولا يمس التلقائي أبداً
  //  • منفصل تماماً عن الحفظ التلقائي للصفحة لكل سورة
  // ══════════════════════════════════════════════════════════════
  Future<void> _saveSelectionAsLastRead() async {
    if (_selStart == null) return;

    final target = _selStart! > (_selEnd ?? _selStart!)
        ? _selStart!
        : (_selEnd ?? _selStart!);
    if (target < 1 || target > _ayahs.length) return;

    // toggle: إذا كانت نفس الآية محفوظة بالفعل → ألغِها
    if (_lastReadAyahMarker == target) {
      await ref.read(lastReadProvider.notifier).clearForSurah(widget.surahNumber);
      if (!mounted) return;
      setState(() => _lastReadAyahMarker = null);
      _showToast('تم إلغاء آخر قراءة');
      return;
    }

    final ayah = _ayahs[target - 1];
    final pos = LastReadPosition(
      surahNumber: widget.surahNumber,
      ayahNumber: ayah.numberInSurah,
      pageNumber: ayah.pageNumber,
      juzNumber: ayah.juzNumber,
      updatedAt: DateTime.now(),
    );

    await ref.read(lastReadProvider.notifier).savePosition(pos);

    if (!mounted) return;
    // تحديث نفس العلامة الوحيدة لتقفز فوراً إلى الآية المختارة يدوياً
    setState(() => _lastReadAyahMarker = target);
    _showToast('تم حفظ الآية $target كآخر قراءة');
  }

  Widget _buildMushafBody() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      child: Column(
        children: [
          if (_surahInfo != null) SurahHeaderWidget(surahInfo: _surahInfo!),
          SizedBox(height: 8.h),
          if (widget.surahNumber != 9 && widget.surahNumber != 1)
            Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 16.w),
                decoration: BoxDecoration(
                  color: AppColors.goldWarm.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: AppColors.goldWarm.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 22.sp,
                    color: AppColors.mushafInk,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          // ✅ dividerBuilder الآن يتجاهل آخر آية (نتعامل معها يدوياً أدناه)
          _isParagraphMode
              ? ParagraphQuranText(
                  ayahs: _ayahs,
                  onAyahTap: _onAyahTap,
                  onAyahLongPress: _onAyahLongPress,
                  isSelected: _isSelected,
                  playingAyah: _playingAyah,
                  lastReadAyah: _lastReadAyahMarker,
                  ayahKeys: _ayahKeys,
                  onVisibilityChanged: _updateVisibleAyah,
                  dividerBuilder: (ayah, index) {
                    // ✅ تجاهل آخر آية هنا — سيُعالج يدوياً
                    if (index >= _ayahs.length - 1)
                      return const SizedBox.shrink();
                    if (_isEndOfPage(ayah, index)) {
                      return _buildPageDivider(ayah, index);
                    }
                    return const SizedBox.shrink();
                  },
                )
              : JustifiedQuranText(
                  ayahs: _ayahs,
                  onAyahTap: _onAyahTap,
                  onAyahLongPress: _onAyahLongPress,
                  isSelected: _isSelected,
                  playingAyah: _playingAyah,
                  lastReadAyah: _lastReadAyahMarker,
                  ayahKeys: _ayahKeys,
                  onVisibilityChanged: _updateVisibleAyah,
                  dividerBuilder: (ayah, index) {
                    // ✅ تجاهل آخر آية هنا — سيُعالج يدوياً
                    if (index >= _ayahs.length - 1)
                      return const SizedBox.shrink();
                    if (_isEndOfPage(ayah, index)) {
                      return _buildPageDivider(ayah, index);
                    }
                    return const SizedBox.shrink();
                  },
                ),

          // ✅ فاصل آخر صفحة مضمون دائماً بغض النظر عن طول السورة
          if (_ayahs.isNotEmpty)
            _buildPageDivider(_ayahs.last, _ayahs.length - 1),

          // ── تذييل الانتقال إلى السورة التالية (لا يظهر في سورة الناس) ──
          if (widget.surahNumber < 114 && _error == null && _ayahs.isNotEmpty)
            _buildNextSurahFooter(),

          SizedBox(height: _selStart != null ? 120.h : 40.h),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  تذييل "السورة التالية" — انتقال يدوي فقط (تم إلغاء التقدّم التلقائي)
  //  لا يظهر في السورة 114 (الحارس في _buildMushafBody).
  // ══════════════════════════════════════════════════════════════
  Widget _buildNextSurahFooter() {
    final nextName = QuranDataService.instance
        .surahById(widget.surahNumber + 1)
        .name;

    return Padding(
      padding: EdgeInsets.only(top: 8.h),
      child: GestureDetector(
        onTap: _goToNextSurah,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
          decoration: BoxDecoration(
            color: AppColors.goldWarm.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: AppColors.goldWarm.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.arrow_back_ios_new,
                size: 14.sp,
                color: AppColors.goldWarm,
              ),
              SizedBox(width: 8.w),
              Text(
                'السورة التالية:',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13.sp,
                  color: AppColors.mushafInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 6.w),
              Text(
                'سورة $nextName',
                style: TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.mushafInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToNextSurah() {
    if (!mounted || widget.surahNumber >= 114) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ModernQuranReaderV2(surahNumber: widget.surahNumber + 1),
      ),
    );
  }

  Widget _buildAudioBar(Sheikh sheikh) {
    final from = _selStart!;
    final to = _selEnd ?? _selStart!;
    final range = from == to ? 'الآية $from' : 'من $from إلى $to';

    // اختصار "إلى آخر السورة": يظهر فقط إن لم يكن النطاق يصل النهاية أصلاً
    final lastAyah = _ayahs.last.numberInSurah;
    final effectiveMax = from > to ? from : to;
    final showExtendToEnd = effectiveMax != lastAyah;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 16.w,
          right: 16.w,
          top: 12.h,
          bottom: MediaQuery.of(context).padding.bottom + 12.h,
        ),
        decoration: BoxDecoration(
          color: AppColors.mushafPaper,
          border: Border(
            top: BorderSide(color: AppColors.mushafBorder, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: _isPlaying ? _stopPlayback : _playSelection,
              child: Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: AppColors.goldWarm,
                  shape: BoxShape.circle,
                ),
                child: _isLoadingAudio
                    ? Padding(
                        padding: EdgeInsets.all(12.w),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            AppColors.mushafPaper,
                          ),
                        ),
                      )
                    : Icon(
                        _isPlaying
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                        color: AppColors.mushafPaper,
                        size: 28.sp,
                      ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    range,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.mushafInk,
                    ),
                  ),
                  Text(
                    sheikh.name,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11.sp,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
            // مسافة ثابتة قبل مجموعة الأزرار اليسرى — تمنع الالتصاق بالنص
            SizedBox(width: 12.w),
            // ── مجموعة الأزرار اليسرى — مضغوطة بـ MainAxisSize.min وموزعة بمسافات 8.w متساوية
            //     هذا يضمن محاذاة سليمة لليسار بدون فراغ متروك وبدون تكدس على اليمين
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showExtendToEnd) ...[
                  GestureDetector(
                    onTap: () => setState(() => _selEnd = lastAyah),
                    child: Container(
                      constraints: BoxConstraints(maxWidth: 92.w),
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.goldWarm.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18.r),
                        border: Border.all(
                          color: AppColors.goldWarm.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.last_page_rounded,
                              size: 14.sp,
                              color: AppColors.goldWarm,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'للنهاية',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.mushafInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                ],
            GestureDetector(
              onTap: () => setState(() => _repeatEnabled = !_repeatEnabled),
              child: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: _repeatEnabled
                      ? AppColors.goldWarm.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.repeat_rounded,
                  color: _repeatEnabled
                      ? AppColors.goldWarm
                      : AppColors.textDim,
                  size: 20.sp,
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Builder(
              builder: (context) {
                final selTarget = _selStart == null
                    ? null
                    : (_selStart! > (_selEnd ?? _selStart!)
                        ? _selStart!
                        : (_selEnd ?? _selStart!));
                final isBookmarked =
                    selTarget != null && _lastReadAyahMarker == selTarget;
                return GestureDetector(
                  onTap: isBookmarked
                      ? () async {
                          await ref
                              .read(lastReadProvider.notifier)
                              .clearForSurah(widget.surahNumber);
                          if (!mounted) return;
                          setState(() => _lastReadAyahMarker = null);
                          _showToast('تم إلغاء آخر قراءة');
                        }
                      : _saveSelectionAsLastRead,
                  child: Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(
                      color: isBookmarked
                          ? AppColors.goldWarm.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8.r),
                      border: isBookmarked
                          ? Border.all(
                              color: AppColors.goldWarm.withValues(alpha: 0.3),
                              width: 1,
                            )
                          : null,
                    ),
                    child: Icon(
                      isBookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: AppColors.goldWarm,
                      size: 20.sp,
                    ),
                  ),
                );
              },
            ),
            SizedBox(width: 8.w),
            GestureDetector(
              onTap: _clearSelection,
              child: Icon(
                Icons.close_rounded,
                color: AppColors.textDim,
                size: 20.sp,
              ),
            ),
          ],
        ),
          ],
        ),
      ),
    );
  }

  void _showSheikhPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.mushafPaper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => const _SheikhPickerSheet(),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  _SheikhPickerSheet
// ════════════════════════════════════════════════════════════════

class _SheikhPickerSheet extends ConsumerWidget {
  const _SheikhPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(settingsProvider).sheikId;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 12.h, bottom: 8.h),
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.goldWarm.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'اختر القارئ',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.mushafInk,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.all(6.r),
                    decoration: BoxDecoration(
                      color: AppColors.goldWarm.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      color: AppColors.textDim,
                      size: 18.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: AppColors.mushafBorder, height: 1, thickness: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.only(
                top: 8.h,
                bottom: MediaQuery.of(context).padding.bottom + 16.h,
              ),
              itemCount: kSheikhs.length,
              itemBuilder: (context, index) {
                final sheikh = kSheikhs[index];
                final selected = sheikh.id == current;

                return InkWell(
                  onTap: () {
                    ref.read(settingsProvider.notifier).setSheikh(sheikh.id);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 14.h,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.goldWarm.withValues(alpha: 0.15)
                          : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.mushafBorder.withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36.r,
                          height: 36.r,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.goldWarm.withValues(alpha: 0.2)
                                : AppColors.goldWarm.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.record_voice_over_rounded,
                            color: selected
                                ? AppColors.goldWarm
                                : AppColors.textDim,
                            size: 18.sp,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sheikh.name,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 14.sp,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: selected
                                      ? AppColors.goldWarm
                                      : AppColors.mushafInk,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                sheikh.style,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 11.sp,
                                  color: AppColors.textDim,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (selected)
                          Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.goldWarm,
                            size: 22.sp,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
