import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

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
  void didUpdateWidget(covariant GradeSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.projectId != widget.projectId) {
      _grade = null;
      _selectedGrade = null;
      _commentController.clear();

      _loadGrade();
    }
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
    final projectId = widget.projectId.trim();

    if (projectId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      final grade = await _gradeService.getGrade(
        projectId,
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
      if (!mounted) {
        return;
      }

      SnackbarManager.showError(
        'grades.load_error'.tr(),
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
  // SAVE
  // =========================================================

  Future<void> _saveGrade() async {
    if (!widget.canEdit || _isSaving) {
      return;
    }

    final projectId = widget.projectId.trim();

    if (projectId.isEmpty) {
      SnackbarManager.showError(
        'errors.project_not_found'.tr(),
      );
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
        projectId: projectId,
        grade: grade,
        comment: _commentController.text.trim(),
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
      if (!mounted) {
        return;
      }

      SnackbarManager.showError(
        'grades.save_error'.tr(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // =========================================================
  // TEXT
  // =========================================================

  String _text({
    required String ru,
    required String en,
  }) {
    return context.locale.languageCode == 'ru' ? ru : en;
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return _buildLoading(
        theme,
        colorScheme,
      );
    }

    final hasGrade = _grade != null ||
        _selectedGrade != null ||
        _commentController.text.trim().isNotEmpty;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(
              theme,
              colorScheme,
            ),

            const SizedBox(height: 16),

            if (!widget.canEdit && !hasGrade)
              _buildEmptyReadonly(
                theme,
                colorScheme,
              )
            else ...[
              _buildGradeDropdown(
                colorScheme,
              ),

              const SizedBox(height: 12),

              _buildCommentField(
                colorScheme,
              ),

              const SizedBox(height: 12),

              _buildMeta(
                theme,
                colorScheme,
              ),

              if (!widget.canEdit) ...[
                const SizedBox(height: 12),
                _buildReadonlyHint(
                  theme,
                  colorScheme,
                ),
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

  // =========================================================
  // LOADING
  // =========================================================

  Widget _buildLoading(
      ThemeData theme,
      ColorScheme colorScheme,
      ) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'grades.loading'.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // HEADER
  // =========================================================

  Widget _buildHeader(
      ThemeData theme,
      ColorScheme colorScheme,
      ) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.grade_outlined,
            color: colorScheme.onPrimaryContainer,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'grades.title'.tr(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.canEdit
                    ? _text(
                  ru: 'Выставьте итоговую оценку проекта',
                  en: 'Set the final project grade',
                )
                    : _text(
                  ru: 'Оценка доступна только для просмотра',
                  en: 'The grade is read-only',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================
  // GRADE DROPDOWN
  // =========================================================

  Widget _buildGradeDropdown(
      ColorScheme colorScheme,
      ) {
    return DropdownButtonFormField<int>(
      initialValue: _selectedGrade,
      decoration: InputDecoration(
        labelText: 'grades.grade'.tr(),
        prefixIcon: const Icon(
          Icons.school_outlined,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant,
          ),
        ),
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

  // =========================================================
  // COMMENT FIELD
  // =========================================================

  Widget _buildCommentField(
      ColorScheme colorScheme,
      ) {
    return TextFormField(
      controller: _commentController,
      enabled: widget.canEdit,
      minLines: 2,
      maxLines: 4,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: 'grades.comment'.tr(),
        prefixIcon: const Icon(
          Icons.comment_outlined,
        ),
        alignLabelWithHint: true,
        filled: true,
        fillColor: widget.canEdit
            ? colorScheme.surface
            : colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // META
  // =========================================================

  Widget _buildMeta(
      ThemeData theme,
      ColorScheme colorScheme,
      ) {
    final grade = _grade;

    if (grade == null) {
      return const SizedBox.shrink();
    }

    final updatedAt = grade.updatedAt;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (grade.gradedBy.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${'grades.graded_by'.tr()}: ${grade.gradedBy}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              Icon(
                Icons.update_outlined,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${'grades.updated'.tr()}: ${DateFormat.yMd(context.locale.toString()).add_Hm().format(updatedAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================
  // READONLY
  // =========================================================

  Widget _buildReadonlyHint(
      ThemeData theme,
      ColorScheme colorScheme,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'grades.readonly'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyReadonly(
      ThemeData theme,
      ColorScheme colorScheme,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 28,
        horizontal: 12,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(
            Icons.grade_outlined,
            size: 42,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 8),
          Text(
            'grades.not_graded'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SAVE BUTTON
  // =========================================================

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
            : const Icon(
          Icons.save_outlined,
        ),
        label: Text(
          _isSaving
              ? 'common.saving'.tr()
              : 'grades.save'.tr(),
        ),
      ),
    );
  }
}