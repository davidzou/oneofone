enum ScheduleType {
  daily,      // 每日
  alternate,  // 单双日
  weekly,     // 每周
  custom      // 自定义间隔
}

enum MedicineTimeOfDay {
  morning,    // 上午
  afternoon,  // 下午
  evening,    // 晚上
  custom      // 自定义时间
}

class MedicineSchedule {
  final int? id;
  final ScheduleType scheduleType;
  final MedicineTimeOfDay timeOfDay;
  final double defaultDosage;
  final int? interval; // 间隔天数，用于自定义间隔
  final String? customTime; // 自定义时间，格式 HH:mm
  final bool isActive;

  MedicineSchedule({
    this.id,
    required this.scheduleType,
    required this.timeOfDay,
    required this.defaultDosage,
    this.interval,
    this.customTime,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'scheduleType': scheduleType.index,
      'timeOfDay': timeOfDay.index,
      'defaultDosage': defaultDosage,
      'interval': interval,
      'customTime': customTime,
      'isActive': isActive ? 1 : 0,
    };
  }

  factory MedicineSchedule.fromMap(Map<String, dynamic> map) {
    return MedicineSchedule(
      id: map['id'],
      scheduleType: ScheduleType.values[map['scheduleType']],
      timeOfDay: MedicineTimeOfDay.values[map['timeOfDay']],
      defaultDosage: map['defaultDosage'],
      interval: map['interval'],
      customTime: map['customTime'],
      isActive: map['isActive'] == 1,
    );
  }

  // 检查今天是否需要吃药
  bool shouldTakeMedicineToday(DateTime today) {
    if (!isActive) return false;
    
    switch (scheduleType) {
      case ScheduleType.daily:
        return true;
      case ScheduleType.alternate:
        // 从2023年10月23日开始计算单双日
        final startDate = DateTime(2023, 10, 23);
        final daysDiff = today.difference(startDate).inDays;
        return daysDiff % 2 == 0;
      case ScheduleType.weekly:
        // 每周特定日期，这里简化为每周一
        return today.weekday == DateTime.monday;
      case ScheduleType.custom:
        if (interval == null) return false;
        final startDate = DateTime(2023, 10, 23);
        final daysDiff = today.difference(startDate).inDays;
        return daysDiff % interval! == 0;
    }
  }

  // 获取今天的药量
  double getDosageForToday(DateTime today) {
    if (scheduleType == ScheduleType.alternate) {
      final startDate = DateTime(2023, 10, 23);
      final daysDiff = today.difference(startDate).inDays;
      return daysDiff % 2 == 0 ? 2.0 : 1.75; // 双日2粒，单日1-3/4粒
    }
    return defaultDosage;
  }
} 