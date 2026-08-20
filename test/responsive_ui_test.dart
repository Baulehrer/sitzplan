import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sitzplan/models/seating_plan.dart';
import 'package:sitzplan/theme/app_theme.dart';
import 'package:sitzplan/widgets/seat_card.dart';
import 'package:sitzplan/screens/seat_detail_screen.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required Size viewport,
    Seat? seat,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(
            size: viewport,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 150,
                height: 178,
                child: SeatCard(seat: seat, onTap: () {}),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('empty seat remains usable on a compact viewport', (
    tester,
  ) async {
    await pumpCard(tester, viewport: const Size(360, 800));

    expect(find.text('Frei'), findsOneWidget);
    expect(find.byType(SeatCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filled seat tolerates large system text without overflow', (
    tester,
  ) async {
    await pumpCard(
      tester,
      viewport: const Size(800, 1280),
      textScale: 1.6,
      seat: Seat(
        planId: 1,
        row: 0,
        col: 0,
        firstName: 'Alexandra',
        lastName: 'Mustermann-Schneider',
        extraInfo: 'Orchester und Theater',
      ),
    );

    expect(find.text('Alexandra Mustermann-Schneider'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filled seat exposes shuffle lock control', (tester) async {
    var locked = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 160,
            height: 190,
            child: SeatCard(
              seat: Seat(planId: 1, row: 0, col: 0, firstName: 'Ada'),
              onTap: () {},
              onLockChanged: (value) => locked = value,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Beim Mischen fixieren'));
    expect(locked, isTrue);
  });

  testWidgets('no-picture seat uses large text without a photo placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: 180,
            height: 210,
            child: SeatCard(
              seat: Seat(
                planId: 1,
                row: 0,
                col: 0,
                firstName: 'Ada',
                lastName: 'Lovelace',
                extraInfo: 'Fensterplatz',
              ),
              extraLabels: const ['Bemerkung'],
              showPhoto: false,
              noPhotoFontSize: 30,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    final name = tester.widget<Text>(find.text('Ada Lovelace'));
    expect(name.style?.fontSize, 30);
    expect(find.text('Bemerkung: Fensterplatz'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('seat editor offers save and continue on compact screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SeatDetailScreen(
            planId: 1,
            row: 0,
            col: 0,
            onSave: (_) async {},
          ),
        ),
      ),
    );

    expect(find.text('Speichern'), findsOneWidget);
    expect(find.text('Speichern & weiter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme exposes compact and expanded breakpoints', (tester) async {
    late bool compact;
    late bool expanded;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            compact = UiBreakpoints.isCompact(context);
            expanded = UiBreakpoints.isExpanded(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(compact, isFalse);
    expect(expanded, isFalse);
  });
}
