import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/services/chat_moderation_policy.dart';
import 'package:zankurd_mobile/src/services/display_name_policy.dart';

/// Görünen adlar hiçbir filtreden geçmiyordu (2026-08-02, A-06 -> P1-009).
///
/// İstemcide tek kontrol uzunluktu; `ChatModerationPolicy` depo genelinde
/// yalnız `room_chat.dart`ta çağrılıyordu ve adlara hiç uygulanmıyordu.
/// Sunucuda ise `profiles.display_name` için CHECK kısıtı, tetikleyici ya da
/// doğrulayan RPC yoktu. Ad; liderlikte, odada, eşleştirmede ve sohbette
/// yabancılara gösterilen, mesajdan daha kalıcı bir UGC yüzeyidir.
///
/// Bu bekçi üç şeyi birden tutar:
///   1. Politikanın kendisi doğru karar veriyor,
///   2. HER İKİ istemci yazma yolu da politikayı çağırıyor,
///   3. Sunucu tarafı kapı var — istemci filtresi tek başına atlatılabilir.
void main() {
  group('politika kararları', () {
    test('sıradan Kurmancî/Türkçe adlar kabul edilir', () {
      for (final name in ['Zelal', 'Rojda', 'Ahmet', 'Şêrîn', 'Ayşe Nur']) {
        expect(
          DisplayNamePolicy.review(name),
          DisplayNameVerdict.allowed,
          reason: '"$name" masum bir ad; reddedilmemeli',
        );
      }
    });

    test('uzunluk sınırları korunuyor', () {
      expect(DisplayNamePolicy.review('a'), DisplayNameVerdict.tooShort);
      expect(DisplayNamePolicy.review('   '), DisplayNameVerdict.empty);
      expect(DisplayNamePolicy.review('x' * 25), DisplayNameVerdict.tooLong);
    });

    test('emoji tek görünen karakter sayılır', () {
      // `String.length` UTF-16 kod birimi sayar; tek bir emoji 2 döner ve
      // kısa ama geçerli bir ad haksız yere reddedilirdi.
      expect(DisplayNamePolicy.review('Ro😀'), DisplayNameVerdict.allowed);
    });

    test('engellenen sözcük içeren ad reddedilir', () {
      expect(
        DisplayNamePolicy.review('siktir'),
        DisplayNameVerdict.blockedWord,
      );
      // Rakam-harf kaçamağı da yakalanmalı.
      expect(
        DisplayNamePolicy.review('s1kt1r'),
        DisplayNameVerdict.blockedWord,
      );
    });

    test('kelime listesi sohbetle ORTAK — ikisi ayrışamaz', () {
      // Ayrı listeler tutulsaydı zamanla birbirinden uzaklaşır ve sohbette
      // engellenen bir sözcük adda serbest kalırdı.
      for (final word in ChatModerationPolicy.blockedWords) {
        expect(
          DisplayNamePolicy.review(word),
          isNot(DisplayNameVerdict.allowed),
          reason: 'sohbette engellenen "$word" adda serbest',
        );
      }
    });

    test('yetkili/destek taklidi reddedilir', () {
      for (final name in [
        'ZanKurd',
        'ZanKurd Destek',
        'admin',
        'Resmi Hesap',
        'system',
      ]) {
        expect(
          DisplayNamePolicy.review(name),
          DisplayNameVerdict.reservedName,
          reason: '"$name" kimlik taklidine açık',
        );
      }
    });

    test('görünmez ve yön değiştiren karakterler reddedilir', () {
      // U+202E ile yazılan ad liderlik tablosunda hizalamayı kırar ve
      // tersten okunarak taklide yarar.
      expect(
        DisplayNamePolicy.review('Ze\u202Elal'),
        DisplayNameVerdict.invalidCharacters,
      );
      expect(
        DisplayNamePolicy.review('Ze\u200Blal'),
        DisplayNameVerdict.invalidCharacters,
      );
    });

    test('bağlantı içeren ad reddedilir', () {
      expect(
        DisplayNamePolicy.review('bit.ly/xyz'),
        DisplayNameVerdict.containsLink,
      );
      expect(
        DisplayNamePolicy.review('www.spam.com'),
        DisplayNameVerdict.containsLink,
      );
    });

    test('her kararın bir kullanıcı metni var', () {
      for (final verdict in DisplayNameVerdict.values) {
        if (verdict == DisplayNameVerdict.allowed) continue;
        expect(
          DisplayNamePolicy.messageKeyFor(verdict),
          isNotEmpty,
          reason: '$verdict için anahtar yok; kullanıcı sebebi göremez',
        );
      }
    });
  });

  group('yazma yolları politikayı çağırıyor', () {
    test('isim kapısı', () {
      final src = File(
        'lib/src/screens/profile_name_gate_screen.dart',
      ).readAsStringSync();
      expect(
        src,
        contains('DisplayNamePolicy.review'),
        reason: 'isim kapısı yalnız uzunluğa bakıyor',
      );
    });

    test('ayarlar ekranı', () {
      final src = File(
        'lib/src/screens/settings_screen.dart',
      ).readAsStringSync();
      expect(
        src,
        contains('DisplayNamePolicy.review'),
        reason:
            'ayarlar yolu süzülmüyor — kullanıcı kapıda temiz ad verip '
            'sonra buradan değiştirebilir',
      );
    });
  });

  group('sunucu tarafı kapı', () {
    late String sql;

    setUpAll(() {
      sql = File(
        'supabase/2026-08-02_display_name_moderation.sql',
      ).readAsStringSync();
    });

    test('profiles üzerinde tetikleyici kuruluyor', () {
      expect(sql, contains('create trigger trg_enforce_display_name_policy'));
      expect(sql, contains('on public.profiles'));
      expect(
        sql,
        contains('before insert or update of display_name'),
        reason:
            'tetikleyici INSERT veya UPDATE yollarından birini kaçırırsa '
            'kapı açık kalır',
      );
    });

    test('sunucu listesi istemci listesiyle örtüşüyor', () {
      // Birebir dize eşitliği aranmaz (SQL tarafı sadeleştirilmiş yazılır);
      // amaç listelerin sessizce ayrışmamasıdır.
      final missing = <String>[];
      for (final word in DisplayNamePolicy.reservedWords) {
        if (!sql.contains("'$word'")) missing.add(word);
      }
      expect(
        missing,
        isEmpty,
        reason: 'sunucuda karşılığı olmayan korunan adlar: $missing',
      );
    });

    test('ada dokunmayan güncellemeler denetimden muaf', () {
      // Aksi hâlde eski bir kayıt yüzünden avatar rengi bile kaydedilemezdi.
      expect(
        sql,
        contains('is not distinct from old.display_name'),
        reason:
            'her profil güncellemesi ad denetimine giriyor; ada dokunmayan '
            'yazımlar eski kayıtlar yüzünden reddedilir',
      );
    });
  });
}
