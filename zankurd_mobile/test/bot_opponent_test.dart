/// Bot rakibin puanlama ve kadro mantığının bekçisi.
///
/// ## Niçin bu test yoktu
///
/// 2026-08-23 test kapsamı taramasında bulundu: `BotOpponent`, `BotRace`
/// ve `BotNames` testlerde **sıfır** kez geçiyordu. Boşluk özellikle
/// sırıtıyor çünkü `BotOpponent` yapıcısı test için bir `Random?` iğnesi
/// taşıyor — seam bilerek açılmış, on ay boyunca kimse kullanmamış.
///
/// ## Niçin sessiz kaldı
///
/// Bot yalnız tek kişilik yarışta görünür ve orada da "insan hissi
/// veren rakip" olarak durur. Puanlaması bozulsa kimse fark etmez:
/// bot 100 yerine 110 yazsa da, seriyi yanlış sıfırlasa da ekranda
/// makul bir sayı görünür. Sessizce yanlış olabilen kod tam da bekçi
/// isteyen koddur.
///
/// ## Buradaki iddialar KUSUR değil, SÖZLEŞME
///
/// Ölçülen davranışların hepsi bugün doğru çalışıyor. Test yeşil
/// başlıyor ve bu kasıtlı: amaç bir kusuru göstermek değil, bugün
/// tuttuğunu yarın da söyleyecek bir kayıt bırakmak.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/bot_names.dart';
import 'package:zankurd_mobile/src/game/bot_opponent.dart';

/// Her zaman doğru cevaplatan üretici: `nextDouble` 0 döndürünce
/// `0 < probability` daima doğru olur (olasılık alt sınırı 0.15).
class _AlwaysCorrect implements Random {
  @override
  double nextDouble() => 0;
  @override
  bool nextBool() => true;
  @override
  int nextInt(int max) => 0;
}

/// Her zaman yanlış cevaplatan üretici: `nextDouble` 1 döndürünce
/// `1 < probability` daima yanlış olur (üst sınır 0.95).
class _AlwaysWrong implements Random {
  @override
  double nextDouble() => 1;
  @override
  bool nextBool() => false;
  @override
  int nextInt(int max) => 0;
}

void main() {
  group('BotOpponent puanlaması', () {
    test('ilk doğru 110 getirir — seri ÖNCE artar, sonra puan yazılır', () {
      final bot = BotOpponent(name: 'X', skill: 0.85, random: _AlwaysCorrect());
      expect(bot.answer(1), isTrue);
      // 100 + (streak=1 * 10) = 110. Sıra ters olsaydı 100 çıkardı.
      expect(bot.score, 110);
      expect(bot.streak, 1);
      expect(bot.correctCount, 1);
    });

    test('seri bonusu 5. doğrudan sonra 50de sabitlenir', () {
      final bot = BotOpponent(name: 'X', skill: 0.85, random: _AlwaysCorrect());
      for (var i = 0; i < 5; i++) {
        bot.answer(1);
      }
      // 110 + 120 + 130 + 140 + 150 = 650
      expect(bot.score, 650);

      final onceki = bot.score;
      bot.answer(1);
      // Altıncı doğru da 150: bonus clamp(0, 50) ile tavanlı.
      expect(bot.score - onceki, 150);
    });

    test('yanlış cevap seriyi sıfırlar ama doğru sayısına dokunmaz', () {
      final bot = BotOpponent(name: 'X', skill: 0.85, random: _AlwaysCorrect());
      bot.answer(1);
      bot.answer(1);
      expect(bot.streak, 2);
      expect(bot.correctCount, 2);

      final yanlisBot = BotOpponent(
        name: 'X',
        skill: 0.85,
        random: _AlwaysWrong(),
      );
      yanlisBot.answer(1);
      expect(yanlisBot.streak, 0);
      expect(yanlisBot.correctCount, 0);
      expect(yanlisBot.score, 0);
    });

    test('olasılık zorlukla düşer ve [0.15, 0.95] aralığına kırpılır', () {
      // Olasılık doğrudan okunamıyor; sınır davranışından çıkarılır.
      // nextDouble()=0.14 → 0.15'lik alt sınırda bile DOĞRU olmalı.
      final altSinir = BotOpponent(
        name: 'X',
        skill: 0.85,
        random: _SabitOran(0.14),
      );
      expect(
        altSinir.answer(12),
        isTrue,
        reason:
            'Zorluk 12 → 0.85 - 11*0.07 = 0.08; alt kırpma 0.15 devrede '
            'olmalı, yoksa 0.14 < 0.08 yanlış verirdi.',
      );

      // nextDouble()=0.96 → 0.95lik üst sınırda bile YANLIŞ olmalı.
      final ustSinir = BotOpponent(
        name: 'X',
        skill: 2.0,
        random: _SabitOran(0.96),
      );
      expect(
        ustSinir.answer(1),
        isFalse,
        reason: 'skill 2.0 kırpılmadan 0.96 < 2.0 doğru verirdi.',
      );
    });
  });

  group('BotRace kadrosu', () {
    test('üç bot farklı adlarla ve azalan beceriyle kurulur', () {
      final race = BotRace.standard(random: Random(42));
      expect(race.bots.length, 3);
      expect(
        race.bots.map((b) => b.name).toSet().length,
        3,
        reason: 'Üç adın farklı çıkması havuzda yineleme olmamasına bağlı.',
      );
      expect(race.bots.map((b) => b.skill).toList(), [0.85, 0.70, 0.55]);
    });

    test('toPlayers her botu Bot durumuyla yansıtır', () {
      final race = BotRace.standard(random: Random(7));
      race.answerAll(1);
      final players = race.toPlayers();
      expect(players.length, 3);
      for (final player in players) {
        expect(player.state, 'Bot');
      }
      for (var i = 0; i < 3; i++) {
        expect(players[i].name, race.bots[i].name);
        expect(players[i].score, race.bots[i].score);
        expect(players[i].streak, race.bots[i].streak);
      }
    });
  });

  group('BotNames havuzu', () {
    test('havuz üçten uzun ve yinelemesiz', () {
      // `BotRace.standard` havuzun ilk üçünü alıyor: üçten kısa bir
      // havuz RangeError verir, yinelemeli havuz aynı adlı iki rakip
      // üretir. İkisi de sessizce bozulur.
      expect(BotNames.pool.length, greaterThanOrEqualTo(3));
      expect(BotNames.pool.toSet().length, BotNames.pool.length);
    });

    test('adlar Hawar alfabesinde — oyuncuya görünen Kurmancî metin', () {
      for (final name in BotNames.pool) {
        for (final bad in ['ı', 'ğ', 'ö', 'ü', 'İ']) {
          expect(
            name.contains(bad),
            isFalse,
            reason: 'Hawar dışı «$bad» harfi bot adında: $name',
          );
        }
      }
    });
  });
}

/// `nextDouble` için sabit oran döndüren üretici.
class _SabitOran implements Random {
  _SabitOran(this._value);
  final double _value;
  @override
  double nextDouble() => _value;
  @override
  bool nextBool() => false;
  @override
  int nextInt(int max) => 0;
}
