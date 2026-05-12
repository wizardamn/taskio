import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/project_model.dart';
import '../services/supabase_service.dart';
import '../utils/app_logger.dart';
import '../utils/error_mapper.dart';

class ReportService {
  final SupabaseClient _client =
      SupabaseService.client;

  // =========================================================
  // PUBLIC
  // =========================================================

  Future<pw.Document> generatePdf(
      BuildContext context,
      List<ProjectModel> projects,
      ) async {
    if (projects.isEmpty) {
      throw Exception('projects.empty');
    }

    try {
      return await _buildPdf(
        context,
        projects,
      );
    } catch (e, st) {
      AppLogger.error(
        'PDF generation error',
        error: e,
        stackTrace: st,
      );

      throw Exception(
        ErrorMapper.map(e),
      );
    }
  }

  Future<void> generateAndPrint(
      BuildContext context,
      List<ProjectModel> projects,
      ) async {
    final pdf = await generatePdf(
      context,
      projects,
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
    );
  }

  // =========================================================
  // BUILD PDF
  // =========================================================

  Future<pw.Document> _buildPdf(
      BuildContext context,
      List<ProjectModel> projects,
      ) async {
    final regularFont = pw.Font.ttf(
      await rootBundle.load(
        'assets/fonts/NotoSans-Regular.ttf',
      ),
    );

    final boldFont = pw.Font.ttf(
      await rootBundle.load(
        'assets/fonts/NotoSans-Bold.ttf',
      ),
    );

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
      ),
    );

    final grades =
    await _loadGrades(projects);

    final total = projects.length;

    final planned = projects
        .where(
          (p) =>
      p.statusEnum ==
          ProjectStatus.planned,
    )
        .length;

    final inProgress = projects
        .where(
          (p) =>
      p.statusEnum ==
          ProjectStatus.inProgress,
    )
        .length;

    final completed = projects
        .where(
          (p) =>
      p.statusEnum ==
          ProjectStatus.completed,
    )
        .length;

    final archived = projects
        .where(
          (p) =>
      p.statusEnum ==
          ProjectStatus.archived,
    )
        .length;

    final overdue = projects
        .where(
          (p) =>
      p.deadline.isBefore(
        DateTime.now(),
      ) &&
          p.statusEnum !=
              ProjectStatus.completed,
    )
        .length;

    int totalTasks = 0;
    int completedTasks = 0;

    for (final project in projects) {
      totalTasks += project.totalTasks;
      completedTasks +=
          project.completedTasks;
    }

    final taskProgress =
    totalTasks == 0
        ? 0.0
        : completedTasks /
        totalTasks;

    // =====================================================
    // COVER PAGE
    // =====================================================

    pdf.addPage(
      pw.Page(
        margin:
        const pw.EdgeInsets.all(40),
        build: (_) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment:
              pw.MainAxisAlignment
                  .center,
              children: [
                pw.Container(
                  padding:
                  const pw.EdgeInsets
                      .all(20),
                  decoration:
                  pw.BoxDecoration(
                    color:
                    PdfColors.blue,
                    shape:
                    pw.BoxShape.circle,
                  ),
                  child: pw.Text(
                    'T',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 50,
                      color:
                      PdfColors
                          .white,
                    ),
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Text(
                  'TASKIO',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 38,
                    color:
                    PdfColors.blue,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'report.title'.tr(),
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 22,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  _formatDateTime(
                    DateTime.now(),
                  ),
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: 14,
                    color:
                    PdfColors
                        .grey700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // =====================================================
    // MAIN PAGE
    // =====================================================

    pdf.addPage(
      pw.MultiPage(
        margin:
        const pw.EdgeInsets.all(32),
        build: (_) {
          return [
            _sectionTitle(
              'report.statistics'.tr(),
              boldFont,
            ),

            pw.SizedBox(height: 16),

            _statsGrid(
              total: total,
              planned: planned,
              inProgress: inProgress,
              completed: completed,
              archived: archived,
              overdue: overdue,
              bold: boldFont,
            ),

            pw.SizedBox(height: 28),

            _sectionTitle(
              'report.progress'.tr(),
              boldFont,
            ),

            pw.SizedBox(height: 14),

            _progressBar(
              taskProgress,
            ),

            pw.SizedBox(height: 8),

            pw.Text(
              '$completedTasks / $totalTasks ${'report.tasks_completed'.tr()}',
              style: pw.TextStyle(
                font: regularFont,
                fontSize: 11,
              ),
            ),

            pw.SizedBox(height: 28),

            _sectionTitle(
              'report.participants'.tr(),
              boldFont,
            ),

            pw.SizedBox(height: 14),

            _buildParticipantsStats(
              projects,
              regularFont,
              boldFont,
            ),

            pw.SizedBox(height: 28),

            _sectionTitle(
              'report.projects'.tr(),
              boldFont,
            ),

            pw.SizedBox(height: 14),

            _buildProjectsTable(
              projects,
              grades,
              regularFont,
              boldFont,
            ),

            pw.SizedBox(height: 28),

            _sectionTitle(
              'report.conclusion'.tr(),
              boldFont,
            ),

            pw.SizedBox(height: 14),

            _buildConclusion(
              total: total,
              completed: completed,
              overdue: overdue,
              progress:
              taskProgress,
              font: regularFont,
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  // =========================================================
  // LOAD GRADES
  // =========================================================

  Future<Map<String, double>>
  _loadGrades(
      List<ProjectModel> projects,
      ) async {
    try {
      final ids =
      projects.map((e) => e.id).toList();

      if (ids.isEmpty) {
        return {};
      }

      final response = await _client
          .from('project_grades')
          .select(
        'project_id, grade',
      )
          .inFilter(
        'project_id',
        ids,
      );

      final Map<String, List<double>>
      grouped = {};

      for (final item in response) {
        final projectId =
        item['project_id']
            .toString();

        final grade =
            (item['grade'] as num?)
                ?.toDouble() ??
                0;

        grouped.putIfAbsent(
          projectId,
              () => [],
        );

        grouped[projectId]!
            .add(grade);
      }

      final Map<String, double>
      averages = {};

      grouped.forEach(
            (key, values) {
          if (values.isEmpty) {
            averages[key] = 0;
            return;
          }

          final avg =
              values.reduce(
                    (a, b) => a + b,
              ) /
                  values.length;

          averages[key] = avg;
        },
      );

      return averages;
    } catch (e, st) {
      AppLogger.error(
        'Load grades failed',
        error: e,
        stackTrace: st,
      );

      return {};
    }
  }

  // =========================================================
  // TITLES
  // =========================================================

  pw.Widget _sectionTitle(
      String text,
      pw.Font bold,
      ) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        font: bold,
        fontSize: 18,
      ),
    );
  }

  // =========================================================
  // STATS GRID
  // =========================================================

  pw.Widget _statsGrid({
    required int total,
    required int planned,
    required int inProgress,
    required int completed,
    required int archived,
    required int overdue,
    required pw.Font bold,
  }) {
    return pw.Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _statCard(
          'report.total'.tr(),
          total.toString(),
          PdfColors.blue,
          bold,
        ),
        _statCard(
          'report.planned'.tr(),
          planned.toString(),
          PdfColors.blueGrey,
          bold,
        ),
        _statCard(
          'report.in_progress'.tr(),
          inProgress.toString(),
          PdfColors.orange,
          bold,
        ),
        _statCard(
          'report.completed'.tr(),
          completed.toString(),
          PdfColors.green,
          bold,
        ),
        _statCard(
          'report.archived'.tr(),
          archived.toString(),
          PdfColors.brown,
          bold,
        ),
        _statCard(
          'report.overdue'.tr(),
          overdue.toString(),
          PdfColors.red,
          bold,
        ),
      ],
    );
  }

  pw.Widget _statCard(
      String title,
      String value,
      PdfColor color,
      pw.Font bold,
      ) {
    return pw.Container(
      width: 110,
      padding:
      const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius:
        pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              font: bold,
              fontSize: 18,
              color:
              PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            title,
            textAlign:
            pw.TextAlign.center,
            style: pw.TextStyle(
              font: bold,
              fontSize: 10,
              color:
              PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // PROGRESS
  // =========================================================

  pw.Widget _progressBar(
      double progress,
      ) {
    final safe =
    progress.clamp(0.0, 1.0);

    return pw.Column(
      crossAxisAlignment:
      pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          height: 14,
          decoration:
          pw.BoxDecoration(
            color:
            PdfColors.grey300,
            borderRadius:
            pw.BorderRadius
                .circular(20),
          ),
          child: pw.Stack(
            children: [
              pw.Container(
                width:
                500 * safe,
                decoration:
                pw.BoxDecoration(
                  color:
                  PdfColors.green,
                  borderRadius:
                  pw.BorderRadius
                      .circular(
                    20,
                  ),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          '${(safe * 100).toStringAsFixed(1)}%',
        ),
      ],
    );
  }

  // =========================================================
  // PARTICIPANTS
  // =========================================================

  pw.Widget _buildParticipantsStats(
      List<ProjectModel> projects,
      pw.Font font,
      pw.Font bold,
      ) {
    final Map<String, UserStats>
    stats = {};

    for (final project in projects) {
      for (final user
      in project.participantsData) {
        stats.putIfAbsent(
          user.fullName,
              () => UserStats(),
        );

        stats[user.fullName]!
            .total++;

        if (project.statusEnum ==
            ProjectStatus.completed) {
          stats[user.fullName]!
              .completed++;
        }

        if (project.statusEnum ==
            ProjectStatus.inProgress) {
          stats[user.fullName]!
              .inProgress++;
        }
      }
    }

    if (stats.isEmpty) {
      return pw.Text(
        'No participants',
      );
    }

    return pw.Column(
      children:
      stats.entries.map((e) {
        final s = e.value;

        return pw.Container(
          margin:
          const pw.EdgeInsets.only(
            bottom: 8,
          ),
          padding:
          const pw.EdgeInsets.all(
            10,
          ),
          decoration:
          pw.BoxDecoration(
            border: pw.Border.all(
              color:
              PdfColors.grey300,
            ),
            borderRadius:
            pw.BorderRadius
                .circular(8),
          ),
          child: pw.Row(
            mainAxisAlignment:
            pw.MainAxisAlignment
                .spaceBetween,
            children: [
              pw.Expanded(
                flex: 3,
                child: pw.Text(
                  e.key,
                  style:
                  pw.TextStyle(
                    font: bold,
                    fontSize: 12,
                  ),
                ),
              ),
              pw.Expanded(
                flex: 5,
                child: pw.Text(
                  '${'report.total'.tr()}: ${s.total} | '
                      '${'report.completed'.tr()}: ${s.completed} | '
                      '${'report.in_progress'.tr()}: ${s.inProgress}',
                  textAlign:
                  pw.TextAlign.right,
                  style:
                  pw.TextStyle(
                    font: font,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // =========================================================
  // PROJECTS TABLE
  // =========================================================

  pw.Widget _buildProjectsTable(
      List<ProjectModel> projects,
      Map<String, double> grades,
      pw.Font font,
      pw.Font bold,
      ) {
    return pw.TableHelper.fromTextArray(
      headers: [
        'report.project_name'.tr(),
        'report.deadline'.tr(),
        'report.status'.tr(),
        'report.tasks'.tr(),
        'report.grade'.tr(),
      ],
      data: projects.map((p) {
        final avgGrade =
        grades[p.id];

        return [
          p.title,
          _formatDate(
            p.deadline,
          ),
          _status(p),
          '${p.completedTasks}/${p.totalTasks}',
          avgGrade == null
              ? '-'
              : avgGrade
              .toStringAsFixed(1),
        ];
      }).toList(),
      headerStyle: pw.TextStyle(
        font: bold,
        color: PdfColors.white,
        fontSize: 11,
      ),
      headerDecoration:
      const pw.BoxDecoration(
        color: PdfColors.blue,
      ),
      cellStyle: pw.TextStyle(
        font: font,
        fontSize: 10,
      ),
      cellPadding:
      const pw.EdgeInsets.all(8),
      border: pw.TableBorder.all(
        color: PdfColors.grey400,
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1),
      },
    );
  }

  // =========================================================
  // CONCLUSION
  // =========================================================

  pw.Widget _buildConclusion({
    required int total,
    required int completed,
    required int overdue,
    required double progress,
    required pw.Font font,
  }) {
    return pw.Container(
      padding:
      const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius:
        pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        '${'report.total_projects'.tr()}: $total.\n'
            '${'report.completed_projects'.tr()}: $completed.\n'
            '${'report.overdue_projects'.tr()}: $overdue.\n'
            '${'report.total_progress'.tr()}: '
            '${(progress * 100).toStringAsFixed(1)}%',
        style: pw.TextStyle(
          font: font,
          fontSize: 12,
          lineSpacing: 4,
        ),
      ),
    );
  }

  // =========================================================
  // HELPERS
  // =========================================================

  String _status(
      ProjectModel p,
      ) {
    switch (p.statusEnum) {
      case ProjectStatus.planned:
        return 'status.planned'.tr();

      case ProjectStatus.inProgress:
        return 'status.in_progress'
            .tr();

      case ProjectStatus.completed:
        return 'status.completed'.tr();

      case ProjectStatus.archived:
        return 'status.archived'.tr();
    }
  }

  String _formatDate(
      DateTime date,
      ) {
    final day = date.day
        .toString()
        .padLeft(2, '0');

    final month = date.month
        .toString()
        .padLeft(2, '0');

    return '$day.$month.${date.year}';
  }

  String _formatDateTime(
      DateTime date,
      ) {
    final hour = date.hour
        .toString()
        .padLeft(2, '0');

    final minute = date.minute
        .toString()
        .padLeft(2, '0');

    return '${_formatDate(date)} $hour:$minute';
  }
}

// ===========================================================
// USER STATS
// ===========================================================

class UserStats {
  int total = 0;
  int completed = 0;
  int inProgress = 0;
}