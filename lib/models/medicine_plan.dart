class MedicinePlan {
  final int? id;
  final String name;
  final bool isActive;
  final String repeatType; // daily, alternate, weekly, custom
  final String? notes;
  final String planType; // 'course' or 'longterm'
  final int? totalDoses; // 疗程型时为总次数/总量，长期型为null
  final String? unit; // 单位，如粒、片、mg

  MedicinePlan({
    this.id,
    required this.name,
    this.isActive = true,
    this.repeatType = 'daily',
    this.notes,
    this.planType = 'longterm',
    this.totalDoses,
    this.unit,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isActive': isActive ? 1 : 0,
      'repeatType': repeatType,
      'notes': notes,
      'planType': planType,
      'totalDoses': totalDoses,
      'unit': unit,
    };
  }

  factory MedicinePlan.fromMap(Map<String, dynamic> map) {
    return MedicinePlan(
      id: map['id'],
      name: map['name'],
      isActive: map['isActive'] == 1,
      repeatType: map['repeatType'],
      notes: map['notes'],
      planType: map['planType'] ?? 'longterm',
      totalDoses: map['totalDoses'],
      unit: map['unit'],
    );
  }
}
