import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/dashboard_shared_widgets.dart';

class CategoryManager extends StatefulWidget {
  const CategoryManager({super.key});

  @override
  State<CategoryManager> createState() => _CategoryManagerState();
}

class _CategoryManagerState extends State<CategoryManager> {
  final _db = FirebaseFirestore.instance;

  void _showCategoryForm([Map<String, dynamic>? category, String? id]) {
    final nameController = TextEditingController(
      text: category?['nameAr'] ?? '',
    );
    final iconController = TextEditingController(
      text: category?['icon'] ?? '🤲',
    );
    final colorController = TextEditingController(
      text: category?['color'] ?? '#C8922A',
    );
    final orderController = TextEditingController(
      text: (category?['order'] ?? 0).toString(),
    );
    bool isActive = category?['isActive'] ?? true;

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
                  id == null ? 'إضافة تصنيف جديد' : 'تعديل التصنيف',
                  style: const TextStyle(
                    color: AppColors.goldWarm,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                DashboardTextField(
                  controller: nameController,
                  label: 'الاسم بالعربية',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DashboardTextField(
                        controller: iconController,
                        label: 'الأيقونة (Emoji)',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DashboardTextField(
                        controller: colorController,
                        label: 'اللون (Hex)',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DashboardTextField(
                        controller: orderController,
                        label: 'الترتيب',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'مفعل',
                          style: TextStyle(
                            color: AppColors.goldLight,
                            fontSize: 14,
                          ),
                        ),
                        Switch(
                          value: isActive,
                          onChanged: (v) => setModalState(() => isActive = v),
                          activeColor: AppColors.goldWarm,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                DashboardButton(
                  label: 'حفظ',
                  onPressed: () async {
                    final data = {
                      'nameAr': nameController.text,
                      'icon': iconController.text,
                      'color': colorController.text,
                      'order': int.tryParse(orderController.text) ?? 0,
                      'isActive': isActive,
                    };
                    if (id == null) {
                      await _db.collection('dua_categories').add(data);
                    } else {
                      await _db
                          .collection('dua_categories')
                          .doc(id)
                          .update(data);
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
          title: 'قائمة التصنيفات',
          onAdd: () => _showCategoryForm(),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection('dua_categories')
                .orderBy('order')
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
                  final category = docs[index].data() as Map<String, dynamic>;
                  final id = docs[index].id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DashboardCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Text(
                            category['icon'] ?? '🤲',
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category['nameAr'] ?? '',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'الترتيب: ${category['order']} | ${category['isActive'] ? 'مفعل' : 'معطل'}',
                                  style: const TextStyle(
                                    color: AppColors.textDim,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: AppColors.goldWarm,
                              size: 20,
                            ),
                            onPressed: () => _showCategoryForm(category, id),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: AppColors.nightMid,
                                  title: const Text(
                                    'حذف التصنيف؟',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  content: const Text(
                                    'سيؤدي هذا لحذف التصنيف بشكل نهائي.',
                                    style: TextStyle(color: AppColors.textDim),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('إلغاء'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        await _db
                                            .collection('dua_categories')
                                            .doc(id)
                                            .delete();
                                        if (mounted) Navigator.pop(context);
                                      },
                                      child: const Text(
                                        'حذف',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
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
}
