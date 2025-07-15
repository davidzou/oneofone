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
  final plans = await db.getAllMedicinePlans();
  final planMap = {for (var p in plans) p.id!: p.name};
  final doseUnified = doseRecords.map((d) => UnifiedRecord.fromDose(d, planMap[d.planId] ?? '未知计划')).toList();
  // 单次计划
  final singleRecords = await db.getMedicineRecordsForDateRange(today.subtract(Duration(days: days-1)), today);
  final singleUnified = singleRecords.map((s) => UnifiedRecord.fromSingle(s)).toList();
  // 合并
  final all = [...doseUnified, ...singleUnified];
  all.sort((a, b) => b.date.compareTo(a.date));
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
      date: DateTime(_today.year, _today.month, _today.day),
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
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              ).then((_) => _loadData());
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
                    _buildTodayStatusCard(),
                    SizedBox(height: isSmallScreen ? 16 : 20),
                    _buildPlansCard(),
                    SizedBox(height: isSmallScreen ? 16 : 20),
                    _buildHistoryCard(),
                  ],
                ),
              ),
            ),
      floatingActionButton: null, // 多次计划已支持单独记录，主按钮可移除
    );
  }

  Widget _buildTodayStatusCard() {
    final List<Widget> statusList = [];
    double totalTodayDosage = 0;
    if (_plans.isEmpty) {
      return Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('今日状态', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('暂无吃药计划', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }
    return FutureBuilder<List<List<MedicineDoseRecord>>>(
      future: Future.wait(_plans.map((plan) => _databaseService.getDoseRecordsByPlanId(plan.id!)).toList()),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(child: Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())));
        }
        final allRecords = snapshot.data!;
        if (allRecords.length != _plans.length) {
          return const Card(child: Padding(padding: EdgeInsets.all(16), child: Center(child: Text('数据加载异常'))));
        }
        for (int idx = 0; idx < _plans.length; idx++) {
          final plan = _plans[idx];
          final doses = _planDoses[plan.id!] ?? [];
          final records = allRecords[idx];
          double todayDosage = 0;
          int todayTakenCount = 0;
          int todaySuggestCount = doses.length;
          int totalTakenCount = records.length;
          double totalTakenDosage = records.fold(0, (sum, r) => sum + r.dosage);
          // 今日统计
          final today = DateTime.now();
          for (final d in doses) {
            final taken = _doseTaken['${plan.id!}-${d.doseOrder}'] ?? false;
            if (taken) {
              todayTakenCount++;
              todayDosage += d.dosage;
            }
          }
          totalTodayDosage += todayDosage;
          int? totalDoses = plan.totalDoses;
          String unit = plan.unit ?? '次';
          bool isCourse = plan.planType == 'course';
          String progressText = '';
          bool isFinished = false;
          if (isCourse && totalDoses != null) {
            progressText = '疗程进度：$totalTakenCount/$totalDoses$unit';
            if (totalTakenCount >= totalDoses) {
              isFinished = true;
            }
          } else {
            progressText = '累计已吃：$totalTakenCount$unit';
          }
          statusList.add(
            ListTile(
              leading: Icon(isCourse && isFinished ? Icons.verified : Icons.medication, color: isCourse && isFinished ? Colors.green : Colors.blue),
              title: Text('${plan.name}'),
              subtitle: Text(isCourse && isFinished
                  ? '已完成疗程'
                  : '今日已吃$todayTakenCount/$todaySuggestCount次，$progressText'),
              trailing: Text('今日药量：${todayDosage.toStringAsFixed(2)}${plan.unit ?? ''}'),
            ),
          );
        }
        return Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('今日状态', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...statusList,
                const Divider(),
                Text('今日总药量：${totalTodayDosage.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      },
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
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(taken ? Icons.check_circle : Icons.radio_button_unchecked, color: taken ? Colors.green : Colors.grey),
                      title: Text('第${d.doseOrder}次 ${d.suggestTime}  药量：${d.dosage}'),
                      trailing: taken
                          ? const Text('已记录', style: TextStyle(color: Colors.green))
                          : ElevatedButton(
                              onPressed: () => _recordDose(plan.id!, d.doseOrder, d.dosage),
                              child: const Text('记录'),
                            ),
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