import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medicine_record.dart';
import '../models/medicine_schedule.dart';
import '../services/database_service.dart';
import 'page_settings.dart';
import 'page_plan_manage.dart';
import '../models/medicine_plan.dart';
import '../models/medicine_dose.dart';
import '../models/medicine_dose_record.dart';
import 'page_statistics.dart';

class UnifiedRecord {
  final DateTime date;
  final String planName;
  final int? doseOrder; // null为单次计划
  final double dosage;
  final bool isTaken;
  final String? notes;

  UnifiedRecord({
    required this.date,
    required this.planName,
    this.doseOrder,
    required this.dosage,
    required this.isTaken,
    this.notes,
  });

  // 工厂方法：多次计划
  factory UnifiedRecord.fromDose(MedicineDoseRecord dose, String planName) {
    return UnifiedRecord(
      date: dose.date,
      planName: planName,
      doseOrder: dose.doseOrder,
      dosage: dose.dosage,
      isTaken: dose.isTaken,
      notes: dose.notes,
    );
  }
  // 工厂方法：单次计划
  factory UnifiedRecord.fromSingle(MedicineRecord rec) {
    return UnifiedRecord(
      date: rec.date,
      planName: '单次计划',
      doseOrder: null,
      dosage: rec.dosage,
      isTaken: rec.isTaken,
      notes: rec.notes,
    );
  }
}

