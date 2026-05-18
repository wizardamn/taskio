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
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final ReportService _reportService = ReportService();

  pw.Document? _pdf;

  ReportScope _scope = ReportScope.singleProject;

  final Set<String> _selectedProjectIds = {};

  bool _isLoading = false;
  bool _initializedSelection = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _initSelection();
    });
  }

  // =========================================================
  // INIT
  // =========================================================

  void _initSelection() {
    if (_initializedSelection) {
      return;
    }

    final projects = context.read<ProjectProvider>().projects;
    final currentProject = _findCurrentProject(projects);

    if (currentProject != null) {
      _selectedProjectIds.add(currentProject.id);
      _scope = ReportScope.singleProject;
    } else if (projects.isNotEmpty) {
      _selectedProjectIds.add(projects.first.id);
      _scope = ReportScope.selectedProjects;
    }

    setState(() {
      _initializedSelection = true;
    });
  }

  ProjectModel? _findCurrentProject(
      List<ProjectModel> projects,
      ) {
    for (final project in projects) {
      if (project.id == widget.projectId) {
        return project;
      }
    }

    return null;
  }

  // =========================================================
  // PROJECT SELECTION
  // =========================================================

  List<ProjectModel> _projectsForReport(
      List<ProjectModel> projects,
      ) {
    switch (_scope) {
      case ReportScope.singleProject:
        final currentProject = _findCurrentProject(projects);

        if (currentProject == null) {
          return [];
        }

        return [currentProject];

      case ReportScope.selectedProjects:
        return projects.where((project) {
          return _selectedProjectIds.contains(project.id);
        }).toList();

      case ReportScope.allProjects:
        return List<ProjectModel>.from(projects);
    }
  }

  ReportOptions _reportOptions() {
    return ReportOptions(
      scope: _scope,
    );
  }

  void _changeScope(ReportScope? scope) {
    if (scope == null) {
      return;
    }

    final projects = context.read<ProjectProvider>().projects;

    setState(() {
      _scope = scope;
      _pdf = null;

      if (scope == ReportScope.singleProject) {
        _selectedProjectIds.clear();

        final currentProject = _findCurrentProject(projects);

        if (currentProject != null) {
          _selectedProjectIds.add(currentProject.id);
        }
      }

      if (scope == ReportScope.allProjects) {
        _selectedProjectIds
          ..clear()
          ..addAll(
            projects.map((project) => project.id),
          );
      }

      if (scope == ReportScope.selectedProjects &&
          _selectedProjectIds.isEmpty) {
        final currentProject = _findCurrentProject(projects);

        if (currentProject != null) {
          _selectedProjectIds.add(currentProject.id);
        } else if (projects.isNotEmpty) {
          _selectedProjectIds.add(projects.first.id);
        }
      }
    });
  }

  void _toggleProjectSelection(
      ProjectModel project,
      bool selected,
      ) {
    setState(() {
      _pdf = null;

      if (selected) {
        _selectedProjectIds.add(project.id);
      } else {
        _selectedProjectIds.remove(project.id);
      }
    });
  }

  void _selectAllProjects(
      List<ProjectModel> projects,
      ) {
    setState(() {
      _pdf = null;

      _selectedProjectIds
        ..clear()
        ..addAll(
          projects.map((project) => project.id),
        );
    });
  }

  void _clearSelectedProjects() {
    setState(() {
      _pdf = null;
      _selectedProjectIds.clear();
    });
  }

  // =========================================================
  // GENERATE
  // =========================================================

  Future<void> _generate() async {
    final provider = context.read<ProjectProvider>();
    final allProjects = provider.projects;

    if (allProjects.isEmpty) {
      SnackbarManager.showWarning(
        'projects.empty'.tr(),
      );
      return;
    }

    final projects = _projectsForReport(allProjects);

    if (projects.isEmpty) {
      SnackbarManager.showWarning(
        'export.no_projects_selected'.tr(),
      );
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final pdf = await _reportService.generatePdf(
        context,
        projects,
        options: _reportOptions(),
      );

      if (!mounted) {
        return;
      }

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
        tag: 'ExportScreen',
      );

      if (!mounted) {
        return;
      }

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
    final pdf = _pdf;

    if (pdf == null) {
      return;
    }

    try {
      final bytes = await pdf.save();

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
        tag: 'ExportScreen',
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
    final pdf = _pdf;

    if (pdf == null) {
      return;
    }

    try {
      await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
      );
    } catch (e, st) {
      AppLogger.error(
        'Print error',
        error: e,
        stackTrace: st,
        tag: 'ExportScreen',
      );

      SnackbarManager.showError(
        ErrorMapper.map(e),
      );
    }
  }

  // =========================================================
  // UI: SETTINGS
  // =========================================================

  Widget _buildReportSettings(
      List<ProjectModel> projects,
      ) {
    final selectedCount = _projectsForReport(projects).length;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'export.report_type'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            RadioGroup<ReportScope>(
              groupValue: _scope,
              onChanged: _changeScope,
              child: Column(
                children: [
                  RadioListTile<ReportScope>(
                    value: ReportScope.singleProject,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'export.current_project'.tr(),
                    ),
                  ),

                  RadioListTile<ReportScope>(
                    value: ReportScope.selectedProjects,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'export.selected_projects'.tr(),
                    ),
                  ),

                  RadioListTile<ReportScope>(
                    value: ReportScope.allProjects,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'export.all_projects'.tr(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Text(
              '${'export.selected_count'.tr()}: $selectedCount',
              style: Theme.of(context).textTheme.bodySmall,
            ),

            if (_scope == ReportScope.selectedProjects) ...[
              const SizedBox(height: 16),
              _buildProjectPicker(projects),
            ],

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _generate,
                icon: _isLoading
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.picture_as_pdf),
                label: Text(
                  'export.generate_preview'.tr(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectPicker(
      List<ProjectModel> projects,
      ) {
    if (projects.isEmpty) {
      return Text(
        'projects.no_projects'.tr(),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: () {
                _selectAllProjects(projects);
              },
              icon: const Icon(Icons.done_all),
              label: Text(
                'common.select_all'.tr(),
              ),
            ),

            const SizedBox(width: 8),

            TextButton.icon(
              onPressed: _clearSelectedProjects,
              icon: const Icon(Icons.clear),
              label: Text(
                'common.clear'.tr(),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 260,
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: projects.length,
            separatorBuilder: (_, __) {
              return const Divider(height: 1);
            },
            itemBuilder: (context, index) {
              final project = projects[index];
              final selected = _selectedProjectIds.contains(
                project.id,
              );

              return CheckboxListTile(
                value: selected,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  project.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${'projects.status'.tr()}: '
                      '${project.statusEnum.localizedText()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onChanged: (value) {
                  _toggleProjectSelection(
                    project,
                    value ?? false,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // =========================================================
  // EMPTY STATE
  // =========================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.picture_as_pdf_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.outline,
            ),

            const SizedBox(height: 16),

            Text(
              'report.no_preview'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),

            const SizedBox(height: 8),

            Text(
              'export.generate_preview_hint'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // PREVIEW
  // =========================================================

  Widget _buildPreview() {
    final pdf = _pdf;

    if (pdf == null) {
      return _buildEmptyState();
    }

    return PdfPreview(
      build: (_) async => pdf.save(),
      allowPrinting: true,
      allowSharing: true,
      canChangePageFormat: true,
      canChangeOrientation: true,
      canDebug: false,
      pdfFileName: 'taskio_report.pdf',
      loadingWidget: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final projects = context.watch<ProjectProvider>().projects;

    if (!_initializedSelection) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'export.title'.tr(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'common.refresh'.tr(),
            onPressed: _isLoading ? null : _generate,
          ),

          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'common.share'.tr(),
            onPressed: _pdf == null ? null : _sharePdf,
          ),

          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'common.print'.tr(),
            onPressed: _pdf == null ? null : _print,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildReportSettings(projects),

          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(),
            )
                : _buildPreview(),
          ),
        ],
      ),
    );
  }
}