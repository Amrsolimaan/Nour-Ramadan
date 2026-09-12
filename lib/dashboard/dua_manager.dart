import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/dashboard_shared_widgets.dart';

class DuaManager extends StatefulWidget {
  const DuaManager({super.key});

  @override
  State<DuaManager> createState() => _DuaManagerState();
}

class _DuaManagerState extends State<DuaManager> {
  final _db = FirebaseFirestore.instance;
  String? _selectedFilterCategory;

  void _showDuaForm([Map<String, dynamic>? dua, String? id]) {
    final textController = TextEditingController(text: dua?['text'] ?? '');
    final translationController = TextEditingController(
      text: dua?['translation'] ?? '',
    );
    final virtueController = TextEditingController(text: dua?['virtue'] ?? '');
    final sourceController = TextEditingController(text: dua?['source'] ?? '');
    final orderController = TextEditingController(
      text: (dua?['order'] ?? 0).toString(),
    );
    final tagsController = TextEditingController(
      text: (dua?['tags'] as List? ?? []).join(', '),
    );
    String? categoryId = dua?['categoryId'];
    bool isPublished = dua?['isPublished'] ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          decoration: const BoxDecoration(
            color: AppColors.nightMid,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  id == null ? 'إضافة دعاء جديد' : 'تعديل الدعاء',
                  style: const TextStyle(
                    color: AppColors.goldWarm,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                FutureBuilder<QuerySnapshot>(
                  future: _db.collection('dua_categories').get(),
                  builder: (context, snap) {
                    final categories = snap.data?.docs ?? [];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'التصنيف',
                          style: TextStyle(
                            color: AppColors.goldLight,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.nightDeep.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderGold),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: categoryId,
                              dropdownColor: AppColors.nightMid,
                              isExpanded: true,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                              hint: const Text(
                                'اختر التصنيف',
                                style: TextStyle(color: AppColors.textDim),
                              ),
                              items: categories.map((c) {
                                final data = c.data() as Map<String, dynamic>;
                                return DropdownMenuItem(
                                  value: c.id,
                                  child: Text(data['nameAr'] ?? ''),
                                );
                              }).toList(),
                              onChanged: (v) =>
                                  setModalState(() => categoryId = v),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                DashboardTextField(
                  controller: textController,
                  label: 'نص الدعاء',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DashboardTextField(
                  controller: translationController,
                  label: 'الترجمة / المعنى',
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DashboardTextField(
                  controller: virtueController,
                  label: 'الفضل',
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DashboardTextField(
                        controller: sourceController,
                        label: 'المصدر',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DashboardTextField(
                        controller: orderController,
                        label: 'الترتيب',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DashboardTextField(
                  controller: tagsController,
                  label: 'الوسوم (مفصولة بفواصل)',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'منشور',
                      style: TextStyle(
                        color: AppColors.goldLight,
                        fontSize: 14,
                      ),
                    ),
                    Switch(
                      value: isPublished,
                      onChanged: (v) => setModalState(() => isPublished = v),
                      activeColor: AppColors.goldWarm,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                DashboardButton(
                  label: 'حفظ',
                  onPressed: () async {
                    final data = {
                      'text': textController.text,
                      'translation': translationController.text,
                      'virtue': virtueController.text,
                      'source': sourceController.text,
                      'categoryId': categoryId,
                      'order': int.tryParse(orderController.text) ?? 0,
                      'isPublished': isPublished,
                      'tags': tagsController.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList(),
                      if (id == null) 'readCount': 0,
                    };
                    if (id == null) {
                      await _db.collection('duas').add(data);
                    } else {
                      await _db.collection('duas').doc(id).update(data);
                    }
                    if (mounted) Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DashboardSectionTitle(
          title: 'قائمة الأدعية',
          onAdd: () => _showDuaForm(),
        ),
        _buildFilter(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _selectedFilterCategory == null
                ? _db.collection('duas').orderBy('order').snapshots()
                : _db
                      .collection('duas')
                      .where('categoryId', isEqualTo: _selectedFilterCategory)
                      .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return Center(child: Text('Error: ${snapshot.error}'));
              if (!snapshot.hasData)
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.goldWarm),
                );

              final docs = snapshot.data!.docs;
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final dua = docs[index].data() as Map<String, dynamic>;
                  final id = docs[index].id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DashboardCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  dua['text'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: AppColors.goldWarm,
                                  size: 20,
                                ),
                                onPressed: () => _showDuaForm(dua, id),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                                onPressed: () => _deleteDua(id),
                              ),
                            ],
                          ),
                          Text(
                            'الترتيب: ${dua['order']} | ${dua['isPublished'] ? 'منشور' : 'مسودة'} | قراءة: ${dua['readCount']}',
                            style: const TextStyle(
                              color: AppColors.textDim,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilter() {
    return FutureBuilder<QuerySnapshot>(
      future: _db.collection('dua_categories').get(),
      builder: (context, snap) {
        final categories = snap.data?.docs ?? [];
        return Container(
          height: 50,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _filterChip(null, 'الكل'),
              ...categories.map((c) {
                final data = c.data() as Map<String, dynamic>;
                return _filterChip(c.id, data['nameAr'] ?? '');
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _filterChip(String? id, String label) {
    final isSelected = _selectedFilterCategory == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilterCategory = selected ? id : null;
          });
        },
        backgroundColor: AppColors.nightMid,
        selectedColor: AppColors.goldWarm,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.nightDeep : AppColors.goldLight,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  void _deleteDua(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.nightMid,
        title: const Text(
          'حذف الدعاء؟',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'سيؤدي هذا لحذف الدعاء بشكل نهائي.',
          style: TextStyle(color: AppColors.textDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              await _db.collection('duas').doc(id).delete();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
