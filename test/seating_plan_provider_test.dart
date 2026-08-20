import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sitzplan/models/seating_plan.dart';
import 'package:sitzplan/providers/seating_plan_provider.dart';
import 'package:sitzplan/screens/editor_screen.dart';
import 'package:sitzplan/services/database_service.dart';
import 'package:sitzplan/theme/app_theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;
  late DatabaseService service;
  late SeatingPlanEditorProvider provider;
  late SeatingPlan plan;

  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 7,
        onCreate: DatabaseService.createSchema,
      ),
    );
    service = DatabaseService.forTesting(database);
    provider = SeatingPlanEditorProvider(database: service, random: Random(7));
    plan = await service.createPlan(
      SeatingPlan(name: 'Testplan', rows: 2, columns: 3),
    );
  });

  tearDown(() => database.close());

  Future<void> addStudent(
    String name,
    int row,
    int col, {
    bool locked = false,
  }) => service.upsertSeat(
    Seat(
      planId: plan.id!,
      row: row,
      col: col,
      firstName: name,
      isLocked: locked,
    ),
  );

  test(
    'shuffle keeps locked students fixed and occupied gaps unchanged',
    () async {
      await addStudent('Fest', 1, 0, locked: true);
      await addStudent('Ada', 1, 1);
      await addStudent('Grace', 0, 2);
      await provider.loadPlan(plan);
      final occupiedBefore = provider.seats
          .map((seat) => '${seat.row}:${seat.col}')
          .toSet();

      final changed = await provider.shuffleSeats(
        ShuffleMode.occupiedPositions,
      );

      expect(changed, isTrue);
      expect(provider.getSeat(1, 0)?.firstName, 'Fest');
      expect(
        provider.seats.map((seat) => '${seat.row}:${seat.col}').toSet(),
        occupiedBefore,
      );
    },
  );

  test(
    'all-place shuffle can distribute students into previous gaps',
    () async {
      await addStudent('Ada', 1, 0);
      await addStudent('Grace', 1, 1);
      await provider.loadPlan(plan);

      final changed = await provider.shuffleSeats(
        ShuffleMode.allAvailablePositions,
      );

      expect(changed, isTrue);
      expect(
        provider.seats.any((seat) => seat.row != 1 || seat.col > 1),
        isTrue,
      );
    },
  );

  test('undo and redo restore exact layout over multiple steps', () async {
    await addStudent('Ada', 1, 0);
    await addStudent('Grace', 1, 1);
    await provider.loadPlan(plan);

    await provider.moveSeat(1, 0, 0, 0);
    await provider.resizePlan(3, 4);
    expect(provider.canUndo, isTrue);
    expect(provider.plan?.rows, 3);

    await provider.undoLayout();
    expect(provider.plan?.rows, 2);
    expect(provider.getSeat(0, 0)?.firstName, 'Ada');

    await provider.undoLayout();
    expect(provider.getSeat(1, 0)?.firstName, 'Ada');
    expect(provider.canRedo, isTrue);

    await provider.redoLayout();
    await provider.redoLayout();
    expect(provider.plan?.columns, 4);
    expect(provider.getSeat(0, 0)?.firstName, 'Ada');
  });

  test('resize reports occupied seats outside the new bounds', () async {
    await addStudent('Rand', 1, 2);
    await provider.loadPlan(plan);

    await expectLater(
      provider.resizePlan(1, 2),
      throwsA(
        isA<LayoutResizeException>().having(
          (error) => error.blockedSeats.single.firstName,
          'blocked student',
          'Rand',
        ),
      ),
    );
  });

  test('findNextFreePosition follows visible grid order and wraps', () async {
    await addStudent('Oben links', 1, 0);
    await addStudent('Oben Mitte', 1, 1);
    await provider.loadPlan(plan);

    final next = provider.findNextFreePosition(1, 1);
    final wrapped = provider.findNextFreePosition(0, 2);

    expect((next?.row, next?.col), (1, 2));
    expect((wrapped?.row, wrapped?.col), (1, 2));
  });

  Future<void> pumpEditor(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          theme: AppTheme.light,
          home: EditorScreen(plan: plan),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      while (provider.loading) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    await tester.pump();
    expect(provider.loading, isFalse);
    expect(provider.error, isNull);
    expect(tester.takeException(), isNull);
  }

  testWidgets('editor desk controls fit compact Android layout', (
    tester,
  ) async {
    await pumpEditor(tester, const Size(360, 800));
    expect(find.text('Plätze mischen'), findsOneWidget);
  });

  testWidgets('editor desk controls fit medium layout', (tester) async {
    await pumpEditor(tester, const Size(800, 900));
    expect(find.byIcon(Icons.casino_outlined), findsOneWidget);
  });
}
