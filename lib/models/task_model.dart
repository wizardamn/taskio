class TaskModel {
  final String id;
  final String projectId;
  final String title;
  final bool isCompleted;
  final DateTime createdAt;

  const TaskModel({
    required this.id,
    required this.projectId,
    required this.title,
    required this.isCompleted,
    required this.createdAt,
  });

  // =========================================================
  // FROM JSON
  // =========================================================

  factory TaskModel.fromJson(
      Map<String, dynamic> json,
      ) {
    return TaskModel(
      id: json['id']?.toString() ?? '',
      projectId:
      json['project_id']?.toString() ?? '',
      title:
      json['title']?.toString().trim() ?? '',
      isCompleted:
      json['is_completed'] == true,
      createdAt: _safeDate(
        json['created_at'],
      ),
    );
  }

  // =========================================================
  // CREATE NEW
  // =========================================================

  factory TaskModel.create({
    required String projectId,
    required String title,
  }) {
    return TaskModel(
      id: '',
      projectId: projectId,
      title: title.trim(),
      isCompleted: false,
      createdAt: DateTime.now(),
    );
  }

  // =========================================================
  // TO JSON
  // =========================================================

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'project_id': projectId,
      'title': title,
      'is_completed': isCompleted,
    };
  }

  // =========================================================
  // COPY WITH
  // =========================================================

  TaskModel copyWith({
    String? id,
    String? projectId,
    String? title,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      projectId:
      projectId ?? this.projectId,
      title: title ?? this.title,
      isCompleted:
      isCompleted ?? this.isCompleted,
      createdAt:
      createdAt ?? this.createdAt,
    );
  }

  // =========================================================
  // TOGGLE
  // =========================================================

  TaskModel toggle() {
    return copyWith(
      isCompleted: !isCompleted,
    );
  }

  // =========================================================
  // SAFE DATE
  // =========================================================

  static DateTime _safeDate(
      dynamic value,
      ) {
    if (value == null) {
      return DateTime.now();
    }

    if (value is DateTime) {
      return value.toLocal();
    }

    return DateTime.tryParse(
      value.toString(),
    )?.toLocal() ??
        DateTime.now();
  }

  // =========================================================
  // EQUALITY
  // =========================================================

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TaskModel &&
            other.id == id &&
            other.projectId == projectId &&
            other.title == title &&
            other.isCompleted == isCompleted &&
            other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      projectId,
      title,
      isCompleted,
      createdAt,
    );
  }

  @override
  String toString() {
    return 'TaskModel('
        'id: $id, '
        'projectId: $projectId, '
        'title: $title, '
        'completed: $isCompleted'
        ')';
  }
}