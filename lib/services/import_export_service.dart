import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CsvStudent {
  final String? firstName;
  final String? lastName;
  final String? extraInfo;

  const CsvStudent({this.firstName, this.lastName, this.extraInfo});

  bool get isEmpty =>
      (firstName == null || firstName!.isEmpty) &&
      (lastName == null || lastName!.isEmpty) &&
      (extraInfo == null || extraInfo!.isEmpty);
}

class ImportExportService {
  Future<List<CsvStudent>> pickCsvStudents() async {
    const typeGroup = XTypeGroup(label: 'CSV', extensions: ['csv']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return [];

    final text = await File(file.path).readAsString();
    final rows = const LineSplitter()
        .convert(text)
        .map(_parseCsvLine)
        .where((row) => row.any((cell) => cell.trim().isNotEmpty))
        .toList();
    if (rows.isEmpty) return [];

    final hasHeader = rows.first
        .map((cell) => cell.trim().toLowerCase())
        .any((cell) => cell == 'vorname' || cell == 'firstname');
    final dataRows = hasHeader ? rows.skip(1) : rows;

    return dataRows
        .map((row) {
          String? value(int index) {
            if (index >= row.length) return null;
            final trimmed = row[index].trim();
            return trimmed.isEmpty ? null : trimmed;
          }

          return CsvStudent(
            firstName: value(0),
            lastName: value(1),
            extraInfo: value(2),
          );
        })
        .where((student) => !student.isEmpty)
        .toList();
  }

  Future<String?> exportBackup() async {
    final saveLocation = await getSaveLocation(
      suggestedName: 'sitzplan-backup-${_dateStamp()}.zip',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'ZIP', extensions: ['zip']),
      ],
    );
    if (saveLocation == null) return null;

    final documents = await getApplicationDocumentsDirectory();
    final sourceDir = Directory(p.join(documents.path, 'sitzplan'));
    if (!await sourceDir.exists()) {
      throw Exception('Keine Sitzplan-Daten zum Sichern gefunden');
    }

    final encoder = ZipFileEncoder();
    encoder.create(saveLocation.path);
    await for (final entity in sourceDir.list(recursive: true)) {
      if (entity is File) {
        final relativePath = p.relative(entity.path, from: sourceDir.path);
        await encoder.addFile(entity, p.join('sitzplan', relativePath));
      }
    }
    encoder.close();
    return saveLocation.path;
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if ((char == ',' || char == ';') && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString());
    return result;
  }

  String _dateStamp() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
