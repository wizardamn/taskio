import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/project_model.dart';

class ReportService {
  /// Генерация PDF-отчета по списку проектов и вывод на печать/просмотр
  Future<void> generateAndPrint(List<ProjectModel> projects) async {
    if (projects.isEmpty) return;

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          final headers = ['Название', 'Срок', 'Статус', 'Оценка'];

          final data = projects.map((p) {
            return [
              p.title,
              DateFormat('dd.MM.yyyy').format(p.deadline),
              // ✅ ИСПОЛЬЗУЕМ ProjectModel.statusEnum
              _statusRu(p.statusEnum),
              p.grade != null ? p.grade!.toStringAsFixed(1) : '-',
            ];
          }).toList();

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Отчет по проектам учащихся',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'Дата формирования: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: headers,
                data: data,
                cellAlignment: pw.Alignment.centerLeft,
                headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                ),
                cellStyle: const pw.TextStyle(fontSize: 11),
                border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey600),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Всего проектов: ${projects.length}',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  /// Перевод статуса проекта на русский язык
  // ✅ ИСПРАВЛЕНО: Принимает ProjectStatus (enum) и обрабатывает все кейсы
  String _statusRu(ProjectStatus status) {
    switch (status) {
      case ProjectStatus.planned:
        return 'Запланирован';
      case ProjectStatus.inProgress:
        return 'В работе';
      case ProjectStatus.completed:
        return 'Завершён';
      case ProjectStatus.archived: // ✅ ДОБАВЛЕН КЕЙС
        return 'Архивирован';
    }
  }
}