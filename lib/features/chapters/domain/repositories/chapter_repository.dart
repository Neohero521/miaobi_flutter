import '../entities/chapter.dart';

abstract class ChapterRepository {
  Future<List<ChapterEntity>> getChaptersByNovelId(String novelId);
  Stream<List<ChapterEntity>> watchChaptersByNovelId(String novelId);
  Future<ChapterEntity?> getChapterById(String id);
  Future<String> createChapter(ChapterEntity chapter);
  Future<void> updateChapter(ChapterEntity chapter);
  Future<void> deleteChapter(String id);
}
