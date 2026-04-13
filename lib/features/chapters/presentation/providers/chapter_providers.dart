import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/repositories/chapter_repository.dart';
import '../../../../core/di/injection.dart';

final chapterRepositoryProvider = Provider<ChapterRepository>((ref) {
  return getIt<ChapterRepository>();
});

// Chapter list by novel stream
final chapterListStreamProvider = StreamProvider.family<List<ChapterEntity>, String>((ref, novelId) {
  final repo = ref.watch(chapterRepositoryProvider);
  return repo.watchChaptersByNovelId(novelId);
});

// Single chapter provider
final chapterByIdProvider = FutureProvider.family<ChapterEntity?, String>((ref, id) async {
  final repo = ref.watch(chapterRepositoryProvider);
  return repo.getChapterById(id);
});

// Chapter actions notifier
class ChapterActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final ChapterRepository _repository;

  ChapterActionsNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<String> createChapter(String novelId, int number, String title, {String content = ''}) async {
    state = const AsyncValue.loading();
    try {
      final id = await _repository.createChapter(ChapterEntity(
        novelId: novelId,
        number: number,
        title: title,
        content: content,
        wordCount: _countWords(content),
      ));
      state = const AsyncValue.data(null);
      return id;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateChapter(ChapterEntity chapter) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateChapter(chapter.copyWith(
        wordCount: _countWords(chapter.content),
        updatedAt: DateTime.now(),
      ));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteChapter(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteChapter(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  int _countWords(String text) {
    if (text.isEmpty) return 0;
    final chinese = text.replaceAll(RegExp(r'[a-zA-Z0-9]'), '').length;
    final english = text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return chinese + english;
  }
}

final chapterActionsProvider = StateNotifierProvider<ChapterActionsNotifier, AsyncValue<void>>((ref) {
  return ChapterActionsNotifier(ref.watch(chapterRepositoryProvider));
});
