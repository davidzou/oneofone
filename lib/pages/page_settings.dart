import 'package:flutter/material.dart';
import '../models/medicine_schedule.dart';
import '../services/database_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final DatabaseService _databaseService = DatabaseService();
  MedicineSchedule? _currentSchedule;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentSchedule();
  }

  Future<void> _loadCurrentSchedule() async {
    try {
      final schedule = await _databaseService.getCurrentSchedule();
      setState(() {
        _currentSchedule = schedule;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateSchedule(MedicineSchedule schedule) async {
    try {
      await _databaseService.updateMedicineSchedule(schedule);
      await _loadCurrentSchedule();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('设置已保存'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildScheduleTypeCard(),
                  SizedBox(height: isSmallScreen ? 16 : 20),
                  _buildTimeOfDayCard(),
                  SizedBox(height: isSmallScreen ? 16 : 20),
                  _buildDosageCard(),
                  SizedBox(height: isSmallScreen ? 16 : 20),
                  _buildCustomSettingsCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildScheduleTypeCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '吃药频率',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...ScheduleType.values.map((type) {
              return RadioListTile<ScheduleType>(
                title: Text(_getScheduleTypeText(type)),
                subtitle: Text(_getScheduleTypeDescription(type)),
                value: type,
                groupValue: _currentSchedule?.scheduleType,
                onChanged: (value) {
                  if (value != null) {
                    final newSchedule = MedicineSchedule(
                      id: _currentSchedule?.id,
                      scheduleType: value,
                      timeOfDay: _currentSchedule?.timeOfDay ?? MedicineTimeOfDay.morning,
                      defaultDosage: _currentSchedule?.defaultDosage ?? 2.0,
                      interval: _currentSchedule?.interval,
                      customTime: _currentSchedule?.customTime,
                    );
                    _updateSchedule(newSchedule);
                  }
                },
                activeColor: Colors.blue,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeOfDayCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '吃药时间',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...MedicineTimeOfDay.values.map((time) {
              return RadioListTile<MedicineTimeOfDay>(
                title: Text(_getTimeOfDayText(time)),
                value: time,
                groupValue: _currentSchedule?.timeOfDay,
                onChanged: (value) {
                  if (value != null) {
                    final newSchedule = MedicineSchedule(
                      id: _currentSchedule?.id,
                      scheduleType: _currentSchedule?.scheduleType ?? ScheduleType.alternate,
                      timeOfDay: value,
                      defaultDosage: _currentSchedule?.defaultDosage ?? 2.0,
                      interval: _currentSchedule?.interval,
                      customTime: _currentSchedule?.customTime,
                    );
                    _updateSchedule(newSchedule);
                  }
                },
                activeColor: Colors.blue,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDosageCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '默认药量',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _currentSchedule?.defaultDosage.toString() ?? '2.0',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '药量（粒）',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      final dosage = double.tryParse(value) ?? 2.0;
                      final newSchedule = MedicineSchedule(
                        id: _currentSchedule?.id,
                        scheduleType: _currentSchedule?.scheduleType ?? ScheduleType.alternate,
                        timeOfDay: _currentSchedule?.timeOfDay ?? MedicineTimeOfDay.morning,
                        defaultDosage: dosage,
                        interval: _currentSchedule?.interval,
                        customTime: _currentSchedule?.customTime,
                      );
                      _updateSchedule(newSchedule);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                const Text('粒'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomSettingsCard() {
    if (_currentSchedule?.scheduleType != ScheduleType.custom) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '自定义设置',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _currentSchedule?.interval?.toString() ?? '1',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '间隔天数',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      final interval = int.tryParse(value) ?? 1;
                      final newSchedule = MedicineSchedule(
                        id: _currentSchedule?.id,
                        scheduleType: _currentSchedule?.scheduleType ?? ScheduleType.alternate,
                        timeOfDay: _currentSchedule?.timeOfDay ?? MedicineTimeOfDay.morning,
                        defaultDosage: _currentSchedule?.defaultDosage ?? 2.0,
                        interval: interval,
                        customTime: _currentSchedule?.customTime,
                      );
                      _updateSchedule(newSchedule);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                const Text('天'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getScheduleTypeText(ScheduleType type) {
    switch (type) {
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

  String _getScheduleTypeDescription(ScheduleType type) {
    switch (type) {
      case ScheduleType.daily:
        return '每天都需要吃药';
      case ScheduleType.alternate:
        return '单日吃1-3/4粒，双日吃2粒';
      case ScheduleType.weekly:
        return '每周特定日期吃药';
      case ScheduleType.custom:
        return '自定义间隔天数';
    }
  }

  String _getTimeOfDayText(MedicineTimeOfDay time) {
    switch (time) {
      case MedicineTimeOfDay.morning:
        return '上午';
      case MedicineTimeOfDay.afternoon:
        return '下午';
      case MedicineTimeOfDay.evening:
        return '晚上';
      case MedicineTimeOfDay.custom:
        return '自定义时间';
    }
  }
} 