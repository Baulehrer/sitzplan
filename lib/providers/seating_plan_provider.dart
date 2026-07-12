import 'dart:collection';

import 'package:flutter/foundation.dart';
import '../models/seating_plan.dart';
import '../services/database_service.dart';
import '../services/import_export_service.dart';

class SeatingPlanListProvider extends ChangeNotifier {
  final _db = DatabaseService();
  List<SeatingPlan> _plans = [];
  bool _loading = false;
  Object? _error;

  UnmodifiableListView<SeatingPlan> get plans => UnmodifiableListView(_plans);
  bool get loading => _loading;
  Object? get error => _error;

  Future<void> loadPlans() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _plans = await _db.getPlans();
    } catch (error) {
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<SeatingPlan> createPlan(
    String name,
    int rows,
    int columns, {
    String? extraLabel,
    String? extraLabel2,
    String? extraLabel3,
    String? groupName,
  }) async {
    final plan = SeatingPlan(
      name: name,
      rows: rows,
      columns: columns,
      extraLabel: extraLabel,
      extraLabel2: extraLabel2,
      extraLabel3: extraLabel3,
      groupName: groupName,
    );
    final created = await _db.createPlan(plan);
    _plans.insert(0, created);
    notifyListeners();
    return created;
  }

  Future<void> deletePlan(int planId) async {
    await _db.deletePlan(planId);
    _plans.removeWhere((p) => p.id == planId);
    notifyListeners();
  }

  Future<void> updatePlan(SeatingPlan plan) async {
    await _db.updatePlan(plan);
    final index = _plans.indexWhere((p) => p.id == plan.id);
    if (index >= 0) {
      _plans[index] = plan.copyWith(updatedAt: DateTime.now());
      notifyListeners();
    }
  }

  Future<SeatingPlan> duplicatePlan(
    SeatingPlan original,
    String newName, {
    bool copySeats = true,
    bool includePhotos = true,
  }) async {
    final created = await _db.duplicatePlan(
      original,
      newName,
      copySeats: copySeats,
      includePhotos: includePhotos,
    );
    _plans.insert(0, created);
    notifyListeners();
    return created;
  }

  Future<void> renamePlan(SeatingPlan plan, String newName) async {
    final updated = plan.copyWith(name: newName);
    await _db.updatePlan(updated);
    final index = _plans.indexWhere((p) => p.id == plan.id);
    if (index >= 0) {
      _plans[index] = updated.copyWith(updatedAt: DateTime.now());
      notifyListeners();
    }
  }
}

class SeatingPlanEditorProvider extends ChangeNotifier {
  final _db = DatabaseService();
  SeatingPlan? _plan;
  List<Seat> _seats = [];
  Map<String, Seat> _seatByPosition = {};
  bool _loading = false;
  Object? _error;

  SeatingPlan? get plan => _plan;
  UnmodifiableListView<Seat> get seats => UnmodifiableListView(_seats);
  bool get loading => _loading;
  Object? get error => _error;

  Seat? getSeat(int row, int col) => _seatByPosition[_positionKey(row, col)];

