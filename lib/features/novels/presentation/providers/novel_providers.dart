import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/novel.dart';
import '../../domain/repositories/novel_repository.dart';
import '../../../../core/di/injection.dart';

// Database provider
final novelRepositoryProvider = Provider<NovelRepository>((ref) {
  return getIt<NovelRepository>();
});

// Novel list stream provider
final novelListStreamProvider = StreamProvider<List<NovelEntity>>((ref) {
  final repo = ref.watch(novelRepositoryProvider);
  return repo.watchAllNovels();
});

// Single novel provider
final novelByIdProvider = FutureProvider.family<NovelEntity?, String>((ref, id) async {
  final repo = ref.watch(novelRepositoryProvider);
  return repo.getNovelById(id);
});

// Search query provider
final novelSearchQueryProvider = StateProvider<String>((ref) => '');

// Filtered novel list
final filteredNovelListProvider = Provider<AsyncValue<List<NovelEntity>>>((ref) {
  final novelsAsync = ref.watch(novelListStreamProvider);
  final query = ref.watch(novelSearchQueryProvider).toLowerCase();

  return novelsAsync.whenData((novels) {
    if (query.isEmpty) return novels;
    return novels.where((n) =>
      n.title.toLowerCase().contains(query) ||
      n.author.toLowerCase().contains(query)
    ).toList();
  });
});

// Novel actions notifier
class NovelActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final NovelRepository _repository;

  NovelActionsNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<String> createNovel(String title, {String author = ''}) async {
    state = const AsyncValue.loading();
    try {
      final id = await _repository.createNovel(NovelEntity(title: title, author: author));
      state = const AsyncValue.data(null);
      return id;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateNovel(NovelEntity novel) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateNovel(novel);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteNovel(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteNovel(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final novelActionsProvider = StateNotifierProvider<NovelActionsNotifier, AsyncValue<void>>((ref) {
  return NovelActionsNotifier(ref.watch(novelRepositoryProvider));
});
