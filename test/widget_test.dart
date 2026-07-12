import 'package:flutter_test/flutter_test.dart';
import 'package:sitzplan/models/seating_plan.dart';

void main() {
  group('SeatingPlan', () {
    test('toMap and fromMap roundtrip', () {
      final plan = SeatingPlan(
        name: 'Klasse 7a',
        rows: 4,
        columns: 8,
        extraLabel: 'Betrieb',
        extraLabel2: 'Instrument',
        extraLabel3: 'Hinweis',
      );
      final map = plan.toMap();
      expect(map['name'], 'Klasse 7a');
      expect(map['rows'], 4);
      expect(map['columns'], 8);
      expect(map['extra_label'], 'Betrieb');
      expect(map['extra_label_2'], 'Instrument');
      expect(map['extra_label_3'], 'Hinweis');
    });

    test('hasExtraField returns true when label is set', () {
      final plan = SeatingPlan(
        name: 'Test',
        rows: 3,
        columns: 6,
        extraLabel: 'Betrieb',
      );
      expect(plan.hasExtraField, isTrue);
    });

    test('hasExtraField returns false when label is null', () {
      final plan = SeatingPlan(name: 'Test', rows: 3, columns: 6);
      expect(plan.hasExtraField, isFalse);
    });

    test('copyWith creates modified copy', () {
      final plan = SeatingPlan(name: 'Test', rows: 3, columns: 6);
      final copy = plan.copyWith(name: 'Neuer Name', rows: 5);
      expect(copy.name, 'Neuer Name');
      expect(copy.rows, 5);
      expect(copy.columns, 6);
    });

    test('copyWith clears optional labels explicitly', () {
      final plan = SeatingPlan(
        name: 'Test',
        rows: 3,
        columns: 6,
        extraLabel: 'Betrieb',
        groupName: 'Klasse 7a',
      );

      final copy = plan.copyWith(clearExtraLabel: true, clearGroupName: true);

      expect(copy.extraLabel, isNull);
      expect(copy.groupName, isNull);
      expect(copy.name, 'Test');
    });
  });

  group('Seat', () {
    test('isEmpty returns true for empty seat', () {
      final seat = Seat(planId: 1, row: 0, col: 0);
      expect(seat.isEmpty, isTrue);
    });

    test('isEmpty returns false when name is set', () {
      final seat = Seat(planId: 1, row: 0, col: 0, firstName: 'Max');
      expect(seat.isEmpty, isFalse);
    });

    test('isEmpty returns false when extraInfo is set', () {
      final seat = Seat(planId: 1, row: 0, col: 0, extraInfo: 'Firma XY');
      expect(seat.isEmpty, isFalse);
    });

    test('isEmpty returns false when third extra info is set', () {
      final seat = Seat(planId: 1, row: 0, col: 0, extraInfo3: 'Rollstuhl');
      expect(seat.isEmpty, isFalse);
    });

    test('displayName combines first and last name', () {
      final seat = Seat(
        planId: 1,
        row: 0,
        col: 0,
        firstName: 'Max',
        lastName: 'Müller',
      );
      expect(seat.displayName, 'Max Müller');
    });

    test('toMap and fromMap roundtrip with extraInfo', () {
      final seat = Seat(
        id: 1,
        planId: 2,
        row: 3,
        col: 4,
        firstName: 'Anna',
        lastName: 'Schmidt',
        photoPath: '/photos/test.jpg',
        extraInfo: 'Bäckerei Müller',
        extraInfo2: 'Trompete',
        extraInfo3: 'Fensterplatz',
      );
      final map = seat.toMap();
      final restored = Seat.fromMap(map);
      expect(restored.firstName, 'Anna');
      expect(restored.lastName, 'Schmidt');
      expect(restored.extraInfo, 'Bäckerei Müller');
      expect(restored.extraInfo2, 'Trompete');
      expect(restored.extraInfo3, 'Fensterplatz');
      expect(restored.row, 3);
      expect(restored.col, 4);
    });

    test('copyWith moves seat without losing details', () {
      final seat = Seat(
        id: 1,
        planId: 2,
        row: 0,
        col: 1,
        firstName: 'Anna',
        lastName: 'Schmidt',
        photoPath: '/photos/test.jpg',
        extraInfo: 'Bäckerei Müller',
      );

      final moved = seat.copyWith(row: 2, col: 3);

      expect(moved.id, 1);
      expect(moved.planId, 2);
      expect(moved.row, 2);
      expect(moved.col, 3);
      expect(moved.firstName, 'Anna');
      expect(moved.lastName, 'Schmidt');
      expect(moved.photoPath, '/photos/test.jpg');
      expect(moved.extraInfo, 'Bäckerei Müller');
    });
  });
}