  Future<void> loadPlan(SeatingPlan plan) async {
    _loading = true;
    _error = null;
    _plan = plan;
    notifyListeners();
    try {
      _setSeats(await _db.getSeats(plan.id!));
    } catch (error) {
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> saveSeat(Seat seat) async {
    if (seat.isEmpty) {
      await removeSeat(seat.row, seat.col);
      return;
    }
    final saved = await _db.upsertSeat(seat);
    final index = _seats.indexWhere(
      (s) => s.id == saved.id || (s.row == saved.row && s.col == saved.col),
    );
    if (index >= 0) {
      _seats[index] = saved;
    } else {
      _seats.add(saved);
    }
    _rebuildSeatIndex();
    notifyListeners();
  }

  Future<void> removeSeat(int row, int col) async {
    final seat = getSeat(row, col);
    if (seat?.id != null) {
      await _db.deleteSeat(seat!.id!);
    }
    _seats.removeWhere((s) => s.row == row && s.col == col);
    _seatByPosition.remove(_positionKey(row, col));
    notifyListeners();
  }

  Future<void> clearSeats() async {
    if (_plan == null) return;
    await _db.deleteSeatsForPlan(_plan!.id!);
    _setSeats([]);
    notifyListeners();
  }

  Future<int> fillFreeSeatsFromCsv(List<CsvStudent> students) async {
    if (_plan == null || students.isEmpty) return 0;

    var added = 0;
    for (var row = 0; row < _plan!.rows; row++) {
      for (var col = 0; col < _plan!.columns; col++) {
        if (added >= students.length) break;
        final existing = getSeat(row, col);
        if (existing != null && !existing.isEmpty) continue;

        final student = students[added];
        await _db.upsertSeat(
          Seat(
            planId: _plan!.id!,
            row: row,
            col: col,
            firstName: student.firstName,
            lastName: student.lastName,
            extraInfo: _plan!.hasExtraField ? student.extraInfo : null,
            extraInfo2: _plan!.extraLabels.length > 1
                ? student.extraInfo2
                : null,
            extraInfo3: _plan!.extraLabels.length > 2
                ? student.extraInfo3
                : null,
          ),
        );
        added++;
      }
    }

    _setSeats(await _db.getSeats(_plan!.id!));
    notifyListeners();
    return added;
  }

  Future<int> fillFreeSeatsWithPhotos(List<String> photoPaths) async {
    if (_plan == null || photoPaths.isEmpty) return 0;

    var added = 0;
    for (var row = 0; row < _plan!.rows; row++) {
      for (var col = 0; col < _plan!.columns; col++) {
        if (added >= photoPaths.length) break;
        final existing = getSeat(row, col);
        if (existing != null && !existing.isEmpty) continue;

        await _db.upsertSeat(
          Seat(
            planId: _plan!.id!,
            row: row,
            col: col,
            photoPath: photoPaths[added],
          ),
        );
        added++;
      }
    }

    _setSeats(await _db.getSeats(_plan!.id!));
    notifyListeners();
    return added;
  }

  /// Move a seat to a new position. If target is occupied, swap both.
  Future<void> moveSeat(int fromRow, int fromCol, int toRow, int toCol) async {
    if (fromRow == toRow && fromCol == toCol) return;

    final fromSeat = getSeat(fromRow, fromCol);
    if (_plan == null || fromSeat == null || fromSeat.isEmpty) return;

    await _db.moveSeat(_plan!.id!, fromRow, fromCol, toRow, toCol);
    _setSeats(await _db.getSeats(_plan!.id!));
    notifyListeners();
  }

  Future<void> restorePositions(List<SeatSnapshot> snapshots) async {
    if (_plan == null) return;
    await _db.restoreSeatPositions(
      _plan!.id!,
      snapshots
          .map(
            (snapshot) => SeatPositionSnapshot(
              row: snapshot.row,
              col: snapshot.col,
              seat: snapshot.seat,
            ),
          )
          .toList(),
    );
    _setSeats(await _db.getSeats(_plan!.id!));
    notifyListeners();
  }

  void clear() {
    _plan = null;
    _setSeats([]);
    notifyListeners();
  }

  void _setSeats(List<Seat> seats) {
    _seats = List<Seat>.from(seats);
    _rebuildSeatIndex();
  }

  void _rebuildSeatIndex() {
    _seatByPosition = {
      for (final seat in _seats) _positionKey(seat.row, seat.col): seat,
    };
  }

  String _positionKey(int row, int col) => '$row:$col';
}

class SeatSnapshot {
  final int row;
  final int col;
  final Seat? seat;

  const SeatSnapshot({
    required this.row,
    required this.col,
    required this.seat,
  });
}
