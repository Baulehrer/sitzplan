import 'dart:collection';
import 'dart:math';

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
  final DatabaseService _db;
  final Random _random;
  SeatingPlan? _plan;
  List<Seat> _seats = [];
  Map<String, Seat> _seatByPosition = {};
  bool _loading = false;
  Object? _error;
  final List<_LayoutHistoryEntry> _undoStack = [];
  final List<_LayoutHistoryEntry> _redoStack = [];

  SeatingPlanEditorProvider({DatabaseService? database, Random? random})
    : _db = database ?? DatabaseService(),
      _random = random ?? Random();

  SeatingPlan? get plan => _plan;
  UnmodifiableListView<Seat> get seats => UnmodifiableListView(_seats);
  bool get loading => _loading;
  Object? get error => _error;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  String? get undoLabel => canUndo ? _undoStack.last.label : null;
  String? get redoLabel => canRedo ? _redoStack.last.label : null;

  Seat? getSeat(int row, int col) => _seatByPosition[_positionKey(row, col)];

  Future<void> loadPlan(SeatingPlan plan) async {
    _loading = true;
    _error = null;
    _plan = plan;
    _clearHistory();
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
    _clearHistory();
    notifyListeners();
  }

  Future<void> removeSeat(int row, int col) async {
    final seat = getSeat(row, col);
    if (seat?.id != null) {
      await _db.deleteSeat(seat!.id!);
    }
    _seats.removeWhere((s) => s.row == row && s.col == col);
    _seatByPosition.remove(_positionKey(row, col));
    _clearHistory();
    notifyListeners();
  }

  Future<void> clearSeats() async {
    if (_plan == null) return;
    await _db.deleteSeatsForPlan(_plan!.id!);
    _setSeats([]);
    _clearHistory();
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
    _clearHistory();
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
    _clearHistory();
    notifyListeners();
    return added;
  }

  /// Move a seat to a new position. If target is occupied, swap both.
  Future<void> moveSeat(int fromRow, int fromCol, int toRow, int toCol) async {
    if (fromRow == toRow && fromCol == toCol) return;

    final fromSeat = getSeat(fromRow, fromCol);
    if (_plan == null || fromSeat == null || fromSeat.isEmpty) return;

    final target = getSeat(toRow, toCol);
    final updated = List<Seat>.from(_seats);
    final fromIndex = updated.indexWhere((seat) => seat.id == fromSeat.id);
    updated[fromIndex] = fromSeat.copyWith(row: toRow, col: toCol);
    if (target != null && !target.isEmpty) {
      final targetIndex = updated.indexWhere((seat) => seat.id == target.id);
      updated[targetIndex] = target.copyWith(row: fromRow, col: fromCol);
    }
    await _commitLayout('Platzwechsel', _plan!, updated);
  }

  Future<void> setSeatLocked(int row, int col, bool locked) async {
    final seat = getSeat(row, col);
    if (seat == null || seat.isEmpty || seat.isLocked == locked) return;
    final saved = await _db.upsertSeat(seat.copyWith(isLocked: locked));
    final index = _seats.indexWhere((item) => item.id == saved.id);
    _seats[index] = saved;
    _rebuildSeatIndex();
    _clearHistory();
    notifyListeners();
  }

  Future<bool> shuffleSeats(ShuffleMode mode) async {
    if (_plan == null) return false;
    final movable = _seats
        .where((seat) => !seat.isEmpty && !seat.isLocked)
        .toList();
    if (movable.length < 2) return false;

    final lockedPositions = {
      for (final seat in _seats.where((seat) => seat.isLocked))
        _positionKey(seat.row, seat.col),
    };
    final available = mode == ShuffleMode.occupiedPositions
        ? movable.map((seat) => _GridPosition(seat.row, seat.col)).toList()
        : [
            for (var row = 0; row < _plan!.rows; row++)
              for (var col = 0; col < _plan!.columns; col++)
                if (!lockedPositions.contains(_positionKey(row, col)))
                  _GridPosition(row, col),
          ];

    List<_GridPosition>? targets;
    for (var attempt = 0; attempt < 8; attempt++) {
      final candidate = List<_GridPosition>.from(available)..shuffle(_random);
      final selected = candidate.take(movable.length).toList();
      if (_positionsChanged(movable, selected)) {
        targets = selected;
        break;
      }
    }
    targets ??= _firstChangedAssignment(movable, available);
    if (targets == null) return false;

    final movableIds = movable.map((seat) => seat.id).toSet();
    final updated = _seats
        .where((seat) => !movableIds.contains(seat.id))
        .toList();
    for (var index = 0; index < movable.length; index++) {
      updated.add(
        movable[index].copyWith(
          row: targets[index].row,
          col: targets[index].col,
        ),
      );
    }
    await _commitLayout('Zufallsverteilung', _plan!, updated);
    return true;
  }

  Future<void> resizePlan(int rows, int columns) async {
    if (_plan == null || (rows == _plan!.rows && columns == _plan!.columns)) {
      return;
    }
    final blocked = _seats
        .where((seat) => seat.row >= rows || seat.col >= columns)
        .toList();
    if (blocked.isNotEmpty) throw LayoutResizeException(blocked);
    await _commitLayout(
      'Raumgröße geändert',
      _plan!.copyWith(rows: rows, columns: columns),
      _seats,
    );
  }

  Future<void> undoLayout() async {
    if (!canUndo) return;
    final entry = _undoStack.removeLast();
    await _applySnapshot(entry.before);
    _redoStack.add(entry);
    notifyListeners();
  }

  Future<void> redoLayout() async {
    if (!canRedo) return;
    final entry = _redoStack.removeLast();
    await _applySnapshot(entry.after);
    _undoStack.add(entry);
    notifyListeners();
  }

  SeatGridPosition? findNextFreePosition(int row, int col) {
    if (_plan == null) return null;
    final positions = [
      for (var currentRow = _plan!.rows - 1; currentRow >= 0; currentRow--)
        for (var currentCol = 0; currentCol < _plan!.columns; currentCol++)
          SeatGridPosition(currentRow, currentCol),
    ];
    final currentIndex = positions.indexWhere(
      (position) => position.row == row && position.col == col,
    );
    for (var offset = 1; offset < positions.length; offset++) {
      final position = positions[(currentIndex + offset) % positions.length];
      final seat = getSeat(position.row, position.col);
      if (seat == null || seat.isEmpty) return position;
    }
    return null;
  }

  void clear() {
    _plan = null;
    _setSeats([]);
    _clearHistory();
    notifyListeners();
  }

  Future<void> _commitLayout(
    String label,
    SeatingPlan updatedPlan,
    List<Seat> updatedSeats,
  ) async {
    final before = _snapshot();
    final after = _LayoutSnapshot(updatedPlan, List<Seat>.from(updatedSeats));
    await _db.replacePlanLayout(updatedPlan, updatedSeats);
    _plan = updatedPlan;
    _setSeats(updatedSeats);
    _undoStack.add(_LayoutHistoryEntry(label, before, after));
    if (_undoStack.length > 50) _undoStack.removeAt(0);
    _redoStack.clear();
    notifyListeners();
  }

  Future<void> _applySnapshot(_LayoutSnapshot snapshot) async {
    await _db.replacePlanLayout(snapshot.plan, snapshot.seats);
    _plan = snapshot.plan;
    _setSeats(snapshot.seats);
  }

  _LayoutSnapshot _snapshot() =>
      _LayoutSnapshot(_plan!, List<Seat>.from(_seats));

  void _clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
  }

  bool _positionsChanged(List<Seat> seats, List<_GridPosition> positions) {
    for (var index = 0; index < seats.length; index++) {
      if (seats[index].row != positions[index].row ||
          seats[index].col != positions[index].col) {
        return true;
      }
    }
    return false;
  }

  List<_GridPosition>? _firstChangedAssignment(
    List<Seat> seats,
    List<_GridPosition> positions,
  ) {
    for (var offset = 1; offset < positions.length; offset++) {
      final candidate = [
        for (var index = 0; index < seats.length; index++)
          positions[(index + offset) % positions.length],
      ];
      if (_positionsChanged(seats, candidate)) return candidate;
    }
    return null;
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

enum ShuffleMode { occupiedPositions, allAvailablePositions }

class LayoutResizeException implements Exception {
  final List<Seat> blockedSeats;

  const LayoutResizeException(this.blockedSeats);
}

class SeatGridPosition {
  final int row;
  final int col;

  const SeatGridPosition(this.row, this.col);
}

class _GridPosition {
  final int row;
  final int col;

  const _GridPosition(this.row, this.col);
}

class _LayoutSnapshot {
  final SeatingPlan plan;
  final List<Seat> seats;

  const _LayoutSnapshot(this.plan, this.seats);
}

class _LayoutHistoryEntry {
  final String label;
  final _LayoutSnapshot before;
  final _LayoutSnapshot after;

  const _LayoutHistoryEntry(this.label, this.before, this.after);
}
