import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../services/grade_service.dart';
import '../../utils/snackbar_manager.dart';

class GradeSection extends StatefulWidget {
  final String projectId;
  final bool canEdit;

  const GradeSection({
    super.key,
    required this.projectId,
    required this.canEdit,
  });

  @override
  State<GradeSection> createState() => _GradeSectionState();
}

class _GradeSectionState extends State<GradeSection> {
  final GradeService _gradeService = GradeService();

  final TextEditingController _commentController =
  TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  ProjectGrade? _grade;
  int? _selectedGrade;

  @override
  void initState() {
    super.initState();
    _loadGrade();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // =========================================================
  // LOAD
  // =========================================================

  Future<void> _loadGrade() async {
    if (widget.projectId.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      return;
    }

    try {
      final grade = await _gradeService.getGrade(
        widget.projectId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _grade = grade;
        _selectedGrade = grade?.grade;

        _commentController.text = grade?.comment ?? '';
      });
    } catch (_) {
      if (mounted) {
        SnackbarManager.showError(
          'grades.load_error'.tr(),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // =========================================================
  // SAVE
  // =========================================================

  Future<void> _saveGrade() async {
    if (!widget.canEdit || _isSaving) {
      return;
    }

    final grade = _selectedGrade;

    if (grade == null) {
      SnackbarManager.showWarning(
        'grades.select_grade'.tr(),
      );
      return;
    }

    try {
      setState(() {
        _isSaving = true;
      });

      final savedGrade = await _gradeService.saveGrade(
        projectId: widget.projectId,
        grade: grade,
        comment: _commentController.text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _grade = savedGrade;
        _selectedGrade = savedGrade.grade;
        _commentController.text = savedGrade.comment ?? '';
      });

      SnackbarManager.showSuccess(
        'grades.saved'.tr(),
      );
    } catch (_) {
      if (mounted) {
        SnackbarManager.showError(
          'grades.save_error'.tr(),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'grades.loading'.tr(),
              ),
            ],
          ),
        ),
      );
    }

    final hasGrade = _grade != null ||
        _selectedGrade != null ||
        _commentController.text.trim().isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme),

            const SizedBox(height: 16),

            if (!widget.canEdit && !hasGrade)
              _buildEmptyReadonly(theme)
            else ...[
              _buildGradeDropdown(),

              const SizedBox(height: 12),

              _buildCommentField(),

              const SizedBox(height: 12),

              _buildMeta(theme),

              if (!widget.canEdit) ...[
                const SizedBox(height: 12),
                _buildReadonlyHint(theme),
              ],

              if (widget.canEdit) ...[
                const SizedBox(height: 16),
                _buildSaveButton(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Icon(
          Icons.grade,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'grades.title'.tr(),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGradeDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _selectedGrade,
      decoration: InputDecoration(
        labelText: 'grades.grade'.tr(),
        border: const OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(
          value: 5,
          child: Text('5'),
        ),
        DropdownMenuItem(
          value: 4,
          child: Text('4'),
        ),
        DropdownMenuItem(
          value: 3,
          child: Text('3'),
        ),
        DropdownMenuItem(
          value: 2,
          child: Text('2'),
        ),
      ],
      onChanged: widget.canEdit
          ? (value) {
        setState(() {
          _selectedGrade = value;
        });
      }
          : null,
    );
  }

  Widget _buildCommentField() {
    return TextFormField(
      controller: _commentController,
      enabled: widget.canEdit,
      minLines: 2,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: 'grades.comment'.tr(),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildMeta(ThemeData theme) {
    final grade = _grade;

    if (grade == null) {
      return const SizedBox.shrink();
    }

    final updatedAt = grade.updatedAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (grade.gradedBy.isNotEmpty)
          Text(
            '${'grades.graded_by'.tr()}: ${grade.gradedBy}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

        const SizedBox(height: 4),

        Text(
          '${'grades.updated'.tr()}: ${DateFormat.yMd(context.locale.toString()).add_Hm().format(updatedAt)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildReadonlyHint(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'grades.readonly'.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyReadonly(ThemeData theme) {
    return Text(
      'grades.not_graded'.tr(),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isSaving ? null : _saveGrade,
        icon: _isSaving
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        )
            : const Icon(Icons.save),
        label: Text(
          'grades.save'.tr(),
        ),
      ),
    );
  }
}