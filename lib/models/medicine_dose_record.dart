class MedicineDoseRecord {
  final int? id;
  final int planId;
  final int doseOrder;
  final DateTime date;
  final double dosage;
  final bool isTaken;
  final String? notes;

  MedicineDoseRecord({
    this.id,
    required this.planId,
    required this.doseOrder,
    required this.date,
    required this.dosage,
    required this.isTaken,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'planId': planId,
      'doseOrder': doseOrder,
      'date': date.toIso8601String(), // 保留完整时间
      'dosage': dosage,
      'isTaken': isTaken ? 1 : 0,
      'notes': notes,
    };
  }

  factory MedicineDoseRecord.fromMap(Map<String, dynamic> map) {
    return MedicineDoseRecord(
      id: map['id'],
      planId: map['planId'],
      doseOrder: map['doseOrder'],
      date: DateTime.parse(map['date']),
      dosage: map['dosage'],
      isTaken: map['isTaken'] == 1,
      notes: map['notes'],
    );
  }
} 