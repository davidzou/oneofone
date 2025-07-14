import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/medicine_record.dart';
import '../models/medicine_schedule.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'medicine_records.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 创建吃药记录表
    await db.execute('''
      CREATE TABLE medicine_records(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        dosage REAL NOT NULL,
        isTaken INTEGER NOT NULL,
        notes TEXT
      )
    ''');

    // 创建吃药计划表
    await db.execute('''
      CREATE TABLE medicine_schedules(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scheduleType INTEGER NOT NULL,
        timeOfDay INTEGER NOT NULL,
        defaultDosage REAL NOT NULL,
        interval INTEGER,
        customTime TEXT,
        isActive INTEGER NOT NULL
      )
    ''');

    // 插入默认的单双日计划
    await db.insert('medicine_schedules', {
      'scheduleType': ScheduleType.alternate.index,
      'timeOfDay': MedicineTimeOfDay.morning.index,
      'defaultDosage': 2.0,
      'interval': null,
      'customTime': null,
      'isActive': 1,
    });
  }

  // 插入吃药记录
  Future<int> insertMedicineRecord(MedicineRecord record) async {
    final db = await database;
    return await db.insert('medicine_records', record.toMap());
  }

  // 更新吃药记录
  Future<int> updateMedicineRecord(MedicineRecord record) async {
    final db = await database;
    return await db.update(
      'medicine_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  // 获取指定日期的吃药记录
  Future<MedicineRecord?> getMedicineRecordForDate(DateTime date) async {
    final db = await database;
    final dateStr = DateTime(date.year, date.month, date.day).toIso8601String();
    final List<Map<String, dynamic>> maps = await db.query(
      'medicine_records',
      where: 'date LIKE ?',
      whereArgs: ['$dateStr%'],
    );

    if (maps.isNotEmpty) {
      return MedicineRecord.fromMap(maps.first);
    }
    return null;
  }

  // 获取指定日期范围的吃药记录
  Future<List<MedicineRecord>> getMedicineRecordsForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final startStr = DateTime(startDate.year, startDate.month, startDate.day).toIso8601String();
    final endStr = DateTime(endDate.year, endDate.month, endDate.day).toIso8601String();
    
    final List<Map<String, dynamic>> maps = await db.query(
      'medicine_records',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startStr, endStr],
      orderBy: 'date DESC',
    );

    return List.generate(maps.length, (i) => MedicineRecord.fromMap(maps[i]));
  }

  // 获取当前吃药计划
  Future<MedicineSchedule?> getCurrentSchedule() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'medicine_schedules',
      where: 'isActive = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return MedicineSchedule.fromMap(maps.first);
    }
    return null;
  }

  // 更新吃药计划
  Future<int> updateMedicineSchedule(MedicineSchedule schedule) async {
    final db = await database;
    if (schedule.id != null) {
      return await db.update(
        'medicine_schedules',
        schedule.toMap(),
        where: 'id = ?',
        whereArgs: [schedule.id],
      );
    } else {
      return await db.insert('medicine_schedules', schedule.toMap());
    }
  }

  // 检查今天是否已经吃过药
  Future<bool> hasTakenMedicineToday() async {
    final today = DateTime.now();
    final record = await getMedicineRecordForDate(today);
    return record?.isTaken ?? false;
  }

  // 记录今天吃药
  Future<void> recordMedicineTaken(double dosage, {String? notes}) async {
    final today = DateTime.now();
    final schedule = await getCurrentSchedule();
    final dosageToTake = schedule?.getDosageForToday(today) ?? dosage;
    
    final record = MedicineRecord(
      date: today,
      dosage: dosageToTake,
      isTaken: true,
      notes: notes,
    );

    await insertMedicineRecord(record);
  }
} 