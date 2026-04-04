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

  // ------------------------------------------------
  // FROM JSON (Safe)
  // ------------------------------------------------

  factory TaskModel.fromJson(
      Map<String, dynamic> json) {
    return TaskModel(
      id: json['id']?.toString() ?? '',
      projectId:
      json['project_id']?.toString() ??
          '',
      title: json['title'] ?? '',
      isCompleted:
      json['is_completed'] ?? false,
      createdAt:
      _safeDate(json['created_at']),
    );
  }

  // ------------------------------------------------
  // TO JSON
  // ------------------------------------------------

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'project_id': projectId,
      'title': title,
      'is_completed': isCompleted,
      'created_at':
      createdAt.toUtc()
          .toIso8601String(),
    };
  }

  // ------------------------------------------------
  // COPY WITH
  // ------------------------------------------------

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

  // ------------------------------------------------
  // TOGGLE COMPLETION
  // ------------------------------------------------

  TaskModel toggle() {
    return copyWith(
      isCompleted: !isCompleted,
    );
  }

  // ------------------------------------------------
  // SAFE DATE PARSER
  // ------------------------------------------------

  static DateTime _safeDate(
      dynamic value) {
    if (value == null) {
      return DateTime.now();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(
        value.toString()) ??
        DateTime.now();
  }

  @override
  String toString() {
    return 'TaskModel(id: $id, title: $title, completed: $isCompleted)';
  }
}