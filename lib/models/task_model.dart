class TaskModel {
  final String id;
  final String projectId;
  final String title;
  final bool isCompleted;
  final DateTime createdAt;

  TaskModel({
    required this.id,
    required this.projectId,
    required this.title,
    required this.isCompleted,
    required this.createdAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      title: json['title'] as String,
      isCompleted: json['is_completed'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'project_id': projectId,
      'title': title,
      'is_completed': isCompleted,
    };
  }
}