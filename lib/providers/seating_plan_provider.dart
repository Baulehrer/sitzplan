import 'package:flutter/foundation.dart';
import '../models/seating_plan.dart';
import '../services/database_service.dart';

class SeatingPlanListProvider extends ChangeNotifier {
  final _db = DatabaseService();
  List<SeatingPlan> _plans = [];
  bool _loading = false;

  List<SeatingPlan> get plans => _plans;
  bool get loading => _loading;

  Future<void> loadPlans() async {
    _loading = true;
    notifyListeners();
    _plans = await _db.getPlans();
    _loading = false;
    notifyListeners();
  }

  Future<SeatingPlan> createPlan(String name, int rows, int columns, {String? extraLabel, String? groupName}) async {
    final plan = SeatingPlan(name: name, rows: rows, columns: columns, extraLabel: extraLabel, groupName: groupName);
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

  Future<SeatingPlan> duplicatePlan(SeatingPlan original, String newName) async {
    final created = await _db.duplicatePlan(original, newName);
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
  bool _loading = false;

  SeatingPlan? get plan => _plan;
  List<Seat> get seats => _seats;
  bool get loading => _loading;

  Seat? getSeat(int row, int col) {
    try {
      return _seats.firstWhere((s) => s.row == row && s.col == col);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadPlan(SeatingPlan plan) async {
    _loading = true;
    _plan = plan;
    notifyListeners();
    _seats = await _db.getSeats(plan.id!);
    _loading = false;
    notifyListeners();
  }

  Future<void> saveSeat(Seat seat) async {
    final saved = await _db.upsertSeat(seat);
    final index = _seats.indexWhere((s) => s.row == seat.row && s.col == seat.col);
    if (index >= 0) {
      _seats[index] = saved;
    } else {
      _seats.add(saved);
    }
    notifyListeners();
  }

  Future<void> removeSeat(int row, int col) async {
    final seat = getSeat(row, col);
    if (seat?.id != null) {
      await _db.deleteSeat(seat!.id!);
    }
    _seats.removeWhere((s) => s.row == row && s.col == col);
    notifyListeners();
  }

  /// Move a seat to a new position. If target is occupied, swap both.
  Future<void> moveSeat(int fromRow, int fromCol, int toRow, int toCol) async {
    if (fromRow == toRow && fromCol == toCol) return;

    final fromSeat = getSeat(fromRow, fromCol);
    final toSeat = getSeat(toRow, toCol);

    if (fromSeat == null || fromSeat.isEmpty) return;

    // Update source seat to target position
    final movedSeat = Seat(
      id: fromSeat.id,
      planId: fromSeat.planId,
      row: toRow,
      col: toCol,
      firstName: fromSeat.firstName,
      lastName: fromSeat.lastName,
      photoPath: fromSeat.photoPath,
      extraInfo: fromSeat.extraInfo,
    );
    await _db.upsertSeat(movedSeat);

    if (toSeat != null && !toSeat.isEmpty) {
      // Swap: move target seat to source position
      final swappedSeat = Seat(
        id: toSeat.id,
        planId: toSeat.planId,
        row: fromRow,
        col: fromCol,
        firstName: toSeat.firstName,
        lastName: toSeat.lastName,
        photoPath: toSeat.photoPath,
        extraInfo: toSeat.extraInfo,
      );
      await _db.upsertSeat(swappedSeat);
    } else {
      // Target was empty — remove source
      if (fromSeat.id != null) {
        // We reused the id for the moved seat, so just remove from list
      }
    }

    // Reload seats from DB to get clean state
    if (_plan != null) {
      _seats = await _db.getSeats(_plan!.id!);
      notifyListeners();
    }
  }

  void clear() {
    _plan = null;
    _seats = [];
    notifyListeners();
  }
}
