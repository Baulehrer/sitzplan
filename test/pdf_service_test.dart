import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sitzplan/models/seating_plan.dart';
import 'package:sitzplan/services/pdf_service.dart';

void main() {
  Uint8List darkPhoto() {
    final image = img.Image(width: 24, height: 24);
    img.fill(image, color: img.ColorRgb8(18, 20, 24));
    return Uint8List.fromList(img.encodeJpg(image));
  }

  double luminance(Uint8List bytes) {
    final image = img.decodeImage(bytes)!;
    var sum = 0.0;
    for (final pixel in image) {
      sum += pixel.luminanceNormalized;
    }
    return sum / (image.width * image.height);
  }

  test('auto mode makes a dark photo more readable', () {
    final service = PdfService();
    final original = darkPhoto();

    final adjusted = service.preparePhotoForExport(
      original,
      const PdfExportOptions(photoMode: PdfPhotoMode.auto),
    );

    expect(luminance(adjusted), greaterThan(luminance(original) * 2));
  });

  test('original mode leaves encoded photo bytes untouched', () {
    final service = PdfService();
    final original = darkPhoto();

    final adjusted = service.preparePhotoForExport(
      original,
      const PdfExportOptions(photoMode: PdfPhotoMode.original),
    );

    expect(adjusted, same(original));
  });

  test('class-list settings roundtrip and reject an A4 overflow', () {
    const settings = ClassListSettings();

    expect(ClassListSettings.fromJson(settings.toJson()).totalWidthCm, 18.9);
    expect(const ClassListSettings(remarksWidthCm: 13).isValid, isFalse);
  });

  test('PDF contains the seating plan and class-list pages', () async {
    final bytes = await PdfService().buildPdf(
      SeatingPlan(
        name: 'Klasse 7a',
        rows: 1,
        columns: 2,
        extraLabel: 'Betrieb',
      ),
      [
        Seat(
          planId: 1,
          row: 0,
          col: 0,
          firstName: 'Ada',
          lastName: 'Lovelace',
          extraInfo: 'Analytik',
        ),
      ],
    );

    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(bytes.length, greaterThan(1000));
  });

  test('large class lists are split across multiple A4 pages', () async {
    final students = [
      for (var index = 0; index < 100; index++)
        Seat(
          planId: 1,
          row: index ~/ 10,
          col: index % 10,
          firstName: 'Vorname $index',
          lastName: 'Nachname $index',
        ),
    ];
    final bytes = await PdfService().buildPdf(
      SeatingPlan(name: 'Große Klasse', rows: 10, columns: 10),
      students,
    );
    expect(bytes, isNotEmpty);
    expect(
      PdfService.classListPageCount(students.length, const ClassListSettings()),
      greaterThan(1),
    );
  });
}
