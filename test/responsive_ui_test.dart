import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sitzplan/models/seating_plan.dart';
import 'package:sitzplan/theme/app_theme.dart';
import 'package:sitzplan/widgets/seat_card.dart';

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

    expect(find.text('Alexandra'), findsOneWidget);
    expect(find.text('Mustermann-Schneider'), findsOneWidget);
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
