// Novel Domain Entity
class NovelEntity {
  final String? id;
  final String title;
  final String author;
  final String cover;
  final String introduction;
  final int totalWordCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  NovelEntity({
    this.id,
    required this.title,
    this.author = '',
    this.cover = '',
    this.introduction = '',
    this.totalWordCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  NovelEntity copyWith({
    String? id,
    String? title,
    String? author,
    String? cover,
    String? introduction,
    int? totalWordCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NovelEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      cover: cover ?? this.cover,
      introduction: introduction ?? this.introduction,
      totalWordCount: totalWordCount ?? this.totalWordCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
