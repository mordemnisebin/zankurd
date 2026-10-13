import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Soru bankasındaki Kurmancî TAŞIYICI cümle Kurmancî kalmalı.
///
/// ## Niçin var
///
/// `kurmanci_alphabet_test` Kurmancî metinlerde Türkçe harf (ı, ğ, ö, ü, İ)
/// aramanın doğru yolunu kurdu ve kendi belgesinde şunu yazıyor: "Bir
/// bekçinin kapsamı kusurun yaşadığı yeri içermiyorsa o bekçi değildir."
/// Ama o taramanın kapsamı `lib/` altındaki arayüz metinleriydi. Kurmancî
/// metnin ezici çoğunluğu `lib/`de değil, **soru bankasında** yaşıyor:
/// 2128 soru, her birinin Kurmancî promptu (2026-08-17 sayımı).
///
/// ## Kural niçin bu kadar dar
///
/// Aynı harf kuralını bankaya olduğu gibi uygulamak yanlış olurdu. Ölçüldü:
/// bütün Kurmancî alanlara uygulandığında **1562** eşleşme çıkıyor ve
/// neredeyse hepsi doğru içerik —
///
/// * `answers` bilerek Türkçe taşır: "roj" sorusunun şıkları
///   "gün/güneş", "yüz", "sözcük"tür; sorunun amacı zaten Türkçe karşılığı
///   sormaktır.
/// * `explanation` birçok soruda Türkçe yazılmıştır (Kurmancî karşılığı ayrı
///   alanda durur ve onu `explanation_ku_test` denetler).
/// * Özel adlar her dilde kendi yazımını korur: "Şerîf Gören",
///   "Victor Sjöström", "Diyarbakır".
///
/// Yani mekanik bir tarama burada 1562 sahte alarm üretir ve sahte alarm
/// üreten bekçi kapatılır. Bu yüzden kural tek bir yere daraltıldı:
/// **promptun tırnak ve parantez dışında kalan kısmı** — sorunun kendi
/// cümlesi. Alıntılanan malzeme (çevrilecek Türkçe cümle, bir terimin
/// karşılığı) her dilde olabilir; ama soruyu soran cümle Kurmancîdir.
///
/// Bu daraltmayla banka **temiz** çıktı: 2128 promptun yalnız biri eşleşti
/// ve o da bir müzik grubunun gerçek adıydı. Bekçi o tek istisnayı gizlemez,
/// adıyla listeler — istisnayı görünür kılmak kuralı zayıflatmaktan iyidir.
void main() {
  /// Türkçeye özgü harfler. Kurmancî alfabesinde ı, ğ, ö, ü yoktur; İ de
  /// yoktur (i'nin büyüğü noktasız I'dır).
  final turkishOnly = RegExp(r'[ığöüİ]');

  /// Alıntı ve parantez içi: taşıyıcı cümlenin dışıdır.
  final quoted = RegExp(r'"[^"]*"|“[^”]*”|«[^»]*»|\([^)]*\)');

  /// Tek istisna ve sebebi.
  ///
  /// "Kardeş Türküler" var olan bir müzik topluluğunun adıdır; adı Kurmancî
  /// yazıma çevirmek onu yanlış yazmak olurdu. Özel ad olduğu için tırnak
  /// içinde de değil, cümlenin doğal parçası.
  const allowedProperNouns = <String>{'Kardeş Türküler'};

  test('Kurmancî prompt cümlesi Türkçe harf taşımaz', () {
    final offenders = <String>[];
    var scanned = 0;

    for (final file in Directory('assets/data').listSync().whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      final decoded = jsonDecode(file.readAsStringSync());
      final items = decoded is List
          ? decoded
          : (decoded is Map ? decoded['questions'] : null);
      if (items is! List) continue;

      for (final item in items) {
        if (item is! Map) continue;
        final prompt = item['prompt'];
        if (prompt is! String || prompt.isEmpty) continue;
        scanned++;

        var carrier = prompt.replaceAll(quoted, ' ');
        for (final allowed in allowedProperNouns) {
          carrier = carrier.replaceAll(allowed, ' ');
        }
        final hits = turkishOnly.allMatches(carrier).map((m) => m[0]!).toSet();
        if (hits.isEmpty) continue;

        offenders.add(
          '${file.uri.pathSegments.last} · ${item['id']} · '
          '[${hits.join()}] $prompt',
        );
      }
    }

    // Banka yüklenmediyse ya da alan adı değiştiyse bekçi boş kümede
    // kendiliğinden geçerdi; ölçülen taban 2128'di.
    expect(
      scanned,
      greaterThanOrEqualTo(2000),
      reason:
          'Yalnız $scanned prompt tarandı; banka okunamamış olabilir ve '
          'tarama boşa geçiyor.',
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'Bu soruların Kurmancî cümlesinde Türkçe harf var. Alıntı içindeki '
          'Türkçe zaten muaf; buradakiler sorunun KENDİ cümlesinde:\n'
          '${offenders.join('\n')}',
    );
  });

  test('istisna listesi kuralı boşaltacak kadar genişlemez', () {
    // İstisna listesi bir kaçış kapısıdır: büyüdükçe kural anlamını
    // yitirir. Yeni bir özel ad eklemek gerekiyorsa bilinçli bir karar
    // olmalı, sessiz bir alışkanlık değil.
    expect(
      allowedProperNouns.length,
      lessThanOrEqualTo(3),
      reason:
          'Muaf özel ad sayısı arttı. Her biri gerçekten var olan bir ad mı, '
          'yoksa kural mı esnetiliyor?',
    );
  });
}
