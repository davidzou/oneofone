class MedicineRecord {
  final int? id;
  final DateTime date;
  final double dosage;
  final bool isTaken;
  final String? notes;

  MedicineRecord({
    this.id,
    required this.date,
    required this.dosage,
    required this.isTaken,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'dosage': dosage,
      'isTaken': isTaken ? 1 : 0,
      'notes': notes,
    };
  }

  factory MedicineRecord.fromMap(Map<String, dynamic> map) {
    return MedicineRecord(
      id: map['id'],
      date: DateTime.parse(map['date']),
      dosage: map['dosage'],
      isTaken: map['isTaken'] == 1,
      notes: map['notes'],
    );
  }
} 