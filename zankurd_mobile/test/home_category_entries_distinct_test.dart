/// Kategorilere açılan iki kartın AYNI ŞEYE BENZEMEDİĞİNİN bekçisi.
///
/// ## Kusur
///
/// Ana sayfada iki kart aynı işlevi (`_openCategories`) çağırıyordu ve
/// alt yazıları neredeyse aynıydı:
///
///     Konu seç          — Bir kategori seç ve başla
///     Tüm kategoriler   — Bir konu seç ve başla
///
/// Ekranda yaklaşık 500 px arayla duruyorlardı ve ikincisi yalnız
/// İLERLEME YOKKEN çiziliyordu, yani yeni kullanıcıda — kafa
/// karışıklığının en pahalı olduğu anda (2026-08-24, simülatörde
/// görüldü).
///
/// ## Niçin kart kaldırılmadı
///
/// Her iki tarafı kaldırma denendi ve üçü de belgelenmiş bir kararı
/// deviriyordu: keşif davetinin ilerleme yokken görünmesi (2026-08-14),
/// üç seçenek kartının `secondary` görsel hiyerarşisi, ve öğrenme ile
/// yarış geçişlerinin farklı hedeflere gitmesi. Ürün sahibinin kararı
/// kartları korumak, METİNLERİ ayırmak oldu.
///
/// Zaten kullanıcının yaşadığı sorun "iki giriş" değildi; "aynı şeye
/// benzeyen iki giriş"ti. İki kartın niyeti gerçekten farklı: biri tek
/// konuda çalışmak, öbürü henüz başlamamış oyuncuya bütünü göstermek.
///
/// ## Niçin sessiz kaldı
///
/// İki kart ayrı dosyalarda tanımlı (`home_screen.dart` ve
/// `home_rows.dart`) ve ikisi de kendi başına doğruydu. Kusur yalnız
/// aynı ekranda yan yana gelince ortaya çıkıyor; hiçbir birim testi iki
/// dosyayı birlikte görmüyordu. Ekran turu da yakalayamaz: görüntü iki
/// kart gösterir, metinlerinin birbirine benzediğini söylemez.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';

void main() {
  test('iki kartın alt yazıları birbirinden ayırt edilebilir', () {
    for (final isKu in [false, true]) {
      final topic = Tr.forKu(K.homeTopicPickerSub, isKu);
      final browse = Tr.forKu(K.homeBrowseAllSub, isKu);

      expect(topic.trim(), isNotEmpty, reason: 'ku=$isKu');
      expect(browse.trim(), isNotEmpty, reason: 'ku=$isKu');
      expect(
        topic,
        isNot(equals(browse)),
        reason: 'İki alt yazı birebir aynı olmuş (ku=$isKu).',
      );

      // Birebir eşitlik yetmez: eski hâlde de metinler farklıydı
      // ("Bir kategori seç ve başla" / "Bir konu seç ve başla") ama
      // kullanıcı için aynı şeyi söylüyorlardı. Ortak kelime oranı
      // ölçülür.
      final a = topic.toLowerCase().split(RegExp(r'\s+')).toSet();
      final b = browse.toLowerCase().split(RegExp(r'\s+')).toSet();
      final ortak = a.intersection(b).length;
      final oran = ortak / (a.length < b.length ? a.length : b.length);
      expect(
        oran,
        lessThan(0.5),
        reason:
            'Alt yazıların yarısından çoğu ortak kelime (ku=$isKu): '
            '"$topic" ↔ "$browse". Kullanıcı ikisini aynı şey sanır.',
      );
    }
  });

  test('Kurmancî alt yazılar Hawar alfabesinde', () {
    for (final key in [K.homeTopicPickerSub, K.homeBrowseAllSub]) {
      final text = Tr.forKu(key, true);
      for (final bad in ['ı', 'ğ', 'ö', 'ü', 'İ']) {
        expect(
          text.contains(bad),
          isFalse,
          reason: 'Hawar dışı «$bad» harfi: $key -> "$text"',
        );
      }
    }
  });
}
