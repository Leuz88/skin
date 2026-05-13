import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/scan_result.dart';
import '../models/patient.dart';
import '../theme/app_theme.dart';
import 'package:flutter/material.dart' show Color;

class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  static PdfColor _pdfColor(Color c) =>
      PdfColor(c.red / 255, c.green / 255, c.blue / 255);

  static const _primaryPdf = PdfColor(0.082, 0.396, 0.753);   // #1565C0
  static const _bgPdf = PdfColor(0.973, 0.98, 0.984);         // #F8FAFB

  Future<void> generateAndPrint(SkinResult result, Patient? patient) async {
    final doc = _buildDocument(result, patient);
    await Printing.layoutPdf(
        onLayout: (_) async => doc.save());
  }

  Future<File> generateAndSave(SkinResult result, Patient? patient) async {
    final doc = _buildDocument(result, patient);
    final bytes = await doc.save();
    final dir = await getApplicationDocumentsDirectory();
    final dateStr =
        DateFormat('yyyyMMdd_HHmm').format(result.measDate);
    final file = File(
        '${dir.path}\\SkinAnalyzer_${dateStr}_${result.patientId.substring(0, 8)}.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  pw.Document _buildDocument(SkinResult result, Patient? patient) {
    final doc = pw.Document(title: 'Referto Analisi Cutanea');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => _buildHeader(result, patient),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 24),
          _buildScoreBanner(result),
          pw.SizedBox(height: 20),
          _buildParametersTable(result),
          pw.SizedBox(height: 20),
          _buildRecommendations(result),
        ],
      ),
    );

    return doc;
  }

  pw.Widget _buildHeader(SkinResult result, Patient? patient) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _primaryPdf, width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Skin Analyzer Pro',
                  style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: _primaryPdf)),
              pw.Text('Referto Analisi Cutanea',
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (patient != null)
                pw.Text('Paziente: ${patient.name}',
                    style: pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(result.measDate),
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey700)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
          'Pagina ${ctx.pageNumber} di ${ctx.pagesCount} · Skin Analyzer Pro',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
    );
  }

  pw.Widget _buildScoreBanner(SkinResult result) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _primaryPdf,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          pw.Column(
            children: [
              pw.Text('Punteggio Medio',
                  style: const pw.TextStyle(
                      color: PdfColors.white70, fontSize: 10)),
              pw.Text(result.averageScore.toStringAsFixed(1),
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.Text('/ 9.9',
              style: const pw.TextStyle(
                  color: PdfColors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  pw.Widget _buildParametersTable(SkinResult result) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(3),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _primaryPdf),
          children: [
            _tableCell('Parametro', bold: true, white: true),
            _tableCell('Score', bold: true, white: true),
            _tableCell('Max', bold: true, white: true),
            _tableCell('Valutazione', bold: true, white: true),
          ],
        ),
        // Rows
        ...SkinParam.values.map((p) {
          final score = result.score(p);
          final range = scoreRangeFor(p, score);
          final rowBg =
              SkinParam.values.indexOf(p).isEven ? _bgPdf : PdfColors.white;
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: rowBg),
            children: [
              _tableCell(p.label),
              _tableCell(score.toStringAsFixed(1)),
              _tableCell('9.9'),
              _tableCell(range.label),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _tableCell(String text,
      {bool bold = false, bool white = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight:
                bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: white ? PdfColors.white : PdfColors.black,
          )),
    );
  }

  pw.Widget _buildRecommendations(SkinResult result) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Note e Raccomandazioni',
              style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaryPdf)),
          pw.SizedBox(height: 8),
          ...SkinParam.values.map((p) {
            final score = result.score(p);
            final range = scoreRangeFor(p, score);
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text('• ${p.label}: ${range.label} (${score.toStringAsFixed(1)})',
                  style: const pw.TextStyle(fontSize: 10)),
            );
          }),
        ],
      ),
    );
  }
}
