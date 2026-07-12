import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
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
}
