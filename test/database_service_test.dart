import 'package:flutter_test/flutter_test.dart';
import 'package:sitzplan/models/seating_plan.dart';
import 'package:sitzplan/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;
  late DatabaseService service;

  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: DatabaseService.createSchema,
      ),
    );
    service = DatabaseService.forTesting(database);
  });

  tearDown(() => database.close());

  test('seat positions are unique within a plan', () async {
    final plan = await service.createPlan(
      SeatingPlan(name: 'Testplan', rows: 2, columns: 2),
    );
    await service.upsertSeat(
      Seat(planId: plan.id!, row: 0, col: 0, firstName: 'Ada'),
    );

    await expectLater(
      service.upsertSeat(
        Seat(planId: plan.id!, row: 0, col: 0, firstName: 'Grace'),
      ),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('swap and undo restore both positions atomically', () async {
    final plan = await service.createPlan(
      SeatingPlan(name: 'Testplan', rows: 1, columns: 2),
    );
    final ada = await service.upsertSeat(
      Seat(planId: plan.id!, row: 0, col: 0, firstName: 'Ada'),
    );
    final grace = await service.upsertSeat(
      Seat(planId: plan.id!, row: 0, col: 1, firstName: 'Grace'),
    );

    await service.moveSeat(plan.id!, 0, 0, 0, 1);
    var seats = await service.getSeats(plan.id!);
    expect(seats.singleWhere((seat) => seat.col == 0).firstName, 'Grace');
    expect(seats.singleWhere((seat) => seat.col == 1).firstName, 'Ada');

    await service.restoreSeatPositions(plan.id!, [
      SeatPositionSnapshot(row: 0, col: 0, seat: ada),
      SeatPositionSnapshot(row: 0, col: 1, seat: grace),
    ]);
    seats = await service.getSeats(plan.id!);
    expect(seats.singleWhere((seat) => seat.col == 0).firstName, 'Ada');
    expect(seats.singleWhere((seat) => seat.col == 1).firstName, 'Grace');
  });

  test('appearance settings persist in the database', () async {
    expect(await service.getSetting('appearance_palette'), isNull);

    await service.setSetting('appearance_palette', 'forest');

    expect(await service.getSetting('appearance_palette'), 'forest');
  });

  test('version 5 migration creates appearance settings', () async {
    await database.execute('DROP TABLE app_settings');

    await DatabaseService.upgradeSchema(database, 4, 5);
    await service.setSetting('appearance_mode', 'dark');

    expect(await service.getSetting('appearance_mode'), 'dark');
  });

  test('schema contains all three custom fields', () async {
    final planColumns = await database.rawQuery('PRAGMA table_info(plans)');
    final seatColumns = await database.rawQuery('PRAGMA table_info(seats)');

    expect(
      planColumns.map((column) => column['name']),
      containsAll(['extra_label', 'extra_label_2', 'extra_label_3']),
    );
    expect(
      seatColumns.map((column) => column['name']),
      containsAll(['extra_info', 'extra_info_2', 'extra_info_3']),
    );
  });
}
