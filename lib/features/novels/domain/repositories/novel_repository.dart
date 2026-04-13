import '../entities/novel.dart';

abstract class NovelRepository {
  Future<List<NovelEntity>> getAllNovels();
  Stream<List<NovelEntity>> watchAllNovels();
  Future<NovelEntity?> getNovelById(String id);
  Future<String> createNovel(NovelEntity novel);
  Future<void> updateNovel(NovelEntity novel);
  Future<void> deleteNovel(String id);
}
