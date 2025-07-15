import 'package:flutter/material.dart';
import '../models/medicine_plan.dart';
import '../models/medicine_dose.dart';
import '../services/database_service.dart';

class PlanManagePage extends StatefulWidget {
  const PlanManagePage({Key? key}) : super(key: key);

  @override
  State<PlanManagePage> createState() => _PlanManagePageState();
}

class _PlanManagePageState extends State<PlanManagePage> {
  final DatabaseService _db = DatabaseService();
  List<MedicinePlan> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    final plans = await _db.getAllMedicinePlans();
    setState(() {
      _plans = plans;
      _loading = false;
    });
  }

  void _showEditDialog({MedicinePlan? plan}) async {
    await showDialog(
      context: context,
      builder: (context) => PlanEditDialog(
        plan: plan,
        onSaved: _loadPlans,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('吃药计划管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showEditDialog(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _plans.length,
              itemBuilder: (context, idx) {
                final plan = _plans[idx];
                return ListTile(
                  title: Text(plan.name),
                  subtitle: Text('类型: ${plan.repeatType}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEditDialog(plan: plan),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () async {
                          await _db.deleteMedicinePlan(plan.id!);
                          _loadPlans();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class PlanEditDialog extends StatefulWidget {
  final MedicinePlan? plan;
  final VoidCallback onSaved;
  const PlanEditDialog({Key? key, this.plan, required this.onSaved}) : super(key: key);

  @override
  State<PlanEditDialog> createState() => _PlanEditDialogState();
}

class _PlanEditDialogState extends State<PlanEditDialog> {
  final DatabaseService _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  String _planType = 'longterm';
  int? _totalDoses;
  String? _unit;
  int _timesPerDay = 1;
  List<MedicineDose> _doses = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.plan?.name ?? '');
    _notesController = TextEditingController(text: widget.plan?.notes ?? '');
    _planType = widget.plan?.planType ?? 'longterm';
    _totalDoses = widget.plan?.totalDoses;
    _unit = widget.plan?.unit;
    _timesPerDay = 1;
    if (widget.plan != null) {
      _loadDoses();
    } else {
      _doses = _suggestDoses(_timesPerDay);
    }
  }

  Future<void> _loadDoses() async {
    if (widget.plan == null) return;
    final doses = await _db.getDosesByPlanId(widget.plan!.id!);
    setState(() {
      _doses = doses;
      _timesPerDay = doses.length;
    });
  }

  List<MedicineDose> _suggestDoses(int times) {
    // 避开0:00~6:00，均匀分布
    final List<String> timeList = _suggestTimes(times);
    return List.generate(times, (i) => MedicineDose(
      id: null,
      planId: widget.plan?.id ?? 0,
      doseOrder: i + 1,
      dosage: 1.0,
      suggestTime: timeList[i],
    ));
  }

  List<String> _suggestTimes(int times) {
    // 8:00~22:00之间均匀分布
    final start = 8;
    final end = 22;
    final interval = ((end - start) * 60) ~/ (times == 1 ? 1 : (times - 1));
    return List.generate(times, (i) {
      final minutes = start * 60 + interval * i;
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    });
  }

  void _onTimesChanged(int value) {
    setState(() {
      _timesPerDay = value;
      _doses = _suggestDoses(value);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; });
    final plan = MedicinePlan(
      id: widget.plan?.id,
      name: _nameController.text.trim(),
      isActive: true,
      repeatType: 'daily',
      notes: _notesController.text.trim(),
      planType: _planType,
      totalDoses: _planType == 'course' ? _totalDoses : null,
      unit: _planType == 'course' ? _unit : null,
    );
    int planId;
    if (widget.plan == null) {
      planId = await _db.insertMedicinePlan(plan);
    } else {
      await _db.updateMedicinePlan(plan);
      planId = plan.id!;
      // 删除原有doses
      final oldDoses = await _db.getDosesByPlanId(planId);
      for (final d in oldDoses) {
        await _db.deleteMedicineDose(d.id!);
      }
    }
    // 插入新doses
    for (int i = 0; i < _doses.length; i++) {
      final d = _doses[i];
      await _db.insertMedicineDose(MedicineDose(
        id: null,
        planId: planId,
        doseOrder: i + 1,
        dosage: d.dosage,
        suggestTime: d.suggestTime,
      ));
    }
    setState(() { _saving = false; });
    widget.onSaved();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.plan == null ? '新建计划' : '编辑计划'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '计划名称'),
                validator: (v) => v == null || v.trim().isEmpty ? '请输入名称' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: '备注'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('每日次数：'),
                  DropdownButton<int>(
                    value: _timesPerDay,
                    items: [1,2,3,4].map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
                    onChanged: (v) {
                      if (v != null) _onTimesChanged(v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('计划类型：'),
                  DropdownButton<String>(
                    value: _planType,
                    items: const [
                      DropdownMenuItem(value: 'longterm', child: Text('长期服用')),
                      DropdownMenuItem(value: 'course', child: Text('疗程型')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() { _planType = v; });
                    },
                  ),
                ],
              ),
              if (_planType == 'course') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('疗程总量：'),
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        initialValue: _totalDoses?.toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '总次数/总量'),
                        onChanged: (v) {
                          setState(() { _totalDoses = int.tryParse(v); });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: TextFormField(
                        initialValue: _unit,
                        decoration: const InputDecoration(labelText: '单位'),
                        onChanged: (v) {
                          setState(() { _unit = v; });
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              ..._doses.asMap().entries.map((entry) {
                final i = entry.key;
                final d = entry.value;
                return Row(
                  children: [
                    Text('第${i+1}次：'),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: TextFormField(
                        initialValue: d.dosage.toString(),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: '药量'),
                        onChanged: (v) {
                          final val = double.tryParse(v) ?? 1.0;
                          setState(() { _doses[i] = MedicineDose(
                            id: d.id,
                            planId: d.planId,
                            doseOrder: d.doseOrder,
                            dosage: val,
                            suggestTime: d.suggestTime,
                          ); });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        initialValue: d.suggestTime,
                        decoration: const InputDecoration(labelText: '时间'),
                        onChanged: (v) {
                          setState(() { _doses[i] = MedicineDose(
                            id: d.id,
                            planId: d.planId,
                            doseOrder: d.doseOrder,
                            dosage: d.dosage,
                            suggestTime: v,
                          ); });
                        },
                      ),
                    ),
                  ],
                );
              }).toList(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '保存中...' : '保存'),
        ),
      ],
    );
  }
} 