import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/services/app_logger.dart';

// ════════════════════════════════════════════════════════════════
//  Logs Screen — شاشة عرض السجلات
// ════════════════════════════════════════════════════════════════

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  LogLevel? _selectedLevel;
  LogCategory? _selectedCategory;
  List<LogEntry> _filteredLogs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  void _loadLogs() {
    setState(() {
      _filteredLogs = logger.getLogs(
        level: _selectedLevel,
        category: _selectedCategory,
      ).reversed.toList(); // الأحدث أولاً
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedLevel = null;
      _selectedCategory = null;
      _loadLogs();
    });
  }

  Future<void> _exportLogs() async {
    try {
      final text = logger.exportLogsAsText();
      await Share.share(
        text,
        subject: 'App Logs - ${DateTime.now()}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في التصدير: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'مسح جميع السجلات؟',
          style: TextStyle(color: Color(0xFFE8D5B0)),
        ),
        content: const Text(
          'هل أنت متأكد من مسح جميع السجلات؟ لا يمكن التراجع عن هذا الإجراء.',
          style: TextStyle(color: Color(0xFFE8D5B0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'مسح',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await logger.clearLogs();
      _loadLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم مسح جميع السجلات'),
            backgroundColor: Color(0xFFC8922A),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = logger.getLogCountByLevel();
    
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
              // Header
              _buildHeader(),
              
              // Statistics
              _buildStatistics(stats),
              
              // Filters
              _buildFilters(),
              
              // Logs List
              Expanded(
                child: _filteredLogs.isEmpty
                    ? _buildEmptyState()
                    : _buildLogsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFC8922A)),
          ),
          const Expanded(
            child: Text(
              'سجلات التطبيق',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 20,
                color: Color(0xFFE8D5B0),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFFC8922A)),
            color: const Color(0xFF1E1B2E),
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _exportLogs();
                  break;
                case 'clear':
                  _clearLogs();
                  break;
                case 'refresh':
                  _loadLogs();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Color(0xFFC8922A), size: 20),
                    SizedBox(width: 8),
                    Text('تحديث', style: TextStyle(color: Color(0xFFE8D5B0))),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.share, color: Color(0xFFC8922A), size: 20),
                    SizedBox(width: 8),
                    Text('تصدير', style: TextStyle(color: Color(0xFFE8D5B0))),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('مسح الكل', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics(Map<LogLevel, int> stats) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2640)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('الكل', logger.totalLogs, Colors.blue),
          _buildStatItem('أخطاء', logger.errorCount, Colors.red),
          _buildStatItem('تحذيرات', stats[LogLevel.warning] ?? 0, Colors.orange),
          _buildStatItem('معلومات', stats[LogLevel.info] ?? 0, Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9B8A6E),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildLevelFilter(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildCategoryFilter(),
          ),
          if (_selectedLevel != null || _selectedCategory != null)
            IconButton(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear, color: Color(0xFFC8922A)),
              tooltip: 'مسح الفلاتر',
            ),
        ],
      ),
    );
  }

  Widget _buildLevelFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2640)),
      ),
      child: DropdownButton<LogLevel?>(
        value: _selectedLevel,
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: const Color(0xFF1E1B2E),
        style: const TextStyle(color: Color(0xFFE8D5B0), fontSize: 14),
        hint: const Text(
          'المستوى',
          style: TextStyle(color: Color(0xFF9B8A6E)),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('الكل')),
          ...LogLevel.values.map((level) => DropdownMenuItem(
            value: level,
            child: Text(level.name),
          )),
        ],
        onChanged: (value) {
          setState(() {
            _selectedLevel = value;
            _loadLogs();
          });
        },
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2640)),
      ),
      child: DropdownButton<LogCategory?>(
        value: _selectedCategory,
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: const Color(0xFF1E1B2E),
        style: const TextStyle(color: Color(0xFFE8D5B0), fontSize: 14),
        hint: const Text(
          'الفئة',
          style: TextStyle(color: Color(0xFF9B8A6E)),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('الكل')),
          ...LogCategory.values.map((category) => DropdownMenuItem(
            value: category,
            child: Text(category.name),
          )),
        ],
        onChanged: (value) {
          setState(() {
            _selectedCategory = value;
            _loadLogs();
          });
        },
      ),
    );
  }

  Widget _buildLogsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredLogs.length,
      itemBuilder: (context, index) {
        final log = _filteredLogs[index];
        return _buildLogItem(log);
      },
    );
  }

  Widget _buildLogItem(LogEntry log) {
    Color levelColor;
    switch (log.level) {
      case LogLevel.debug:
        levelColor = Colors.grey;
        break;
      case LogLevel.info:
        levelColor = Colors.green;
        break;
      case LogLevel.warning:
        levelColor = Colors.orange;
        break;
      case LogLevel.error:
        levelColor = Colors.red;
        break;
      case LogLevel.critical:
        levelColor = Colors.deepOrange;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: levelColor.withOpacity(0.3)),
      ),
      child: ExpansionTile(
        leading: Text(
          '${log.emoji} ${log.categoryEmoji}',
          style: const TextStyle(fontSize: 20),
        ),
        title: Text(
          log.message,
          style: const TextStyle(
            color: Color(0xFFE8D5B0),
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          '${log.timestamp.hour.toString().padLeft(2, '0')}:'
          '${log.timestamp.minute.toString().padLeft(2, '0')}:'
          '${log.timestamp.second.toString().padLeft(2, '0')} • '
          '${log.level.name} • ${log.category.name}',
          style: TextStyle(
            color: levelColor.withOpacity(0.8),
            fontSize: 11,
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0B1A),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (log.data != null) ...[
                  const Text(
                    'البيانات:',
                    style: TextStyle(
                      color: Color(0xFFC8922A),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    log.data.toString(),
                    style: const TextStyle(
                      color: Color(0xFFE8D5B0),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (log.error != null) ...[
                  const Text(
                    'الخطأ:',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    log.error!,
                    style: const TextStyle(
                      color: Color(0xFFE8D5B0),
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (log.stackTrace != null) ...[
                  const Text(
                    'Stack Trace:',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    log.stackTrace!,
                    style: const TextStyle(
                      color: Color(0xFFE8D5B0),
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 10,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: log.toString()),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم النسخ'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.copy,
                        size: 16,
                        color: Color(0xFFC8922A),
                      ),
                      label: const Text(
                        'نسخ',
                        style: TextStyle(color: Color(0xFFC8922A)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            size: 64,
            color: const Color(0xFF9B8A6E).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد سجلات',
            style: TextStyle(
              fontSize: 18,
              color: const Color(0xFF9B8A6E).withOpacity(0.8),
            ),
          ),
          if (_selectedLevel != null || _selectedCategory != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _clearFilters,
              child: const Text(
                'مسح الفلاتر',
                style: TextStyle(color: Color(0xFFC8922A)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
