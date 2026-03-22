import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/seating_plan.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    // Use FFI for desktop platforms
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'sitzplan', 'sitzplan.db');

    // Ensure directory exists
    await Directory(p.dirname(dbPath)).create(recursive: true);

    return await openDatabase(
      dbPath,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE plans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            rows INTEGER NOT NULL,
            columns INTEGER NOT NULL,
            extra_label TEXT,
            group_name TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE seats (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            plan_id INTEGER NOT NULL,
            row INTEGER NOT NULL,
            col INTEGER NOT NULL,
            first_name TEXT,
            last_name TEXT,
            photo_path TEXT,
            extra_info TEXT,
            FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE CASCADE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE plans ADD COLUMN extra_label TEXT');
          await db.execute('ALTER TABLE seats ADD COLUMN extra_info TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE plans ADD COLUMN group_name TEXT');
        }
      },
    );
  }

  // --- Plans ---

  Future<List<SeatingPlan>> getPlans() async {
    final db = await database;
    final maps = await db.query('plans', orderBy: 'updated_at DESC');
    return maps.map((m) => SeatingPlan.fromMap(m)).toList();
  }

  Future<SeatingPlan> createPlan(SeatingPlan plan) async {
    final db = await database;
    final id = await db.insert('plans', plan.toMap());
    return plan.copyWith(id: id);
  }

  Future<void> updatePlan(SeatingPlan plan) async {
    final db = await database;
    await db.update(
      'plans',
      plan.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [plan.id],
    );
  }

  Future<void> deletePlan(int planId) async {
    final db = await database;
    // Delete associated photos
    final seats = await getSeats(planId);
    for (final seat in seats) {
      if (seat.photoPath != null) {
        final file = File(seat.photoPath!);
        if (await file.exists()) await file.delete();
      }
    }
    await db.delete('seats', where: 'plan_id = ?', whereArgs: [planId]);
    await db.delete('plans', where: 'id = ?', whereArgs: [planId]);
  }

  // --- Seats ---

  Future<List<Seat>> getSeats(int planId) async {
    final db = await database;
    final maps = await db.query(
      'seats',
      where: 'plan_id = ?',
      whereArgs: [planId],
      orderBy: 'row ASC, col ASC',
    );
    return maps.map((m) => Seat.fromMap(m)).toList();
  }

  Future<Seat> upsertSeat(Seat seat) async {
    final db = await database;
    if (seat.id != null) {
      await db.update('seats', seat.toMap(), where: 'id = ?', whereArgs: [seat.id]);
      return seat;
    } else {
      final id = await db.insert('seats', seat.toMap());
      return seat.copyWith(id: id);
    }
  }

  Future<void> deleteSeat(int seatId) async {
    final db = await database;
    await db.delete('seats', where: 'id = ?', whereArgs: [seatId]);
  }

  Future<void> deleteSeatsForPlan(int planId) async {
    final db = await database;
    await db.delete('seats', where: 'plan_id = ?', whereArgs: [planId]);
  }

  Future<SeatingPlan> duplicatePlan(SeatingPlan original, String newName) async {
    final newPlan = SeatingPlan(
      name: newName,
      rows: original.rows,
      columns: original.columns,
      extraLabel: original.extraLabel,
      groupName: original.groupName,
    );
    final created = await createPlan(newPlan);

    // Copy all seats
    final seats = await getSeats(original.id!);
    for (final seat in seats) {
      await upsertSeat(Seat(
        planId: created.id!,
        row: seat.row,
        col: seat.col,
        firstName: seat.firstName,
        lastName: seat.lastName,
        photoPath: seat.photoPath, // Reference same photo file
        extraInfo: seat.extraInfo,
      ));
    }

    return created;
  }
}
