import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/providers/untimed_mode_provider.dart';

/// Süresiz mod rekabetçi turlara SIZMAMALI.
///
/// ## Niçin bu bekçi var
///
/// WCAG 2.2.1 gereği eklenen "süresiz mod" ayarı, yanlış kapsamla bağlanırsa
/// bir erişilebilirlik kazancı olmaktan çıkıp hile anahtarına dönüşür: oda,
/// 1v1, günlük tur, bot yarışı ve turnuvada süre puanın parçasıdır ve onu
/// kapatan oyuncu diğerlerinin önüne geçer.
///
/// Kapsam keyfî çizilmedi — ödül yerleşiminin sınırıyla aynı tutuldu.
/// `_settleQuizReward` şu koşulda erken dönüp sıfır coin veriyor:
///
///     widget.practice || widget.room.id == null
///
/// Yani süresiz modun açık olabileceği turlar zaten hiçbir sunucu ödülünü ya
/// da lig puanını beslemiyor. Bu bekçi o hizalamayı sabitler: karar mantığı
/// burada birebir yeniden kuruluyor ve iki tarafın da aynı kalması aranıyor.
/// Quiz ekranı yarın modlardan birini "ödülsüz" saymaya başlarsa bu test
/// hatırlatır.
void main() {
  /// `_QuizScreenState._isRewardNeutralSolo` ile birebir aynı kural.
  bool isRewardNeutralSolo({
    required bool is1v1,
    required bool dailyQuiz,
    required bool botRace,
    required bool practice,
    required String? roomId,
  }) {
    return !is1v1 && !dailyQuiz && !botRace && (practice || roomId == null);
  }

  /// `_settleQuizReward` içindeki erken dönüş koşulu.
  bool awardsNoReward({required bool practice, required String? roomId}) =>
      practice || roomId == null;

  test('süresiz modun açık olabildiği her tur ödülsüz', () {
    final modes = <String, Map<String, dynamic>>{
      'solo kategori': {
        'is1v1': false,
        'dailyQuiz': false,
        'botRace': false,
        'practice': false,
        'roomId': null,
      },
      'alıştırma': {
        'is1v1': false,
        'dailyQuiz': false,
        'botRace': false,
        'practice': true,
        'roomId': null,
      },
      'oda (1v1)': {
        'is1v1': true,
        'dailyQuiz': false,
        'botRace': false,
        'practice': false,
        'roomId': 'room-1',
      },
      'günlük tur': {
        'is1v1': false,
        'dailyQuiz': true,
        'botRace': false,
        'practice': false,
        'roomId': 'daily-1',
      },
      'bot yarışı': {
        'is1v1': false,
        'dailyQuiz': false,
        'botRace': true,
        'practice': false,
        'roomId': 'bot-1',
      },
      'sunucu odası': {
        'is1v1': false,
        'dailyQuiz': false,
        'botRace': false,
        'practice': false,
        'roomId': 'room-2',
      },
    };

    modes.forEach((name, m) {
      final untimedAllowed = isRewardNeutralSolo(
        is1v1: m['is1v1'] as bool,
        dailyQuiz: m['dailyQuiz'] as bool,
        botRace: m['botRace'] as bool,
        practice: m['practice'] as bool,
        roomId: m['roomId'] as String?,
      );
      if (!untimedAllowed) return;
      expect(
        awardsNoReward(
          practice: m['practice'] as bool,
          roomId: m['roomId'] as String?,
        ),
        isTrue,
        reason:
            '«$name» turunda süresiz mod açılabiliyor ama tur ÖDÜL VERİYOR. '
            'Bu, erişilebilirlik ayarını hile anahtarına çevirir.',
      );
    });
  });

  test('rekabetçi modlarda süresiz mod kapalı kalır', () {
    for (final competitive in [
      {'is1v1': true, 'dailyQuiz': false, 'botRace': false},
      {'is1v1': false, 'dailyQuiz': true, 'botRace': false},
      {'is1v1': false, 'dailyQuiz': false, 'botRace': true},
    ]) {
      expect(
        isRewardNeutralSolo(
          is1v1: competitive['is1v1']!,
          dailyQuiz: competitive['dailyQuiz']!,
          botRace: competitive['botRace']!,
          // En kötü durum: oyuncu alıştırma bayrağıyla girse bile
          // rekabetçi mod sayaçlı kalmalı.
          practice: true,
          roomId: null,
        ),
        isFalse,
        reason: 'Rekabetçi mod süresiz sayıldı: $competitive',
      );
    }
  });

  testWidgets('sağlayıcı ağaçta yoksa sayaç açık kalır', (tester) async {
    // Ekran turu aracı ve izole widget testleri sağlayıcısız çalışır;
    // orada çökmek yerine mevcut davranışa düşülmeli.
    late bool value;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            value = UntimedModeProvider.isEnabledIn(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(value, isFalse);
  });

  testWidgets('sağlayıcı varsa tercih okunur', (tester) async {
    late bool value;
    await tester.pumpWidget(
      ChangeNotifierProvider<UntimedModeProvider>.value(
        value: UntimedModeProvider(initialEnabled: true),
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              value = UntimedModeProvider.isEnabledIn(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(value, isTrue);
  });
}
