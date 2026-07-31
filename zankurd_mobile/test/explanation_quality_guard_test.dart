import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Açıklama kalitesi bekçisi.
///
/// 2026-07-25 canlı denetimi: cevap verildikten sonra açılan "Açıklama ·
/// Zana" paneli, soruların bir bölümünde hiçbir şey öğretmiyordu. İki
/// kalıp saf gürültüydü:
///
///   • "…îdiaya di vê pirsê de ne rast e; bersiva rast 'Şaş' e."
///     Cevap zaten ekranda yeşil olarak duruyor.
///   • "misafirperverlik Kürt kültürü kategorisinde ele alınır."
///     Kategori zaten soru kartının üstünde çip olarak yazıyor.
///
/// Bunlar `tool/strip_empty_explanations.py` ile temizlendi. Boş açıklamada
/// panel hiç açılmadığı için sonuç "öğretmeyen panel" yerine "panel yok"
/// olur — sessiz ama dürüst.
///
/// Bu test kalıpların bankaya geri sızmasını engeller. Yeni soru üreten
/// araçlar bu şablonları yeniden kullanırsa burada yakalanır.
/// Her iki bankanın soruları — kaçaklar ikisine de dağılmıştı.
List<Map<String, dynamic>> _allBankQuestions() {
  final all = <Map<String, dynamic>>[];
  for (final name in const [
    'assets/data/offline_questions.json',
    'assets/data/editorial_questions.json',
  ]) {
    final file = File(name);
    expect(file.existsSync(), isTrue, reason: '$name bulunamadı');
    all.addAll(
      (jsonDecode(file.readAsStringSync()) as List)
          .cast<Map<String, dynamic>>(),
    );
  }
  return all;
}

