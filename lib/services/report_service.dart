import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/project_model.dart';
import '../utils/app_logger.dart';
import '../utils/error_mapper.dart';

class ReportService {
  /// Генерация PDF-отчета по проектам
  Future<void> generateAndPrint(
      List<ProjectModel> projects) async {
    if (projects.isEmpty) return;

    try {
      AppLogger.info('Generating project report');

      final pdf = pw.Document();

      /// Unicode шрифты
      final font = await PdfGoogleFonts.robotoRegular();
      final boldFont = await PdfGoogleFonts.robotoBold();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) {
            final headers = [
              'projects.name'.tr(),
              'projects.deadline'.tr(),
              'projects.status'.tr(),
              'projects.grade'.tr(),
            ];

            final data = projects.map((p) {
              return [
                p.title,
                _formatDate(p.deadline),
                _localizedStatus(p),
                p.grade != null
                    ? p.grade!.toStringAsFixed(1)
                    : '-',
              ];
            }).toList();

            return pw.Column(
              crossAxisAlignment:
              pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'report.title'.tr(),
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 22,
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  '${'report.generated_at'.tr()}: '
                      '${_formatDateTime(DateTime.now())}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 12,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.TableHelper.fromTextArray(
                  headers: headers,
                  data: data,
                  headerDecoration:
                  const pw.BoxDecoration(
                      color: PdfColors.grey300),
                  headerStyle: pw.TextStyle(
                    font: boldFont,
                    fontSize: 12,
                  ),
                  cellStyle: pw.TextStyle(
                    font: font,
                    fontSize: 11,
                  ),
                  cellAlignment:
                  pw.Alignment.centerLeft,
                  border: pw.TableBorder.all(
                    width: 0.5,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  '${'report.total_projects'.tr()}: '
                      '${projects.length}',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 12,
                  ),
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
      );

      AppLogger.info('Report generated');
    } catch (e, st) {
      AppLogger.error('Report error', e);
      AppLogger.error('StackTrace', st);
      throw Exception(ErrorMapper.map(e));
    }
  }

  // =========================================================
  // LOCAL HELPERS
  // =========================================================

  String _localizedStatus(ProjectModel project) {
    // PDF не имеет BuildContext,
    // поэтому используем .tr() напрямую
    switch (project.statusEnum) {
      case ProjectStatus.planned:
        return 'status.planned'.tr();
      case ProjectStatus.inProgress:
        return 'status.in_progress'.tr();
      case ProjectStatus.completed:
        return 'status.completed'.tr();
      case ProjectStatus.archived:
        return 'status.archived'.tr();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}