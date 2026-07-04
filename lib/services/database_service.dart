import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import '../models/seating_plan.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  final _uuid = const Uuid();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    // Use FFI for desktop platforms
    if (!kIsWeb &&
        (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
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
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
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
    final seats = await getSeats(planId);
    final photoPaths = _photoPathsFromSeats(seats);

    await db.transaction((txn) async {
      await txn.delete('seats', where: 'plan_id = ?', whereArgs: [planId]);
      await txn.delete('plans', where: 'id = ?', whereArgs: [planId]);
    });

    for (final photoPath in photoPaths) {
      await _deletePhotoIfUnused(photoPath);
    }
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
    Seat? previous;
    Seat? saved;

    await db.transaction((txn) async {
      if (seat.id != null) {
        previous = await _getSeatById(txn, seat.id!);
        await txn.update(
          'seats',
          seat.toMap(),
          where: 'id = ?',
          whereArgs: [seat.id],
        );
        saved = seat;
      } else {
        final id = await txn.insert('seats', seat.toMap());
        saved = seat.copyWith(id: id);
      }
      await _touchPlan(txn, saved!.planId);
    });

    final previousPhotoPath = previous?.photoPath;
    if (previousPhotoPath != null && previousPhotoPath != saved!.photoPath) {
      await _deletePhotoIfUnused(previousPhotoPath);
    }

    return saved!;
  }

  Future<void> deleteSeat(int seatId) async {
    final db = await database;
    Seat? deleted;

    await db.transaction((txn) async {
      deleted = await _getSeatById(txn, seatId);
      await txn.delete('seats', where: 'id = ?', whereArgs: [seatId]);
      if (deleted != null) {
        await _touchPlan(txn, deleted!.planId);
      }
    });

    final photoPath = deleted?.photoPath;
    if (photoPath != null) {
      await _deletePhotoIfUnused(photoPath);
    }
  }

  Future<void> deleteSeatsForPlan(int planId) async {
    final db = await database;
    final seats = await getSeats(planId);
    final photoPaths = _photoPathsFromSeats(seats);

    await db.transaction((txn) async {
      await txn.delete('seats', where: 'plan_id = ?', whereArgs: [planId]);
      await _touchPlan(txn, planId);
    });

    for (final photoPath in photoPaths) {
      await _deletePhotoIfUnused(photoPath);
    }
  }

  Future<void> moveSeat(
    int planId,
    int fromRow,
    int fromCol,
    int toRow,
    int toCol,
  ) async {
    if (fromRow == toRow && fromCol == toCol) return;

    final db = await database;
    await db.transaction((txn) async {
      final fromSeat = await _getSeatByPosition(txn, planId, fromRow, fromCol);
      if (fromSeat == null || fromSeat.isEmpty) return;

      final toSeat = await _getSeatByPosition(txn, planId, toRow, toCol);

      if (toSeat != null && toSeat.isEmpty) {
        await txn.delete('seats', where: 'id = ?', whereArgs: [toSeat.id]);
      }

      await txn.update(
        'seats',
        fromSeat.copyWith(row: toRow, col: toCol).toMap(),
        where: 'id = ?',
        whereArgs: [fromSeat.id],
      );

      if (toSeat != null && !toSeat.isEmpty) {
        await txn.update(
          'seats',
          toSeat.copyWith(row: fromRow, col: fromCol).toMap(),
          where: 'id = ?',
          whereArgs: [toSeat.id],
        );
      }

      await _touchPlan(txn, planId);
    });
  }

  Future<SeatingPlan> duplicatePlan(
    SeatingPlan original,
    String newName,
  ) async {
    final newPlan = SeatingPlan(
      name: newName,
      rows: original.rows,
      columns: original.columns,
      extraLabel: original.extraLabel,
      groupName: original.groupName,
    );
    final created = await createPlan(newPlan);

    final seats = await getSeats(original.id!);
    for (final seat in seats) {
      final copiedPhotoPath = await _copyPhoto(seat.photoPath);
      await upsertSeat(
        Seat(
          planId: created.id!,
          row: seat.row,
          col: seat.col,
          firstName: seat.firstName,
          lastName: seat.lastName,
          photoPath: copiedPhotoPath,
          extraInfo: seat.extraInfo,
        ),
      );
    }

    return created;
  }

  Future<Seat?> _getSeatById(DatabaseExecutor db, int seatId) async {
    final maps = await db.query(
      'seats',
      where: 'id = ?',
      whereArgs: [seatId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Seat.fromMap(maps.first);
  }

  Future<Seat?> _getSeatByPosition(
    DatabaseExecutor db,
    int planId,
    int row,
    int col,
  ) async {
    final maps = await db.query(
      'seats',
      where: 'plan_id = ? AND row = ? AND col = ?',
      whereArgs: [planId, row, col],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Seat.fromMap(maps.first);
  }

  Future<void> _touchPlan(DatabaseExecutor db, int planId) async {
    await db.update(
      'plans',
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [planId],
    );
  }

  Future<String?> _copyPhoto(String? photoPath) async {
    if (photoPath == null) return null;

    final source = File(photoPath);
    if (!await source.exists()) return null;

    final extension = p.extension(photoPath).isEmpty
        ? '.jpg'
        : p.extension(photoPath);
    final targetPath = p.join(p.dirname(photoPath), '${_uuid.v4()}$extension');
    final copy = await source.copy(targetPath);
    return copy.path;
  }

  Future<void> _deletePhotoIfUnused(String photoPath) async {
    final db = await database;
    final references = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM seats WHERE photo_path = ?',
      [photoPath],
    );
    final count = references.first['count'] as int? ?? 0;
    if (count > 0) return;

    final file = File(photoPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Set<String> _photoPathsFromSeats(Iterable<Seat> seats) {
    return seats.map((seat) => seat.photoPath).whereType<String>().toSet();
  }
}
