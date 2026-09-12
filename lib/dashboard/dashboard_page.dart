import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'daily_config_manager.dart';
import 'category_manager.dart';
import 'dua_manager.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nightDeep,
      appBar: AppBar(
        title: const Text(
          'لوحة التحكم',
          style: TextStyle(
            color: AppColors.goldWarm,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.goldWarm,
          labelColor: AppColors.goldWarm,
          unselectedLabelColor: AppColors.textDim,
          tabs: const [
            Tab(text: 'آية اليوم', icon: Icon(Icons.today)),
            Tab(text: 'التصنيفات', icon: Icon(Icons.category)),
            Tab(text: 'الأدعية', icon: Icon(Icons.menu_book)),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.pageGradient),
        child: TabBarView(
          controller: _tabController,
          children: const [
            DailyConfigManager(),
            CategoryManager(),
            DuaManager(),
          ],
        ),
      ),
    );
  }
}
