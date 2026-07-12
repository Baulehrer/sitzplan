import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart' show BuildContext;
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/seating_plan.dart';

class PdfService {
  Future<void> exportAndShare(
    SeatingPlan plan,
    List<Seat> seats,
    BuildContext context, {
    PdfExportOptions options = const PdfExportOptions(),
  }) async {
    final pdf = pw.Document();

    // Build seat lookup
    final seatMap = <String, Seat>{};
    for (final seat in seats) {
      seatMap['${seat.row}_${seat.col}'] = seat;
    }

    // Load photos
    final photoCache = <String, pw.MemoryImage>{};
    for (final seat in seats) {
      if (options.includePhotos && seat.photoPath != null) {
        final file = File(seat.photoPath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final adjustedBytes = preparePhotoForExport(bytes, options);
          photoCache[seat.photoPath!] = pw.MemoryImage(adjustedBytes);
        }
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Title
              pw.Center(
                child: pw.Text(
                  plan.name,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 12),

              // Grid — Raster immer sichtbar (alle Zellen haben Rahmen)
              pw.Expanded(
                child: pw.Table(
                  columnWidths: {
                    for (int c = 0; c < plan.columns; c++)
                      c: const pw.FlexColumnWidth(1),
                  },
                  border: pw.TableBorder.all(
                    color: PdfColors.grey600,
                    width: 0.8,
                  ),
                  children: [
                    for (int r = plan.rows - 1; r >= 0; r--)
                      pw.TableRow(
                        children: [
                          for (int c = 0; c < plan.columns; c++)
                            _buildCell(
                              seatMap['${r}_$c'],
                              photoCache,
                              plan.rows,
                              plan.columns,
                              plan.extraLabels,
                              options,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              _buildBoardMarker(),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) => pdf.save(),
      name: _fileName(plan),
    );
  }

  pw.Widget _buildCell(
    Seat? seat,
    Map<String, pw.MemoryImage> photoCache,
    int totalRows,
    int totalColumns,
    List<String> extraLabels,
    PdfExportOptions options,
  ) {
    final cellHeight =
        (PdfPageFormat.a4.landscape.availableHeight - 76) / totalRows;

    // Empty cell — still shows the grid border
    if (seat == null || seat.isEmpty) {
      return pw.Container(height: cellHeight);
    }

    final visibleExtras = <({String label, String value})>[
      if (options.includeExtraInfo)
        for (var index = 0; index < seat.extraInfos.length; index++)
          if (seat.extraInfos[index]?.isNotEmpty == true &&
              index < extraLabels.length)
            (label: extraLabels[index], value: seat.extraInfos[index]!),
    ];
    final hasName = options.includeNames && seat.displayName.isNotEmpty;
    final textHeight = (hasName ? 11.0 : 0) + visibleExtras.length * 7.0;
    final cellWidth =
        (PdfPageFormat.a4.landscape.availableWidth - 40) / totalColumns;
    final photoSize = math.max(
      10.0,
      math.min(cellWidth - 8, cellHeight - textHeight - 8),
    );

    return pw.Container(
      height: cellHeight,
      padding: const pw.EdgeInsets.all(3),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          // Photo — large
          if (options.includePhotos &&
              seat.photoPath != null &&
              photoCache.containsKey(seat.photoPath))
            pw.Container(
              width: photoSize,
              height: photoSize,
              child: pw.ClipRRect(
                horizontalRadius: 4,
                verticalRadius: 4,
                child: pw.Image(
                  photoCache[seat.photoPath!]!,
                  fit: pw.BoxFit.cover,
                ),
              ),
            )
          else
            pw.Container(
              width: photoSize,
              height: photoSize,
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              alignment: pw.Alignment.center,
              child: pw.Text(
                _initials(seat),
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey500,
                ),
              ),
            ),
          pw.SizedBox(height: 2),

          if (hasName)
            pw.Text(
              seat.displayName,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
              maxLines: 1,
            ),
          for (final extra in visibleExtras)
            pw.Text(
              '${extra.label}: ${extra.value}',
              style: const pw.TextStyle(
                fontSize: 5.5,
                color: PdfColors.grey700,
              ),
              textAlign: pw.TextAlign.center,
              maxLines: 1,
            ),
        ],
      ),
    );
  }

  pw.Widget _buildBoardMarker() => pw.Row(
    children: [
      pw.Expanded(child: pw.Divider(color: PdfColors.grey600, thickness: 1.4)),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10),
        child: pw.Text(
          'TAFEL · LEHRERPOSITION',
          style: pw.TextStyle(
            fontSize: 7,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
      ),
      pw.Expanded(child: pw.Divider(color: PdfColors.grey600, thickness: 1.4)),
    ],
  );

  Uint8List preparePhotoForExport(Uint8List bytes, PdfExportOptions options) {
    if (options.photoMode == PdfPhotoMode.original) return bytes;
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    var brightness = options.photoBrightness;
    var contrast = options.photoContrast;
    var gamma = options.photoGamma;
    if (options.photoMode == PdfPhotoMode.auto) {
      final luminance = _averageLuminance(decoded);
      brightness = (0.58 / luminance.clamp(0.08, 0.85)).clamp(0.88, 3.0);
      contrast = luminance < 0.22 ? 0.92 : 1.06;
      gamma = luminance < 0.22 ? 0.70 : (luminance < 0.45 ? 0.82 : 0.94);
    }

    final adjusted = img.adjustColor(
      decoded,
      brightness: brightness,
      contrast: contrast,
      gamma: gamma,
    );
    return Uint8List.fromList(img.encodeJpg(adjusted, quality: 92));
  }

  double _averageLuminance(img.Image image) {
    final stepX = (image.width / 80).ceil().clamp(1, image.width);
    final stepY = (image.height / 80).ceil().clamp(1, image.height);
    var sum = 0.0;
    var count = 0;
    for (var y = 0; y < image.height; y += stepY) {
      for (var x = 0; x < image.width; x += stepX) {
        sum += image.getPixel(x, y).luminanceNormalized;
        count++;
      }
    }
    return count == 0 ? 0.5 : sum / count;
  }

  String _initials(Seat seat) {
    final f = seat.firstName?.isNotEmpty == true ? seat.firstName![0] : '';
    final l = seat.lastName?.isNotEmpty == true ? seat.lastName![0] : '';
    return '$f$l'.toUpperCase();
  }

  String _fileName(SeatingPlan plan) {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final safeName = plan.name
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9ÄÖÜäöüß_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return '${safeName.isEmpty ? 'Sitzplan' : safeName}_Sitzplan_$date.pdf';
  }
}

class PdfExportOptions {
  final bool includePhotos;
  final bool includeNames;
  final bool includeExtraInfo;
  final PdfPhotoMode photoMode;
  final double photoBrightness;
  final double photoContrast;
  final double photoGamma;

  const PdfExportOptions({
    this.includePhotos = true,
    this.includeNames = true,
    this.includeExtraInfo = true,
    this.photoMode = PdfPhotoMode.auto,
    this.photoBrightness = 1,
    this.photoContrast = 1,
    this.photoGamma = 1,
  });
}

enum PdfPhotoMode { original, auto, manual }
