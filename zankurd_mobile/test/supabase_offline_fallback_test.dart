import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';

/// Her isteği anında ağ hatasıyla reddeden sahte HTTP client. Gerçek bir
/// soket açmaz — bu yüzden gerçek-ağ testlerinin aksine (bkz. ilk deneme:
/// 127.0.0.1:1'e bağlanmak GoTrue'nun retry/backoff'u yüzünden 45sn'den
/// uzun sürdü) deterministik ve anında başarısız olur.
class _AlwaysFailingHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw Exception('injected: ağ erişilemez');
  }
}

/// 2026-07-21 denetiminde bulunan test boşluğu: repository'nin Supabase
/// erişilemez olduğunda gerçekten güvenli davrandığını (ne çökme ne de
/// sahte skor/coin/oda üretimi) hiçbir test doğrulamıyordu.
void main() {
  SupabaseZanKurdRepository unreachableRepo() => SupabaseZanKurdRepository(
    SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test_key',
      httpClient: _AlwaysFailingHttpClient(),
    ),
  );

  test('loadQuestions ağ hatasında throw etmez, offline bankaya düşer', () async {
    final repo = unreachableRepo();
    final questions = await repo.loadQuestions(limit: 5);
    expect(questions, isNotEmpty);
  });

  test('loadCoinBalance ağ hatasında throw etmez, 0 döner', () async {
    final repo = unreachableRepo();
    expect(await repo.loadCoinBalance(), 0);
  });

  test('spendCoins ağ hatasında false döner — coin sahte harcanmış sayılmaz', () async {
    final repo = unreachableRepo();
    expect(await repo.spendCoins(20, 'wildcard_fifty_fifty'), isFalse);
  });

  test(
    'awardQuizCoins ağ hatasında 0 döner — sunucu onaylamadan ödül verilmez',
    () async {
      final repo = unreachableRepo();
      final amount = await repo.awardQuizCoins(
        score: 500,
        correctCount: 8,
        bestStreak: 5,
        totalQuestions: 10,
      );
      expect(amount, 0);
    },
  );

  test(
    'createOnlineRoom ağ hatasında throw eder — sessizce sahte oda üretmez',
    () async {
      final repo = unreachableRepo();
      await expectLater(repo.createOnlineRoom(), throwsA(anything));
    },
  );
}
