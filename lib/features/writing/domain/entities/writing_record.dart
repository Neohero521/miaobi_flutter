// WritingRecord Domain Entity
// Tracks AI writing operations for a chapter
class WritingRecordEntity {
  final String? id;
  final String chapterId;
  final String provider;   // e.g., 'minimax', 'openai'
  final int promptTokens;
  final int completionTokens;
  final String model;
  final DateTime? createdAt;

  WritingRecordEntity({
    this.id,
    required this.chapterId,
    this.provider = '',
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.model = '',
    this.createdAt,
  });

  WritingRecordEntity copyWith({
    String? id,
    String? chapterId,
    String? provider,
    int? promptTokens,
    int? completionTokens,
    String? model,
    DateTime? createdAt,
  }) {
    return WritingRecordEntity(
      id: id ?? this.id,
      chapterId: chapterId ?? this.chapterId,
      provider: provider ?? this.provider,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      model: model ?? this.model,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
