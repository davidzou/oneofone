class MedicineDose {
  final int? id;
  final int planId;
  final int doseOrder; // 第几次（1、2、3、4...）
  final double dosage; // 药量
  final String suggestTime; // 建议时间，格式HH:mm

  MedicineDose({
    this.id,
    required this.planId,
    required this.doseOrder,
    required this.dosage,
    required this.suggestTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'planId': planId,
      'doseOrder': doseOrder,
      'dosage': dosage,
      'suggestTime': suggestTime,
    };
  }

  factory MedicineDose.fromMap(Map<String, dynamic> map) {
    return MedicineDose(
      id: map['id'],
      planId: map['planId'],
      doseOrder: map['doseOrder'],
      dosage: map['dosage'],
      suggestTime: map['suggestTime'],
    );
  }
} 