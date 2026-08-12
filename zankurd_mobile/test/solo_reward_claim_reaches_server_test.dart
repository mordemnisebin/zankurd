import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/widget_test_helpers.dart';

/// Solo turun ödül talebinin SUNUCUYA gittiğinin bekçisi.
///
/// ## Kusur
///
/// `_claimCoins` içinde `if (widget.room.id == null) return 0;` duruyordu.
/// Solo tur tam olarak odasız turdur — `awardQuizCoins` soloyu zaten
/// `room?.id == null` ile tanır. Yani kapı, solo turu ödül yolundan
/// TAMAMEN çıkarıyordu: `_settleCoins` çağrılmıyor, `awardQuizCoins`
/// çağrılmıyor, `claim_solo_reward` RPC'si hiç istenmiyordu.
///
/// Kapı yazıldığı gün doğruydu: sunucu odasız turu ödüllendiremiyordu
/// (`claim_quiz_reward`, `p_room_id is null` görünce `verification_required`
/// döner), çağrı boşunaydı. 2026-08-10'da solo için ayrı bir RPC yazıldı ve
/// depo odasız çağrıyı ona yönlendirmeye başladı — ama bu kapı yerinde
/// kaldı. Sonuç: yeni RPC için göç yazıldı, tavan tasarlandı, ekonomi ona
/// göre fiyatlandı ve istemci onu HİÇ çağırmadı.
///
/// Sessiz kalmasının iki sebebi vardı. Kapının `_settleCoins` içinde bir
/// ikizi vardı; 2026-08-10'da o ikiz kaldırılınca sorun çözülmüş göründü.
/// Ve solo ödülü uçtan uca — ekrandan depoya — kuran hiçbir test yoktu:
/// mevcut ödül testleri `_settleCoins`i doğrudan çağırıyor, yani kapının
/// arkasından başlıyordu.
///
/// Bu bekçi ekrandan başlar. Turu bitirir ve deponun çağrıldığını,
/// odasız çağrıldığını doğrular.
void main() {
  const question = QuizQuestion(
    id: 'solo_reward_probe',
    category: 'Ziman',
    prompt: 'Hevwateya «renk» bi Kurmancî çi ye?',
    promptTr: '«Renk» sözcüğünün Kurmancî karşılığı nedir?',
    answers: ['dar', 'reng', 'kevir', 'av'],
    answersTr: ['dar', 'reng', 'kevir', 'av'],
    correctAnswer: 'reng',
    correctAnswerTr: 'reng',
    explanation: '«reng» = «renk».',
  );

  // Ders turu ilk açılışta iki adımlı bir koç işareti örtüsü gösterir ve o
  // örtü bütün dokunuşları yutar. Boş tercihlerle kurulan bir test, şıkka
  // dokunduğunu sanıp aslında örtüye dokunur; ilk taslak tam bu yüzden
  // "ödül istenmedi" diyordu. Tur öncesi bayrakları `freshMockRepository`
  // ile aynı biçimde kur.
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.profileName.completed.user': true,
      'zankurd.navTour.seen': true,
      'zankurd.quiz_tutorial.seen': true,
    });
  });

  Future<void> playSoloRound(WidgetTester tester, _SpyRepository repo) async {
    // Varsayılan test yüzeyi 800×600, yani YATAY; quiz orada başka bir
    // düzen dalına girer. Dikey telefon ölçüsü kur.
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repo,
          // Odasız oda: `createRoom()` id'siz döner ve solo tur budur.
          room: repo.createRoom(),
          questions: const [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(question.correctAnswer).first);
    await tester.pumpAndSettle();

    // Pasif bir düğmeye dokunmak sessizce hiçbir şey yapmaz ve test
    // "ödül istenmedi" der. Önce eylemin GERÇEKTEN etkin olduğunu
    // doğrula, sonra dokun.
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('quiz-next-button')),
    );
    expect(
      button.onPressed,
      isNotNull,
      reason: 'Cevap sonrası ana eylem etkin olmalı; değilse tur bitmiyor.',
    );

    // Cevap vermek turu bitirmez; son soruda ana eylem "Biqedîne" olur ve
    // ödül uzlaşması ona basıldığında koşar.
    await tester.tap(find.byKey(const ValueKey('quiz-next-button')));
    await tester.pumpAndSettle();
  }

  testWidgets('solo tur ödül talebini depoya iletiyor', (tester) async {
    final repo = _SpyRepository();
    expect(
      repo.createRoom().id,
      isNull,
      reason:
          'Bu bekçinin dayanağı, solo turun ODASIZ olmasıdır; oda id alırsa '
          'test artık soloyu ölçmüyor demektir.',
    );

    await playSoloRound(tester, repo);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(
      repo.awardCalls,
      greaterThan(0),
      reason:
          'Solo tur ödül talebini hiç göndermedi. `_claimCoins` içindeki '
          'odasız-tur kapısı geri konmuş olabilir — o kapı, solo ödül '
          'RPC\'sini ölü koda çevirir.',
    );
    expect(
      repo.lastRoomId,
      isNull,
      reason:
          'Talep odalı gitmiş. Depo soloyu `room?.id == null` ile tanır; '
          'oda id\'siyle giden bir solo tur, oda doğrulamasına düşer ve '
          'sunucu onu reddeder.',
    );
  });

  testWidgets('alıştırma turu ödül talebi göndermiyor', (tester) async {
    // Aynı kapının MEŞRU yarısı. Alıştırma, yanlış yapılan soruların
    // tekrarıdır; yeni bir tur değildir ve ödüllendirilirse aynı sorudan
    // sınırsız jeton üretilir.
    final repo = _SpyRepository();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repo,
          room: repo.createRoom(),
          questions: const [question],
          enableTimer: false,
          practice: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(question.correctAnswer).first);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Alıştırma turunun ana eylemi "Piştre" değil, kendini değerlendirme
    // düğmeleridir; `quiz-next-button` bu dalda hiç çizilmez. Turun nasıl
    // bittiği burada önemli değil — ödül yolunun HİÇ açılmaması önemli.
    expect(
      find.byKey(const ValueKey('quiz-next-button')),
      findsNothing,
      reason:
          'Alıştırma dalı ana eylemi kendi değerlendirme düğmeleriyle '
          'değiştirir; bu anahtar burada görünüyorsa akış değişmiş demektir.',
    );
    expect(
      repo.awardCalls,
      0,
      reason: 'Alıştırma turu jeton üretemez; kapının bu yarısı kalmalı.',
    );
  });
}

class _SpyRepository extends MockZanKurdRepository {
  int awardCalls = 0;
  String? lastRoomId;
  bool sawRoomArgument = false;

  @override
  String? get currentUserId => 'solo-user';

  @override
  Future<int> awardQuizCoins({
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
    GameRoom? room,
  }) async {
    awardCalls++;
    sawRoomArgument = room != null;
    lastRoomId = room?.id;
    return 0;
  }
}
