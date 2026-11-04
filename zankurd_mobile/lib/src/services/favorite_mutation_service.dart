import '../data/sync_manager.dart';
import '../data/zankurd_repository.dart';
import '../models/quiz_question.dart';
import '../utils/error_reporter.dart';

/// Favori yazımının ortak dayanıklılık yolu.
///
/// Ekranlar yalnız kendi iyimser UI/mesaj davranışını yönetir. Repository
/// yazımı başarısız olursa istenen son durum SyncManager kuyruğunda tutulur
/// ve asıl hata tekrar fırlatılır; böylece çağıran başarı göstermemeye devam
/// eder.
class FavoriteMutationService {
  const FavoriteMutationService._();

  static Future<bool> setFavorite({
    required ZanKurdRepository repository,
    required QuizQuestion question,
    required bool favorite,
  }) async {
    try {
      final result = await repository.toggleFavoriteQuestion(
        question,
        favorite,
      );
      try {
        await SyncManager.maybeInstance?.supersedeQueuedFavorite(question.id);
      } catch (error, stack) {
        ErrorReporter.record(error, stack, reason: 'favorite queue supersede');
      }
      return result;
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'favorite mutation failed');
      final manager = SyncManager.maybeInstance;
      if (manager != null) {
        try {
          await manager.retainFavorite(
            questionId: question.id,
            favorite: favorite,
          );
        } catch (queueError, queueStack) {
          ErrorReporter.record(
            queueError,
            queueStack,
            reason: 'favorite queue',
          );
        }
      }
      rethrow;
    }
  }
}
