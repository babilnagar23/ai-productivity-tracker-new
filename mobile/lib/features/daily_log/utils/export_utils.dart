import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../routines/data/models/routine_model.dart';

class ExportUtils {
  static Future<void> exportToCsv(List<RoutineModel> routines) async {
    final buf = StringBuffer();
    buf.writeln('Date,Productivity Score,Study Hours,Mobile Usage,Sleep Time,Wake Time');
    for (final r in routines) {
      buf.writeln('${r.date},${r.productivityScore},${r.studyHours},${r.mobileUsage},${r.sleepTime},${r.wakeTime}');
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/productivity_data.csv');
    await file.writeAsString(buf.toString());

    await SharePlus.instance.share(
      ShareParams(
        text: 'CSV Export',
        subject: 'Productivity Tracker CSV Export',
        files: [XFile(file.path, mimeType: 'text/csv')],
      ),
    );
  }

  static Future<void> exportToPdf(List<RoutineModel> routines) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Text('Productivity Tracker Data Export', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            context: context,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headerHeight: 25,
            cellHeight: 25,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
            },
            headers: ['Date', 'Score', 'Study Hrs', 'Mobile Hrs', 'Sleep', 'Wake'],
            data: routines.map((r) {
              return [
                r.date,
                r.productivityScore.toString(),
                r.studyHours.toString(),
                r.mobileUsage.toString(),
                r.sleepTime,
                r.wakeTime,
              ];
            }).toList(),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/productivity_data.pdf');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        text: 'PDF Export',
        subject: 'Productivity Tracker PDF Export',
        files: [XFile(file.path, mimeType: 'application/pdf')],
      ),
    );
  }

  static Future<void> exportToWord(List<RoutineModel> routines) async {
    final buf = StringBuffer();
    buf.writeln('<html><head><meta charset="utf-8"></head><body>');
    buf.writeln('<h1>Productivity Tracker Data Export</h1>');
    buf.writeln('<table border="1" cellpadding="5" cellspacing="0">');
    buf.writeln('<tr>');
    buf.writeln('<th>Date</th>');
    buf.writeln('<th>Productivity Score</th>');
    buf.writeln('<th>Study Hours</th>');
    buf.writeln('<th>Mobile Usage</th>');
    buf.writeln('<th>Sleep Time</th>');
    buf.writeln('<th>Wake Time</th>');
    buf.writeln('</tr>');

    for (final r in routines) {
      buf.writeln('<tr>');
      buf.writeln('<td>${r.date}</td>');
      buf.writeln('<td>${r.productivityScore}</td>');
      buf.writeln('<td>${r.studyHours}</td>');
      buf.writeln('<td>${r.mobileUsage}</td>');
      buf.writeln('<td>${r.sleepTime}</td>');
      buf.writeln('<td>${r.wakeTime}</td>');
      buf.writeln('</tr>');
    }

    buf.writeln('</table></body></html>');

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/productivity_data.doc');
    await file.writeAsString(buf.toString());

    await SharePlus.instance.share(
      ShareParams(
        text: 'Word Export',
        subject: 'Productivity Tracker Word Export',
        files: [XFile(file.path, mimeType: 'application/msword')],
      ),
    );
  }
}