Future<List<UnifiedRecord>> getRecentUnifiedRecords(DatabaseService db) async {
  final today = DateTime.now();
  final days = 7;
  
  // 多次计划
  final doseRecords = await db.getDoseRecordsForDateRange(today.subtract(Duration(days: days-1)), today);
  print('多次计划记录数量: ${doseRecords.length}');
  
  final plans = await db.getAllMedicinePlans();
  print('计划数量: ${plans.length}');
  
  final planMap = {for (var p in plans) p.id!: p.name};
  final doseUnified = doseRecords.map((d) => UnifiedRecord.fromDose(d, planMap[d.planId] ?? '未知计划')).toList();
  
  // 单次计划
  final singleRecords = await db.getMedicineRecordsForDateRange(today.subtract(Duration(days: days-1)), today);
  print('单次计划记录数量: ${singleRecords.length}');
  
  final singleUnified = singleRecords.map((s) => UnifiedRecord.fromSingle(s)).toList();
  
  // 合并
  final all = [...doseUnified, ...singleUnified];
  all.sort((a, b) => b.date.compareTo(a.date));
  
  print('总记录数量: ${all.length}');
  return all;
}


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
  bool _isRecording = false;

  // 新增：多次计划相关
  List<MedicinePlan> _plans = [];
  Map<int, List<MedicineDose>> _planDoses = {};
  Map<String, bool> _doseTaken = {}; // key: planId-doseOrder

  int _selectedIndex = 0;

  void _onNavBarTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

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
      // 加载多次计划
      final plans = await _databaseService.getAllMedicinePlans();
      final Map<int, List<MedicineDose>> planDoses = {};
      final Map<String, bool> doseTaken = {};
      for (final plan in plans) {
        final doses = await _databaseService.getDosesByPlanId(plan.id!);
        planDoses[plan.id!] = doses;
        for (final d in doses) {
          // 查询今天是否已吃
          final taken = await _getDoseTaken(plan.id!, d.doseOrder);
          doseTaken['${plan.id!}-${d.doseOrder}'] = taken;
        }
      }
      setState(() {
        _currentSchedule = schedule;
        _todayRecord = record;
        _plans = plans;
        _planDoses = planDoses;
        _doseTaken = doseTaken;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _getDoseTaken(int planId, int doseOrder) async {
    final record = await _databaseService.getDoseRecord(planId, doseOrder, _today);
    return record?.isTaken ?? false;
  }

  Future<void> _recordDose(int planId, int doseOrder, double dosage) async {
    await _databaseService.insertDoseRecord(MedicineDoseRecord(
      id: null,
      planId: planId,
      doseOrder: doseOrder,
      date: DateTime.now(), // 保存完整时间
      dosage: dosage,
      isTaken: true,
      notes: null,
    ));
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已记录本次吃药'), backgroundColor: Colors.green),
      );
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
    final List<Widget> _pages = [
      _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTodayStatusCard(),
                    SizedBox(height: isSmallScreen ? 16 : 20),
                    _buildPlansCard(),
                  ],
                ),
              ),
            ),
      Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        child: _buildHistoryCard(),
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('吃药记录'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: '统计分析',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const StatisticsPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: '计划管理',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PlanManagePage(),
                ),
              ).then((_) => _loadData());
            },
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavBarTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: '最近记录',
          ),
        ],
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildTodayStatusCard() {
    if (_plans.isEmpty) {
      return Card(
        elevation: 4,
        margin: EdgeInsets.zero,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('今日服药总览', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                Text('暂无吃药计划', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      );
    }
    // 统计所有药品今日应吃总量、已吃总量、总建议次数、已吃次数
    int totalSuggestCount = 0;
    int totalTakenCount = 0;
    double totalSuggestDosage = 0;
    double totalTakenDosage = 0;
    for (final plan in _plans) {
      final doses = _planDoses[plan.id!] ?? [];
      totalSuggestCount += doses.length;
      totalSuggestDosage += doses.fold(0, (sum, d) => sum + d.dosage);
      for (final d in doses) {
        final taken = _doseTaken['${plan.id!}-${d.doseOrder}'] ?? false;
        if (taken) {
          totalTakenCount++;
          totalTakenDosage += d.dosage;
        }
      }
    }
    double percent = totalSuggestDosage == 0 ? 0 : (totalTakenDosage / totalSuggestDosage).clamp(0.0, 1.0);
    Color progressColor = percent >= 1.0 ? Colors.green : Colors.blue;
    String statusText = percent >= 1.0 ? '今日已全部完成' : '请按时服药';
    Color statusColor = percent >= 1.0 ? Colors.green : Colors.orange;
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('今日服药总览', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('已吃 $totalTakenCount/$totalSuggestCount 次，药量 ${totalTakenDosage.toStringAsFixed(2)}/${totalSuggestDosage.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: percent,
              minHeight: 12,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
            const SizedBox(height: 8),
            Text(statusText, style: TextStyle(color: statusColor)),
          ],
        ),
      ),
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

  Widget _buildPlansCard() {
    if (_plans.isEmpty) {
      return const SizedBox();
    }
    final today = DateTime.now();
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('多次吃药计划', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._plans.map((plan) {
              final doses = _planDoses[plan.id!] ?? [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ...doses.map((d) {
                    final taken = _doseTaken['${plan.id!}-${d.doseOrder}'] ?? false;
                    return FutureBuilder<MedicineDoseRecord?>(
                      future: _databaseService.getDoseRecord(plan.id!, d.doseOrder, today),
                      builder: (context, snapshot) {
                        String? timeStr;
                        if (taken && snapshot.hasData && snapshot.data != null) {
                          timeStr = DateFormat('HH:mm:ss').format(snapshot.data!.date);
                        }
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(taken ? Icons.check_circle : Icons.radio_button_unchecked, color: taken ? Colors.green : Colors.grey),
                          title: Text('第${d.doseOrder}次 ${d.suggestTime}  药量：${d.dosage}'),
                          subtitle: taken && timeStr != null ? Text('记录于 $timeStr') : null,
                          trailing: taken
                              ? const Text('已记录', style: TextStyle(color: Colors.green))
                              : ElevatedButton(
                                  onPressed: () => _recordDose(plan.id!, d.doseOrder, d.dosage),
                                  child: const Text('记录'),
                                ),
                        );
                      },
                    );
                  }).toList(),
                  const Divider(),
                ],
              );
            }).toList(),
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
                onPressed: () {},
                child: const Text('查看全部'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<UnifiedRecord>>(
            future: getRecentUnifiedRecords(_databaseService),
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
                children: records.take(7).map((rec) {
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      rec.isTaken ? Icons.check_circle : Icons.cancel,
                      color: rec.isTaken ? Colors.green : Colors.red,
                    ),
                    title: Text('${rec.planName}${rec.doseOrder != null ? ' 第${rec.doseOrder}次' : ''}'),
                    subtitle: Text('${rec.date.month}/${rec.date.day}  药量:${rec.dosage}${rec.notes != null ? ' 备注:${rec.notes}' : ''}'),
                    trailing: rec.isTaken ? const Text('已记录', style: TextStyle(color: Colors.green)) : const Text('未记录', style: TextStyle(color: Colors.red)),
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
}