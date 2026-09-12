import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/dashboard_shared_widgets.dart';

class DailyConfigManager extends StatefulWidget {
  const DailyConfigManager({super.key});

  @override
  State<DailyConfigManager> createState() => _DailyConfigManagerState();
}

class _DailyConfigManagerState extends State<DailyConfigManager> {
  final _titleController = TextEditingController();
  final _verseController = TextEditingController();
  final _referenceController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('daily')
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _titleController.text = data['title'] ?? '';
        _verseController.text = data['verseOfDay'] ?? '';
        _referenceController.text = data['verseReference'] ?? '';
        _selectedDate =
            (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading config: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('app_config')
          .doc('daily')
          .set({
            'title': _titleController.text,
            'verseOfDay': _verseController.text,
            'verseReference': _referenceController.text,
            'date': Timestamp.fromDate(_selectedDate),
          });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم الحفظ بنجاح')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving config: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _titleController.text.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.goldWarm),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DashboardSectionTitle(title: 'إعداد آية اليوم'),
          DashboardCard(
            child: Column(
              children: [
                DashboardTextField(
                  controller: _titleController,
                  label: 'العنوان الرئيسى',
                  hint: 'مثال: آية اليوم',
                ),
                const SizedBox(height: 16),
                DashboardTextField(
                  controller: _verseController,
                  label: 'نص الآية',
                  hint: 'أدخل نص الآية الكريمة هنا...',
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                DashboardTextField(
                  controller: _referenceController,
                  label: 'المرجع',
                  hint: 'مثال: البقرة: 185',
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'التاريخ',
                    style: TextStyle(
                      color: AppColors.goldLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}',
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.calendar_today,
                      color: AppColors.goldWarm,
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppColors.goldWarm,
                                onPrimary: AppColors.nightDeep,
                                surface: AppColors.nightMid,
                                onSurface: AppColors.textPrimary,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 30),
                DashboardButton(
                  label: 'حفظ التغييرات',
                  onPressed: _saveConfig,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
