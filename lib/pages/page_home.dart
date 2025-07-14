import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medicine_record.dart';
import '../models/medicine_schedule.dart';
import '../services/database_service.dart';
import 'page_settings.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseService _databaseService = DatabaseService();
  MedicineSchedule? _currentSchedule;
  MedicineRecord? _todayRecord;
  bool _isLoading = true;
  late DateTime _today;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final schedule = await _databaseService.getCurrentSchedule();
      final record = await _databaseService.getMedicineRecordForDate(_today);
      
      setState(() {
        _currentSchedule = schedule;
        _todayRecord = record;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading data: $e');
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _recordMedicineTaken(double dosage) async {
    try {
      await _databaseService.recordMedicineTaken(dosage);
      await _loadData(); // 重新加载数据
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已记录吃药：${dosage.toStringAsFixed(2)}粒'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('记录失败：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getDosageText() {
    if (_currentSchedule == null) return '未知';
    
    final dosage = _currentSchedule!.getDosageForToday(_today);
    if (dosage == 2.0) return '2粒';
    if (dosage == 1.75) return '1-3/4粒';
    return '${dosage.toStringAsFixed(2)}粒';
  }

  String _getScheduleText() {
    if (_currentSchedule == null) return '未设置';
    
    switch (_currentSchedule!.scheduleType) {
      case ScheduleType.daily:
        return '每日';
      case ScheduleType.alternate:
        return '单双日';
      case ScheduleType.weekly:
        return '每周';
      case ScheduleType.custom:
        return '自定义间隔';
    }
  }

  bool _shouldTakeMedicineToday() {
    if (_currentSchedule == null) return false;
    return _currentSchedule!.shouldTakeMedicineToday(_today);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('吃药记录'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              ).then((_) => _loadData()); // 返回时重新加载数据
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTodayCard(),
                    SizedBox(height: isSmallScreen ? 16 : 20),
                    _buildScheduleCard(),
                    SizedBox(height: isSmallScreen ? 16 : 20),
                    _buildHistoryCard(),
                  ],
                ),
              ),
            ),
      floatingActionButton: _shouldTakeMedicineToday() && (_todayRecord?.isTaken != true)
          ? FloatingActionButton.extended(
              onPressed: () => _showTakeMedicineDialog(),
              label: Text(isSmallScreen ? '记录' : '记录吃药'),
              icon: const Icon(Icons.medical_services),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildTodayCard() {
    final dateFormat = DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN');
    final isTaken = _todayRecord?.isTaken ?? false;
    final dosage = _todayRecord?.dosage ?? _currentSchedule?.getDosageForToday(_today) ?? 0.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '今天 (${dateFormat.format(_today)})',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8 : 12, 
                    vertical: isSmallScreen ? 4 : 6
                  ),
                  decoration: BoxDecoration(
                    color: isTaken ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isTaken ? '已吃药' : '未吃药',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 10 : 12,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            Text(
              '今日药量：${dosage.toStringAsFixed(2)}粒',
              style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
            ),
            if (_todayRecord?.notes != null) ...[
              SizedBox(height: isSmallScreen ? 6 : 8),
              Text(
                '备注：${_todayRecord!.notes}',
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 14, 
                  color: Colors.grey
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '吃药计划',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.schedule, color: Colors.blue),
                const SizedBox(width: 8),
                Text('频率：${_getScheduleText()}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.medical_services, color: Colors.green),
                const SizedBox(width: 8),
                Text('今日药量：${_getDosageText()}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  _shouldTakeMedicineToday() ? '今天需要吃药' : '今天不需要吃药',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    '最近记录',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // TODO: 跳转到历史记录页面
                  },
                  child: const Text('查看全部'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<MedicineRecord>>(
              future: _databaseService.getMedicineRecordsForDateRange(
                _today.subtract(const Duration(days: 7)),
                _today,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return const Text('加载失败');
                }
                
                final records = snapshot.data ?? [];
                if (records.isEmpty) {
                  return const Text('暂无记录');
                }
                
                return Column(
                  children: records.take(5).map((record) {
                    final dateFormat = DateFormat('MM/dd');
                    return ListTile(
                      leading: Icon(
                        record.isTaken ? Icons.check_circle : Icons.cancel,
                        color: record.isTaken ? Colors.green : Colors.red,
                      ),
                      title: Text(
                        '${dateFormat.format(record.date)} - ${record.dosage.toStringAsFixed(2)}粒',
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: record.notes != null 
                        ? Text(
                            record.notes!,
                            overflow: TextOverflow.ellipsis,
                          ) 
                        : null,
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTakeMedicineDialog() {
    final dosage = _currentSchedule?.getDosageForToday(_today) ?? 2.0;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('记录吃药'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('今日药量：${dosage.toStringAsFixed(2)}粒'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _recordMedicineTaken(dosage);
                  },
                  child: Text('吃了${dosage.toStringAsFixed(2)}粒'),
                ),
                if (dosage == 2.0)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _recordMedicineTaken(1.75);
                    },
                    child: const Text('吃了1-3/4粒'),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }
}


class WhichOfDay {
  // final []<String> values;
}
