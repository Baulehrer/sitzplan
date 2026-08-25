import 'dart:io';
import 'dart:convert';
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
    final bytes = await buildPdf(plan, seats, options: options);

    await Printing.layoutPdf(onLayout: (_) => bytes, name: _fileName(plan));
  }

  Future<Uint8List> buildPdf(
    SeatingPlan plan,
    List<Seat> seats, {
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
    final noPictureMode = !seats.any(
      (seat) => seat.photoPath?.isNotEmpty == true,
    );
    final noPictureFontSize = _noPictureFontSize(plan, seats);

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
                              noPictureMode,
                              noPictureFontSize,
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

    _addClassListPage(pdf, plan, seats, options);
    return pdf.save();
  }

  void _addClassListPage(
    pw.Document pdf,
    SeatingPlan plan,
    List<Seat> seats,
    PdfExportOptions options,
  ) {
    final settings = options.classListSettings;
    final students = _classListStudents(seats, options);
    final width = settings.totalWidthCm * PdfPageFormat.cm;
    final rowHeight = settings.rowHeightCm * PdfPageFormat.cm;
    final remarkWidth = settings.remarksWidthCm * PdfPageFormat.cm / 3;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(PdfPageFormat.cm),
        build: (_) => pw.Align(
          alignment: pw.Alignment.topCenter,
          child: pw.CustomPaint(
            foregroundPainter: (canvas, size) =>
                _drawDashedBorder(canvas, size),
            child: pw.Container(
              width: width,
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Center(
                    child: pw.Text(
                      'Klassenliste',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  _classListColumnHeaders(
                    settings: settings,
                    rowHeight: rowHeight,
                    remarkWidth: remarkWidth,
                    plan: plan,
                  ),
                  pw.Table(
                    columnWidths: {
                      0: pw.FixedColumnWidth(
                        settings.numberWidthCm * PdfPageFormat.cm,
                      ),
                      1: pw.FixedColumnWidth(
                        settings.lastNameWidthCm * PdfPageFormat.cm,
                      ),
                      2: pw.FixedColumnWidth(
                        settings.firstNameWidthCm * PdfPageFormat.cm,
                      ),
                      3: pw.FixedColumnWidth(remarkWidth),
                      4: pw.FixedColumnWidth(remarkWidth),
                      5: pw.FixedColumnWidth(remarkWidth),
                    },
                    border: pw.TableBorder.all(
                      color: PdfColors.black,
                      width: .6,
                    ),
                    children: [
                      for (var index = 0; index < students.length; index++)
                        pw.TableRow(
                          children: [
                            _classListCell(
                              '${index + 1}',
                              rowHeight,
                              align: pw.Alignment.center,
                            ),
                            _classListCell(
                              students[index].lastName ?? '',
                              rowHeight,
                            ),
                            _classListCell(
                              students[index].firstName ?? '',
                              rowHeight,
                            ),
                            _classListCell(
                              students[index].extraInfo ?? '',
                              rowHeight,
                            ),
                            _classListCell(
                              students[index].extraInfo2 ?? '',
                              rowHeight,
                            ),
                            _classListCell(
                              students[index].extraInfo3 ?? '',
                              rowHeight,
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Seat> _classListStudents(List<Seat> seats, PdfExportOptions options) {
    final students = seats.where((seat) => !seat.isEmpty).toList();
    if (options.classListSort == ClassListSort.individual &&
        options.classListOrder != null) {
      return options.classListOrder!.where((seat) => !seat.isEmpty).toList();
    }
    students.sort((a, b) {
      final last = _compareName(a.lastName, b.lastName);
      if (last != 0) return last;
      final first = _compareName(a.firstName, b.firstName);
      if (first != 0) return first;
      final row = a.row.compareTo(b.row);
      return row != 0 ? row : a.col.compareTo(b.col);
    });
    return students;
  }

  int _compareName(String? a, String? b) =>
      (a ?? '').toLowerCase().compareTo((b ?? '').toLowerCase());

  String _extraLabel(SeatingPlan plan, int index) =>
      index < plan.extraLabels.length ? plan.extraLabels[index] : '';

  pw.Widget _classListColumnHeaders({
    required ClassListSettings settings,
    required double rowHeight,
    required double remarkWidth,
    required SeatingPlan plan,
  }) => pw.Column(
    children: [
      pw.Row(
        children: [
          _classListHeader(
            'Nr.',
            rowHeight * 2,
            width: settings.numberWidthCm * PdfPageFormat.cm,
          ),
          _classListHeader(
            'Name',
            rowHeight * 2,
            width: settings.lastNameWidthCm * PdfPageFormat.cm,
          ),
          _classListHeader(
            'Vorname',
            rowHeight * 2,
            width: settings.firstNameWidthCm * PdfPageFormat.cm,
          ),
          _classListHeader('Bemerkungen', rowHeight, width: remarkWidth * 3),
        ],
      ),
      pw.Row(
        children: [
          pw.SizedBox(width: settings.numberWidthCm * PdfPageFormat.cm),
          pw.SizedBox(width: settings.lastNameWidthCm * PdfPageFormat.cm),
          pw.SizedBox(width: settings.firstNameWidthCm * PdfPageFormat.cm),
          _classListHeader(_extraLabel(plan, 0), rowHeight, width: remarkWidth),
          _classListHeader(_extraLabel(plan, 1), rowHeight, width: remarkWidth),
          _classListHeader(_extraLabel(plan, 2), rowHeight, width: remarkWidth),
        ],
      ),
    ],
  );

  pw.Widget _classListHeader(String text, double height, {double? width}) =>
      pw.Container(
        width: width,
        height: height,
        padding: const pw.EdgeInsets.all(3),
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: .6),
        ),
        child: pw.Text(
          text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          maxLines: 2,
        ),
      );

  pw.Widget _classListCell(
    String text,
    double height, {
    pw.Alignment align = pw.Alignment.centerLeft,
  }) => pw.Container(
    height: height,
    padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
    alignment: align,
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 8), maxLines: 1),
  );

  void _drawDashedBorder(PdfGraphics canvas, PdfPoint size) {
    const dash = 4.0;
    const gap = 3.0;
    canvas
      ..setColor(PdfColors.grey700)
      ..setLineWidth(.7);
    void line(double x1, double y1, double x2, double y2) {
      final length = x1 == x2 ? (y2 - y1).abs() : (x2 - x1).abs();
      final direction = x1 == x2
          ? (y2 >= y1 ? 1.0 : -1.0)
          : (x2 >= x1 ? 1.0 : -1.0);
      for (var start = 0.0; start < length; start += dash + gap) {
        final end = (start + dash).clamp(0, length).toDouble();
        if (x1 == x2) {
          canvas
            ..moveTo(x1, y1 + direction * start)
            ..lineTo(x1, y1 + direction * end);
        } else {
          canvas
            ..moveTo(x1 + direction * start, y1)
            ..lineTo(x1 + direction * end, y1);
        }
      }
    }

    line(0, 0, size.x, 0);
    line(size.x, 0, size.x, size.y);
    line(size.x, size.y, 0, size.y);
    line(0, size.y, 0, 0);
    canvas.strokePath();
  }

  pw.Widget _buildCell(
    Seat? seat,
    Map<String, pw.MemoryImage> photoCache,
    int totalRows,
    int totalColumns,
    List<String> extraLabels,
    PdfExportOptions options,
    bool noPictureMode,
    double noPictureFontSize,
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
    if (noPictureMode) {
      return pw.Container(
        height: cellHeight,
        padding: const pw.EdgeInsets.all(6),
        alignment: pw.Alignment.center,
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            if (hasName)
              pw.Text(
                seat.displayName,
                style: pw.TextStyle(
                  fontSize: noPictureFontSize,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
                maxLines: 2,
              ),
            if (hasName && visibleExtras.isNotEmpty) pw.SizedBox(height: 4),
            for (final extra in visibleExtras)
              pw.Text(
                '${extra.label}: ${extra.value}',
                style: pw.TextStyle(
                  fontSize: math.max(6, noPictureFontSize * .55),
                  color: PdfColors.grey700,
                ),
                textAlign: pw.TextAlign.center,
                maxLines: 2,
              ),
          ],
        ),
      );
    }

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

  double _noPictureFontSize(SeatingPlan plan, List<Seat> seats) {
    final cellWidth =
        (PdfPageFormat.a4.landscape.availableWidth - 40) / plan.columns;
    final cellHeight =
        (PdfPageFormat.a4.landscape.availableHeight - 76) / plan.rows;
    var longestName = 1;
    var maximumLines = 1;
    for (final seat in seats.where((seat) => !seat.isEmpty)) {
      longestName = math.max(longestName, seat.displayName.length);
      for (var index = 0; index < seat.extraInfos.length; index++) {
        final value = seat.extraInfos[index];
        if (value?.isNotEmpty != true) continue;
        final label = index < plan.extraLabels.length
            ? plan.extraLabels[index]
            : '';
        final detailLength = label.isEmpty
            ? value!.length
            : label.length + value!.length + 2;
        longestName = math.max(longestName, (detailLength * .55).ceil());
      }
      maximumLines = math.max(
        maximumLines,
        1 + seat.extraInfos.where((value) => value?.isNotEmpty == true).length,
      );
    }
    final widthLimited = (cellWidth - 12) * 2.5 / longestName;
    final heightLimited = (cellHeight - 12) / (1.2 + (maximumLines - 1) * .7);
    return math.min(28, math.max(8, math.min(widthLimited, heightLimited)));
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
  final ClassListSort classListSort;
  final List<Seat>? classListOrder;
  final ClassListSettings classListSettings;

  const PdfExportOptions({
    this.includePhotos = true,
    this.includeNames = true,
    this.includeExtraInfo = true,
    this.photoMode = PdfPhotoMode.auto,
    this.photoBrightness = 1,
    this.photoContrast = 1,
    this.photoGamma = 1,
    this.classListSort = ClassListSort.alphabetical,
    this.classListOrder,
    this.classListSettings = const ClassListSettings(),
  });

  PdfExportOptions copyWith({
    ClassListSort? classListSort,
    List<Seat>? classListOrder,
    ClassListSettings? classListSettings,
  }) => PdfExportOptions(
    includePhotos: includePhotos,
    includeNames: includeNames,
    includeExtraInfo: includeExtraInfo,
    photoMode: photoMode,
    photoBrightness: photoBrightness,
    photoContrast: photoContrast,
    photoGamma: photoGamma,
    classListSort: classListSort ?? this.classListSort,
    classListOrder: classListOrder ?? this.classListOrder,
    classListSettings: classListSettings ?? this.classListSettings,
  );
}

enum PdfPhotoMode { original, auto, manual }

enum ClassListSort { alphabetical, individual }

class ClassListSettings {
  static const storageKey = 'class_list_settings';

  final double numberWidthCm;
  final double lastNameWidthCm;
  final double firstNameWidthCm;
  final double remarksWidthCm;
  final double rowHeightCm;

  const ClassListSettings({
    this.numberWidthCm = 1,
    this.lastNameWidthCm = 3.3,
    this.firstNameWidthCm = 2.6,
    this.remarksWidthCm = 12,
    this.rowHeightCm = .75,
  });

  double get totalWidthCm =>
      numberWidthCm + lastNameWidthCm + firstNameWidthCm + remarksWidthCm;

  bool get isValid =>
      numberWidthCm > 0 &&
      lastNameWidthCm > 0 &&
      firstNameWidthCm > 0 &&
      remarksWidthCm > 0 &&
      rowHeightCm > 0 &&
      totalWidthCm <= 19;

  Map<String, double> toMap() => {
    'numberWidthCm': numberWidthCm,
    'lastNameWidthCm': lastNameWidthCm,
    'firstNameWidthCm': firstNameWidthCm,
    'remarksWidthCm': remarksWidthCm,
    'rowHeightCm': rowHeightCm,
  };

  String toJson() => jsonEncode(toMap());

  factory ClassListSettings.fromJson(String value) {
    try {
      final map = jsonDecode(value) as Map<String, dynamic>;
      final settings = ClassListSettings(
        numberWidthCm: (map['numberWidthCm'] as num?)?.toDouble() ?? 1,
        lastNameWidthCm: (map['lastNameWidthCm'] as num?)?.toDouble() ?? 3.3,
        firstNameWidthCm: (map['firstNameWidthCm'] as num?)?.toDouble() ?? 2.6,
        remarksWidthCm: (map['remarksWidthCm'] as num?)?.toDouble() ?? 12,
        rowHeightCm: (map['rowHeightCm'] as num?)?.toDouble() ?? .75,
      );
      return settings.isValid ? settings : const ClassListSettings();
    } catch (_) {
      return const ClassListSettings();
    }
  }
}
