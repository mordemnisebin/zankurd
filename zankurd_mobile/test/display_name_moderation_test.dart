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

  group('sunucunun kendi atadığı adlar', () {
    // Bu grup olmasaydı üretim kırılırdı: `ensureProfile()` HER yeni
    // kullanıcıya 'ZanKurd Oyuncusu' yazıyor ve bu ad markayı içerdiği
    // için korunan-ad kuralına takılıyordu. Tetikleyici canlıya
    // uygulansaydı hiçbir yeni kullanıcının profil INSERT'i geçmezdi.
    //
    // Depo aynı sınıftan bir kazayı zaten yaşadı (`assign_player_tag`,
    // applied.md 2026-08-01): ensureProfile istisnayı yutuyor, uygulama
    // normal görünüyor ama profil satırı hiç oluşmuyordu.
    test('varsayılan profil adı politikadan GEÇER', () {
      expect(
        DisplayNamePolicy.review('ZanKurd Oyuncusu'),
        DisplayNameVerdict.allowed,
        reason:
            'ensureProfile bu adı her yeni kullanıcıya atıyor; reddedilirse '
            'kayıt akışı tamamen kırılır',
      );
    });

    test('muafiyet TAM eşleşme — marka taklidi hâlâ reddedilir', () {
      for (final name in ['ZanKurd Destek', 'ZanKurd Resmi', 'ZanKurd']) {
        expect(
          DisplayNamePolicy.review(name),
          DisplayNameVerdict.reservedName,
          reason: 'muafiyet fazla geniş: "$name" geçiyor',
        );
      }
    });

    test('depodaki varsayılan ad ile politika listesi aynı', () {
      // İkisi ayrışırsa muafiyet sessizce işlevsiz kalır.
      final repo = File(
        'lib/src/data/supabase_zankurd_repository.dart',
      ).readAsStringSync();
      for (final name in DisplayNamePolicy.systemAssignedNames) {
        expect(
          repo,
          contains("'$name'"),
          reason:
              '"$name" politikada muaf ama depo artık onu atamıyor — '
              'muafiyet ölü, ya da depo başka bir ad atıyor',
        );
      }
    });

    test('sunucu tarafı da aynı muafiyeti taşıyor', () {
      final sql = File(
        'supabase/2026-08-02_display_name_moderation.sql',
      ).readAsStringSync();
      for (final name in DisplayNamePolicy.systemAssignedNames) {
        expect(
          sql,
          contains("'$name'"),
          reason:
              'istemci muaf tutuyor ama tetikleyici tutmuyor — yeni '
              'kullanıcı profili sunucuda reddedilir',
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

    // 2026-08-14 denetimi: üçüncü yazma yolu (kayıt formu) hiç
    // çağırmıyordu — engellenen sözcük/marka taklidi içeren bir ad
    // kapıdan hiç geçmeden doğrudan üretilen profile yazılabiliyordu.
    test('kayıt formu', () {
      final src = File(
        'lib/src/screens/sign_up_screen.dart',
      ).readAsStringSync();
      expect(
        src,
        contains('DisplayNamePolicy.review'),
        reason:
            'kayıt formu süzülmüyor — engellenen sözcük/marka taklidi içeren '
            'bir ad kapıdan hiç geçmeden sunucuya yazılabilir',
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

    test('bağlantı TLD listesi istemci ile sunucuda AYNI', () {
      // Canlıya uygularken yakalandı: Dart tarafında liste kısaltma alan
      // adlarıyla genişletilmişti (ly, gl, co…) ama SQL'e yansıtılmamıştı.
      // Sonuç, kapının yanlış tarafındaydı — istemci 'bit.ly/x' adını
      // reddederken SUNUCU kabul ediyordu, yani asıl koruma açıktı.
      final dart = File(
        'lib/src/services/display_name_policy.dart',
      ).readAsStringSync();
      final dartTlds = RegExp(
        r"\(com\|net\|org\|[a-z|]+\)",
      ).firstMatch(dart)?.group(0);
      expect(dartTlds, isNotNull, reason: 'Dart TLD listesi bulunamadı');

      final sqlTlds = RegExp(
        r"\(com\|net\|org\|[a-z|]+\)",
      ).firstMatch(sql)?.group(0);
      expect(sqlTlds, isNotNull, reason: 'SQL TLD listesi bulunamadı');

      expect(
        sqlTlds,
        dartTlds,
        reason:
            'istemci ve sunucu farklı TLD listesi kullanıyor; birinin '
            'reddettiğini diğeri kabul eder',
      );
    });

    test('normalize eşlemesi istemci ile sunucuda AYNI uzunlukta', () {
      // Postgres `translate`ta `from`un `to`dan uzun olan kısmı SESSİZCE
      // SİLİNİR. İlk yazımda uzunluklar tutmuyordu ve '@' -> 's' gibi
      // yanlış eşleşmeler oluşuyordu.
      final m = RegExp(
        r"translate\(\s*\n?\s*lower\(coalesce\(p_input, ''\)\),\s*\n\s*'([^']*)',\s*\n\s*'([^']*)'",
      ).firstMatch(sql);
      expect(m, isNotNull, reason: 'SQL translate çağrısı bulunamadı');
      expect(
        m!.group(1)!.length,
        m.group(2)!.length,
        reason:
            "translate from/to uzunlukları farklı — fazlalık sessizce "
            "siliniyor ve kaçamak yakalanmıyor",
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
