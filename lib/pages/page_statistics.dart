import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/medicine_plan.dart';
import '../models/medicine_dose_record.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({Key? key}) : super(key: key);

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final DatabaseService _db = DatabaseService();
  List<MedicinePlan> _plans = [];
  Map<int, List<MedicineDoseRecord>> _planRecords = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final plans = await _db.getAllMedicinePlans();
    final Map<int, List<MedicineDoseRecord>> planRecords = {};
    for (final plan in plans) {
      planRecords[plan.id!] = await _db.getDoseRecordsByPlanId(plan.id!);
    }
    setState(() {
      _plans = plans;
      _planRecords = planRecords;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('统计分析')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('药品累计统计', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ..._plans.map((plan) {
                  final records = _planRecords[plan.id!] ?? [];
                  final total = records.fold<double>(0, (sum, r) => sum + r.dosage);
                  final unit = plan.unit ?? '次';
                  return ListTile(
                    title: Text(plan.name),
                    subtitle: Text(plan.planType == 'course'
                        ? '疗程型，累计服药：$total$unit'
                        : '长期型，累计服药：$total$unit'),
                  );
                }),
                const Divider(),
                const SizedBox(height: 8),
                const Text('近30天每日服药次数', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildDailyTrendTable(),
              ],
            ),
    );
  }

  Widget _buildDailyTrendTable() {
    final today = DateTime.now();
    final days = List.generate(30, (i) => today.subtract(Duration(days: 29 - i)));
    // 统计所有药品每日服药次数
    final Map<String, int> dayCount = {};
    for (final records in _planRecords.values) {
      for (final r in records) {
        final key = '${r.date.year}-${r.date.month.toString().padLeft(2, '0')}-${r.date.day.toString().padLeft(2, '0')}';
        dayCount[key] = (dayCount[key] ?? 0) + 1;
      }
    }
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {0: FixedColumnWidth(90)},
      children: [
        TableRow(
          children: [
            const Padding(
              padding: EdgeInsets.all(4),
              child: Text('日期', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Padding(
              padding: EdgeInsets.all(4),
              child: Text('服药次数', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        ...days.map((d) {
          final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(4),
                child: Text('${d.month}/${d.day}'),
              ),
              Padding(
                padding: const EdgeInsets.all(4),
                child: Text('${dayCount[key] ?? 0}'),
              ),
            ],
          );
        }),
      ],
    );
  }
} 