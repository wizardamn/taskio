import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../models/project_model.dart';
import '../../providers/project_provider.dart';
import '../../services/report_service.dart';
import '../../utils/snackbar_manager.dart';
import '../../utils/error_mapper.dart';
import '../../utils/app_logger.dart';

class ExportScreen extends StatefulWidget {
  final String projectId;

  const ExportScreen({
    super.key,
    required this.projectId,
  });

  @override
  State<ExportScreen> createState() =>
      _ExportScreenState();
}

class _ExportScreenState
    extends State<ExportScreen> {
  final ReportService _reportService =
  ReportService();

  pw.Document? _pdf;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      _generate();
    });
  }

  // =========================================================
  // GENERATE
  // =========================================================

  Future<void> _generate() async {
    final provider =
    context.read<ProjectProvider>();

    final ProjectModel? project =
        provider.projects.where((p) => p.id == widget.projectId).cast<ProjectModel?>().firstOrNull;

    if (project == null) {
      SnackbarManager.showWarning(
        'projects.not_found'.tr(),
      );
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final pdf =
      await _reportService.generatePdf(
        context,
        [project],
      );

      if (!mounted) return;

      setState(() {
        _pdf = pdf;
      });

      SnackbarManager.showSuccess(
        'report.generated'.tr(),
      );
    } catch (e, st) {
      AppLogger.error(
        'Export generate error',
        error: e,
        stackTrace: st,
      );

      if (!mounted) return;

      SnackbarManager.showError(
        ErrorMapper.map(e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // =========================================================
  // SHARE / SAVE
  // =========================================================

  Future<void> _sharePdf() async {
    if (_pdf == null) return;

    try {
      final bytes =
      await _pdf!.save();

      await Printing.sharePdf(
        bytes: bytes,
        filename:
        'taskio_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      SnackbarManager.showSuccess(
        'report.saved'.tr(),
      );
    } catch (e, st) {
      AppLogger.error(
        'Share PDF error',
        error: e,
        stackTrace: st,
      );

      SnackbarManager.showError(
        ErrorMapper.map(e),
      );
    }
  }

  // =========================================================
  // PRINT
  // =========================================================

  Future<void> _print() async {
    if (_pdf == null) return;

    try {
      await Printing.layoutPdf(
        onLayout: (_) async =>
            _pdf!.save(),
      );
    } catch (e, st) {
      AppLogger.error(
        'Print error',
        error: e,
        stackTrace: st,
      );

      SnackbarManager.showError(
        ErrorMapper.map(e),
      );
    }
  }

  // =========================================================
  // EMPTY STATE
  // =========================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Icon(
              Icons.picture_as_pdf_outlined,
              size: 72,
              color: Theme.of(context)
                  .colorScheme
                  .outline,
            ),
            const SizedBox(height: 16),
            Text(
              'report.no_preview'.tr(),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'export.title'.tr(),
        ),
        actions: [
          IconButton(
            icon:
            const Icon(Icons.refresh),
            tooltip:
            'common.refresh'.tr(),
            onPressed:
            _isLoading
                ? null
                : _generate,
          ),
          IconButton(
            icon:
            const Icon(Icons.share),
            tooltip:
            'common.share'.tr(),
            onPressed:
            _pdf == null
                ? null
                : _sharePdf,
          ),
          IconButton(
            icon:
            const Icon(Icons.print),
            tooltip:
            'common.print'.tr(),
            onPressed:
            _pdf == null
                ? null
                : _print,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child:
        CircularProgressIndicator(),
      )
          : _pdf == null
          ? _buildEmptyState()
          : PdfPreview(
        build:
            (format) async =>
            _pdf!.save(),
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat:
        true,
        canChangeOrientation:
        true,
        canDebug: false,
        pdfFileName:
        'taskio_report.pdf',
        loadingWidget:
        const Center(
          child:
          CircularProgressIndicator(),
        ),
      ),
    );
  }
}