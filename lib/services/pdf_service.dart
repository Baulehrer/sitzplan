import 'dart:io';
import 'package:flutter/material.dart' show BuildContext;
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
          photoCache[seat.photoPath!] = pw.MemoryImage(bytes);
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
                  border: pw.TableBorder.all(
                    color: PdfColors.grey600,
                    width: 0.8,
                  ),
                  children: [
                    for (int r = 0; r < plan.rows; r++)
                      pw.TableRow(
                        children: [
                          for (int c = 0; c < plan.columns; c++)
                            _buildCell(
                              seatMap['${r}_$c'],
                              photoCache,
                              plan.rows,
                              plan.hasExtraField && options.includeExtraInfo,
                              options,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
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
    bool hasExtraField,
    PdfExportOptions options,
  ) {
    final cellHeight =
        (PdfPageFormat.a4.landscape.availableHeight - 52) / totalRows;
    // Photo takes most of the cell
    final photoSize = cellHeight * 0.65;

    // Empty cell — still shows the grid border
    if (seat == null || seat.isEmpty) {
      return pw.Container(height: cellHeight);
    }

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

          // Vorname — kleiner
          if (options.includeNames &&
              seat.firstName != null &&
              seat.firstName!.isNotEmpty)
            pw.Text(
              seat.firstName!,
              style: const pw.TextStyle(fontSize: 7),
              textAlign: pw.TextAlign.center,
              maxLines: 1,
            ),

          // Nachname — größer und fett
          if (options.includeNames &&
              seat.lastName != null &&
              seat.lastName!.isNotEmpty)
            pw.Text(
              seat.lastName!,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
              maxLines: 1,
            ),

          // Extra-Info — klein, unter dem Namen
          if (hasExtraField &&
              seat.extraInfo != null &&
              seat.extraInfo!.isNotEmpty)
            pw.Text(
              seat.extraInfo!,
              style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
              textAlign: pw.TextAlign.center,
              maxLines: 1,
            ),
        ],
      ),
    );
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

  const PdfExportOptions({
    this.includePhotos = true,
    this.includeNames = true,
    this.includeExtraInfo = true,
  });
}