void main() {
  test('soru bankasında bilgi taşımayan açıklama kalıbı yok', () {
    final file = File('assets/data/offline_questions.json');
    expect(file.existsSync(), isTrue, reason: 'soru bankası bulunamadı');

    final questions = (jsonDecode(file.readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
    expect(questions, isNotEmpty);

    final noise = RegExp(
      r"îdiaya di vê pirsê de|bersiva rast\s*['«]"
      r'|kategorisinde ele alınır|kategorisinde değerlendirilir'
      r'|têgeheke derbasdar e|geçerli bir kavramdır',
      caseSensitive: false,
    );

    final offenders = <String>[];
    for (final question in questions) {
      for (final field in ['explanation', 'explanationKu', 'explanationTr']) {
        final value = (question[field] as String?) ?? '';
        if (value.isNotEmpty && noise.hasMatch(value)) {
          offenders.add('${question['id']} ($field): $value');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Bilgi taşımayan açıklama kalıbı geri gelmiş '
          '(${offenders.length} adet). İlk üç örnek:\n'
          '${offenders.take(3).join("\n")}\n'
          'Temizlemek için: python3 tool/strip_empty_explanations.py',
    );
  });

  test('Kurmancî açıklama Türkçenin kopyası değil', () {
    // 2026-07-27: iki soruda `explanationKu` ile `explanationTr` birebir
    // aynıydı ve ikisi de **Türkçeydi**. Yani Kurmancî arayüzde soru
    // Kurmancî, açıklaması Türkçe çıkıyordu; Kurmancîsi hiç yazılmamış,
    // Türkçesi kopyalanmıştı.
    //
    // Bu kusur gözle bulunmaz: açıklama panelinde bir metin vardır, dolu
    // görünür ve doğrudur — yalnız dili yanlıştır. Eşitlik ölçütü bunu
    // kelime bilgisi gerektirmeden yakalar.
    final offenders = <String>[];
    for (final question in _allBankQuestions()) {
      final ku = (question['explanationKu'] as String?)?.trim();
      final tr = (question['explanationTr'] as String?)?.trim();
      if (ku == null || tr == null || ku.isEmpty) continue;
      if (ku == tr) offenders.add(question['id'] as String);
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Kurmancî açıklaması Türkçenin kopyası: ${offenders.join(", ")}',
    );
  });

  test('Kurmancî soru gövdesinde Türkçe harf yok', () {
    // Açıklamalarla aynı ölçüt gövdelere de uygulanır: 2026-07-27'de iki
    // Paradigma sorusunun gövdesinde "ölçüya" duruyordu — hem yanlış
    // sözcük hem de cümlenin tanımladığı kavramın ("pîvana azadiyê")
    // Kurmancî karşılığı. Yani soru, öğrettiği sözcüğü kendisi yanlış
    // yazıyordu.
    final quoted = RegExp(r'''«[^»]*»|"[^"]*"|'[^']*'|\([^)]*\)''');
    final turkish = RegExp('[ığöüİĞÖÜ]');
    // Türkçe özel adlar Kurmancî gövdede de aynen yazılır.
    const properNames = {'offline_10344', 'edit_sinema_0005'};

    final offenders = <String>[];
    for (final question in _allBankQuestions()) {
      final id = question['id'] as String;
      if (properNames.contains(id)) continue;
      final prompt = question['prompt'] as String;
      if (turkish.hasMatch(prompt.replaceAll(quoted, ''))) offenders.add(id);
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Kurmancî gövdede Türkçe harf: ${offenders.join(", ")}',
    );
  });

  test('Kurmancî açıklamada Türkçe harf yok', () {
    // Kurmancî alfabesinde ı, ğ, ö, ü ve İ yoktur. Alıntı ve parantez içi
    // karşılıklar ("teşekkür", (kapıcı)) bilinçli sözlük biçimidir; onlar
    // sayılmaz. Geriye kalan bir Türkçe harf ya sızmış kelimedir ya da
    // yanlış yazımdır — 2026-07-27'de "ölçüya" (doğrusu "pîvana") böyle
    // bulundu.
    final quoted = RegExp(r'''«[^»]*»|"[^"]*"|'[^']*'|\([^)]*\)''');
    final turkish = RegExp('[ığöüİĞÖÜ]');
    // Türkçe özel adlar Kurmancî cümlede de aynen yazılır. Kurmancî
    // kaynaklar da yönetmenlerin resmî ad yazımını korur; "Oz" yazmak
    // kişiyi aranamaz hâle getirir.
    //   edit_sinema_0025 → Zeki Ökten
    //   offline_sin_2017 → Kazim Öz
    const properNames = {'edit_sinema_0025', 'offline_sin_2017'};

    final offenders = <String>[];
    for (final question in _allBankQuestions()) {
      final id = question['id'] as String;
      if (properNames.contains(id)) continue;
      final ku = question['explanationKu'] as String?;
      if (ku == null) continue;
      if (turkish.hasMatch(ku.replaceAll(quoted, ''))) offenders.add(id);
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Kurmancî açıklamada Türkçe harf: ${offenders.join(", ")}',
    );
  });

  test('açıklama alanı olan sorularda metin anlamlı uzunlukta', () {
    final file = File('assets/data/offline_questions.json');
    final questions = (jsonDecode(file.readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();

    // Boş bırakmak serbest (panel açılmaz); ama dolu bırakılıp tek kelime
    // yazmak paneli açar ve yine hiçbir şey öğretmez.
    final tooShort = questions.where((q) {
      final value = ((q['explanation'] as String?) ?? '').trim();
      return value.isNotEmpty && value.length < 12;
    }).toList();

    expect(
      tooShort,
      isEmpty,
      reason:
          '${tooShort.length} soruda açıklama var ama 12 karakterden kısa; '
          'panel açılır, içerik vermez.',
    );
  });

  test('açıklama soruyu tekrar etmekle yetinmiyor', () {
    // Uzunluk bir açıklamanın bilgi taşıdığını göstermez. 2026-07-30'da
    // ölçüldü: 263 soruda açıklama, soru gövdesinde ve doğru cevapta zaten
    // geçen sözcüklerden başka **hiçbir** sözcük taşımıyordu.
    //
    //   S : Rast e an şaş e: Têgeha «Arabê Şamo» tê vê wateyê: …
    //   A : Erê, ev ravekirin bi rastî ya «Arabê Şamo» e.        (213 soru)
    //
    //   S : Hejmara «pênc» bi Tirkî çi ye?
    //   A : «pênc»: beş.                                          (50 soru)
    //
    // Oyuncu turu bitirdiğinde sonuç ekranında bu satırları okur; orası
    // turun tek öğretme anıdır (bkz. `lesson_explanation_test`). Cevabı
    // ikinci kez yazmak o anı harcar.
    //
    // 263'ü düzeltildi. Rast/Şaş ailesi artık aynı kategoriden ikinci bir
    // terimin tanımını verir — uydurma değil, bankanın kendi Şaş
    // açıklamalarından türetilmiş. Sözlük soruları kullanım örneği alır.
    //
    // Kalan borç, açıklaması doğru cevabın birebir tekrarı olan sorular:
    // "«destmal»: destmala ku serê govendê dihejîne." Bunlar el yazımı
    // gerektirir — her biri ayrı bir kültür/siyaset/müzik bilgisidir ve
    // uydurmak düzeltmemekten kötüdür. Tavan bir mandaldır: yalnız
    // inebilir. Yeni soru bu kusuru bankaya geri sokamaz.
    //
    // Kalan 208 = offline 179 + editoryal 29. Kategoriye göre offline
    // dağılımı: Paradigma 30, Çand 28, Siyaset 26, Muzîk 25, Edebiyat 21,
    // Dîrok 20, Cografya 19, Ziman 10.
    const ceiling = 208;

    // `\w` Dart'ta ASCII'dir: "çîrokê" üç parçaya bölünür ve hepsi
    // uzunluk süzgecine takılır, yani Kurmancî bir açıklama "boş" görünür.
    // Unicode harf sınıfı şart.
    final word = RegExp(r'[\p{L}\p{N}]+', unicode: true);
    Set<String> significant(String? value) => word
        .allMatches((value ?? '').toLowerCase())
        .map((m) => m[0]!)
        .where((w) => w.length > 3)
        .toSet();

    final restating = <String>[];
    for (final question in _allBankQuestions()) {
      final explanation =
          (question['explanationKu'] as String?) ??
          (question['explanation'] as String?);
      final words = significant(explanation);
      if (words.isEmpty) continue;
      final body = significant(question['prompt'] as String?)
        ..addAll(significant(question['correctAnswer'] as String?));
      if (words.difference(body).isEmpty) {
        restating.add(question['id'] as String);
      }
    }

    expect(
      restating.length,
      lessThanOrEqualTo(ceiling),
      reason:
          'Açıklaması soruya hiçbir yeni sözcük eklemeyen soru sayısı '
          '${restating.length}, tavan $ceiling. Yeni örnekler: '
          '${restating.take(5).join(", ")}',
    );
  });
}
