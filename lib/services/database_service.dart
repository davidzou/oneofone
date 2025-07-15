import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/medicine_record.dart';
import '../models/medicine_schedule.dart';
import '../models/medicine_plan.dart';
import '../models/medicine_dose.dart';
import '../models/medicine_dose_record.dart';

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
    // 吃药记录表
    await db.execute('''
      CREATE TABLE medicine_records(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        dosage REAL NOT NULL,
        isTaken INTEGER NOT NULL,
        notes TEXT
      )
    ''');

    // 吃药计划表
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

    // 新增：多次吃药计划表
    await db.execute('''
      CREATE TABLE medicine_plans(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        isActive INTEGER NOT NULL,
        repeatType TEXT NOT NULL,
        notes TEXT,
        planType TEXT NOT NULL DEFAULT 'longterm',
        totalDoses INTEGER,
        unit TEXT
      )
    ''');
    // 新增：单次剂量表
    await db.execute('''
      CREATE TABLE medicine_doses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        planId INTEGER NOT NULL,
        doseOrder INTEGER NOT NULL,
        dosage REAL NOT NULL,
        suggestTime TEXT NOT NULL,
        FOREIGN KEY(planId) REFERENCES medicine_plans(id) ON DELETE CASCADE
      )
    ''');

    // 新增：多次吃药实际记录表
    await db.execute('''
      CREATE TABLE medicine_dose_records(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        planId INTEGER NOT NULL,
        doseOrder INTEGER NOT NULL,
        date TEXT NOT NULL,
        dosage REAL NOT NULL,
        isTaken INTEGER NOT NULL,
        notes TEXT,
        UNIQUE(planId, doseOrder, date)
      )
    ''');

    // 插入默认的单双日计划
    await db.insert('medicine_schedules', {
      'scheduleType': 1,
      'timeOfDay': 0,
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

  // 获取指定日期的吃药记录（只保留年月日）
  Future<MedicineRecord?> getMedicineRecordForDate(DateTime date) async {
    final db = await database;
    final dateOnly = DateTime(date.year, date.month, date.day);
    final dateStr = dateOnly.toIso8601String();
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

  // 记录今天吃药（有则更新，无则插入）
  Future<void> recordMedicineTaken(double dosage, {String? notes}) async {
    final today = DateTime.now();
    final dateOnly = DateTime(today.year, today.month, today.day);
    final schedule = await getCurrentSchedule();
    final dosageToTake = schedule?.getDosageForToday(dateOnly) ?? dosage;
    final exist = await getMedicineRecordForDate(dateOnly);
    final record = MedicineRecord(
      id: exist?.id,
      date: dateOnly,
      dosage: dosageToTake,
      isTaken: true,
      notes: notes,
    );
    if (exist == null) {
      await insertMedicineRecord(record);
    } else {
      await updateMedicineRecord(record);
    }
  }

  // ========== 多次吃药计划相关 ==========
  Future<int> insertMedicinePlan(MedicinePlan plan) async {
    final db = await database;
    return await db.insert('medicine_plans', plan.toMap());
  }

  Future<int> updateMedicinePlan(MedicinePlan plan) async {
    final db = await database;
    return await db.update('medicine_plans', plan.toMap(), where: 'id = ?', whereArgs: [plan.id]);
  }

  Future<int> deleteMedicinePlan(int id) async {
    final db = await database;
    return await db.delete('medicine_plans', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<MedicinePlan>> getAllMedicinePlans() async {
    final db = await database;
    final maps = await db.query('medicine_plans', orderBy: 'id DESC');
    return maps.map((e) => MedicinePlan.fromMap(e)).toList();
  }

  // ========== 单次剂量相关 ==========
  Future<int> insertMedicineDose(MedicineDose dose) async {
    final db = await database;
    return await db.insert('medicine_doses', dose.toMap());
  }

  Future<int> updateMedicineDose(MedicineDose dose) async {
    final db = await database;
    return await db.update('medicine_doses', dose.toMap(), where: 'id = ?', whereArgs: [dose.id]);
  }

  Future<int> deleteMedicineDose(int id) async {
    final db = await database;
    return await db.delete('medicine_doses', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<MedicineDose>> getDosesByPlanId(int planId) async {
    final db = await database;
    final maps = await db.query('medicine_doses', where: 'planId = ?', whereArgs: [planId], orderBy: 'doseOrder ASC');
    return maps.map((e) => MedicineDose.fromMap(e)).toList();
  }

  // ========== 多次吃药实际记录相关 ==========
  Future<int> insertDoseRecord(MedicineDoseRecord record) async {
    final db = await database;
    return await db.insert('medicine_dose_records', record.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<MedicineDoseRecord?> getDoseRecord(int planId, int doseOrder, DateTime date) async {
    final db = await database;
    final dateOnly = DateTime(date.year, date.month, date.day).toIso8601String();
    final maps = await db.query(
      'medicine_dose_records',
      where: 'planId = ? AND doseOrder = ? AND date = ?',
      whereArgs: [planId, doseOrder, dateOnly],
    );
    if (maps.isNotEmpty) {
      return MedicineDoseRecord.fromMap(maps.first);
    }
    return null;
  }

  Future<List<MedicineDoseRecord>> getDoseRecordsForDate(DateTime date) async {
    final db = await database;
    final dateOnly = DateTime(date.year, date.month, date.day).toIso8601String();
    final maps = await db.query(
      'medicine_dose_records',
      where: 'date = ?',
      whereArgs: [dateOnly],
    );
    return maps.map((e) => MedicineDoseRecord.fromMap(e)).toList();
  }

  Future<List<MedicineDoseRecord>> getDoseRecordsForDateRange(DateTime startDate, DateTime endDate) async {
    final db = await database;
    final startStr = DateTime(startDate.year, startDate.month, startDate.day).toIso8601String();
    final endStr = DateTime(endDate.year, endDate.month, endDate.day).toIso8601String();
    final maps = await db.query(
      'medicine_dose_records',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startStr, endStr],
      orderBy: 'date DESC',
    );
    return maps.map((e) => MedicineDoseRecord.fromMap(e)).toList();
  }

  Future<List<MedicineDoseRecord>> getDoseRecordsByPlanId(int planId) async {
    final db = await database;
    final maps = await db.query(
      'medicine_dose_records',
      where: 'planId = ?',
      whereArgs: [planId],
    );
    return maps.map((e) => MedicineDoseRecord.fromMap(e)).toList();
  }
} 