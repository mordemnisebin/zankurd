import 'package:flutter/foundation.dart';

@immutable
class Lesson {
  final String id;
  final String slug;
  final String titleKu;
  final String? titleTr;
  final String? descriptionKu;
  final String category;
  final String? iconName;
  final int order;

  const Lesson({
    required this.id,
    required this.slug,
    required this.titleKu,
    this.titleTr,
    this.descriptionKu,
    required this.category,
    this.iconName,
    this.order = 0,
  });

  Lesson copyWith({
    String? id,
    String? slug,
    String? titleKu,
    String? titleTr,
    String? descriptionKu,
    String? category,
    String? iconName,
    int? order,
  }) => Lesson(
    id: id ?? this.id,
    slug: slug ?? this.slug,
    titleKu: titleKu ?? this.titleKu,
    titleTr: titleTr ?? this.titleTr,
    descriptionKu: descriptionKu ?? this.descriptionKu,
    category: category ?? this.category,
    iconName: iconName ?? this.iconName,
    order: order ?? this.order,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'title_ku': titleKu,
    'title_tr': titleTr,
    'description_ku': descriptionKu,
    'category': category,
    'icon_name': iconName,
    'order': order,
  };

  static Lesson fromJson(Map<String, dynamic> json) => Lesson(
    id: json['id'] as String,
    slug: json['slug'] as String,
    titleKu: json['title_ku'] as String,
    titleTr: json['title_tr'] as String?,
    descriptionKu: json['description_ku'] as String?,
    category: json['category'] as String? ?? '',
    iconName: json['icon_name'] as String?,
    order: json['order'] as int? ?? 0,
  );

  @override
  String toString() => 'Lesson(slug: $slug, title: $titleKu)';
}

@immutable
class LessonSlide {
  final String id;
  final String lessonId;
  final int order;
  final String contentKu;
  final String? contentTr;
  final String? exampleKu;
  final String? imageUrl;
  final String? audioUrl;

  const LessonSlide({
    required this.id,
    required this.lessonId,
    required this.order,
    required this.contentKu,
    this.contentTr,
    this.exampleKu,
    this.imageUrl,
    this.audioUrl,
  });

  LessonSlide copyWith({
    String? id,
    String? lessonId,
    int? order,
    String? contentKu,
    String? contentTr,
    String? exampleKu,
    String? imageUrl,
    String? audioUrl,
  }) => LessonSlide(
    id: id ?? this.id,
    lessonId: lessonId ?? this.lessonId,
    order: order ?? this.order,
    contentKu: contentKu ?? this.contentKu,
    contentTr: contentTr ?? this.contentTr,
    exampleKu: exampleKu ?? this.exampleKu,
    imageUrl: imageUrl ?? this.imageUrl,
    audioUrl: audioUrl ?? this.audioUrl,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'lesson_id': lessonId,
    'order_in_lesson': order,
    'content_ku': contentKu,
    'content_tr': contentTr,
    'example_ku': exampleKu,
    'image_url': imageUrl,
    'audio_url': audioUrl,
  };

  static LessonSlide fromJson(Map<String, dynamic> json) => LessonSlide(
    id: json['id'] as String,
    lessonId: json['lesson_id'] as String,
    order: json['order_in_lesson'] as int,
    contentKu: json['content_ku'] as String,
    contentTr: json['content_tr'] as String?,
    exampleKu: json['example_ku'] as String?,
    imageUrl: json['image_url'] as String?,
    audioUrl: json['audio_url'] as String?,
  );

  @override
  String toString() => 'LessonSlide(lesson: $lessonId, order: $order)';
}

@immutable
class UserLessonProgress {
  final String userId;
  final String lessonId;
  final bool completed;
  final DateTime? completedAt;

  const UserLessonProgress({
    required this.userId,
    required this.lessonId,
    this.completed = false,
    this.completedAt,
  });

  UserLessonProgress copyWith({
    String? userId,
    String? lessonId,
    bool? completed,
    DateTime? completedAt,
  }) => UserLessonProgress(
    userId: userId ?? this.userId,
    lessonId: lessonId ?? this.lessonId,
    completed: completed ?? this.completed,
    completedAt: completedAt ?? this.completedAt,
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'lesson_id': lessonId,
    'completed': completed,
    'completed_at': completedAt?.toIso8601String(),
  };

  static UserLessonProgress fromJson(Map<String, dynamic> json) =>
      UserLessonProgress(
        userId: json['user_id'] as String,
        lessonId: json['lesson_id'] as String,
        completed: json['completed'] as bool? ?? false,
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'] as String)
            : null,
      );

  @override
  String toString() =>
      'UserLessonProgress(lesson: $lessonId, completed: $completed)';
}
