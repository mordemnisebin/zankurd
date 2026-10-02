import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Kaynak-önce üretilen sorunun cevabı, kaynaktan çıkarılan olguyla
/// çelişemez.
///
/// ## Kusur
///
/// 2026-08-07'de `sf_cin_0038` şöyle sevk edilmiş durumdaydı:
///
///     soru          : «Persona» hangi ülkenin yapımıdır?
///     şıklar        : Swêd / Norwec / Danîmarka / Fînlanda
///     correctAnswer : Fînlanda
///     açıklama      : «BFI kataloğuna göre bu film bir İSVEÇ yapımıdır.»
///     provenance    : exactSupportingFact = "Country: Sweden"
///     kaynak        : BFI'ın Persona sayfası
///
/// Kaynak, olgu ve kaydın kendi açıklaması — üçü de İsveç diyordu. Yalnız
/// cevap anahtarı Finlandiya'ydı. Bergman'ın filmini bilen oyuncu doğru
/// şıkkı seçip YANLIŞ işaretleniyor, ardından kendisine cevabın İsveç
/// olduğunu söyleyen açıklamayı okuyordu: bileni cezalandıran, bilmeyeni
/// ödüllendiren bir soru.
///
/// Hiçbir bekçi bunu göremezdi. Yapısal kontrollerin hepsi geçiyordu — dört
/// şık var, doğru cevap şıklar arasında, uzunluk dengeli, iki dil hizalı.
/// Kusur yapıda değil ANLAMDA'ydı.
///
/// ## Bu bekçi niçin dar
///
/// İlk yazımda kural genel tutuldu: "açıklamada anılan tek şık doğru cevap
/// olmalı". Bütün bankalarda koştuğunda 100'den fazla yanlış alarm verdi ve
/// hepsi meşru içerikti — iyi açıklamalar doğru cevabı başka sözcüklerle
/// anlatır ("Mumbai" için «Bombay»), kişileri soyadıyla anar ("Alessandro
/// Volta" için «Volta»), çeldiricileri de tanıtır. Sezgiye dayanan bir kural
/// burada gürültü üretiyordu.
///
/// Bu yüzden bekçi, kusurun ÇIKTIĞI boru hattına bağlandı: kaynak-önce
/// üretimde her sorunun provenance kaydında kaynaktan alınan olgu
/// (`exactSupportingFact`) yazılıdır. Cevap o olguyla karşılaştırılabilir ve
/// karşılaştırma kesindir. Ölçüldüğünde 101 kaydın 100'ü tutuyordu, biri
/// tutmuyordu — Persona.
void main() {
  const bankPath = 'assets/data/source_first_2026_08_questions.json';
  const provenancePath =
      'docs/content/verified_external_pool_2026_08/provenance.json';

  /// «Country: Sweden» olgusunun şıklarda alabileceği karşılıklar.
  /// Kurmancî ve Türkçe biçimler birlikte tutulur; kaynak İngilizcedir.
  const countryNames = <String, List<String>>{
    'sweden': ['swêd', 'isveç'],
    'denmark': ['danîmarka', 'danimarka'],
    'norway': ['norwec', 'norveç'],
    'finland': ['fînlanda', 'finlandiya'],
    'france': ['fransa'],
    'germany': ['almanya'],
    'italy': ['îtalya', 'italya'],
    'japan': ['japonya'],
    'india': ['hindistan'],
    'iran': ['îran', 'iran'],
    'usa': ['dya', 'abd'],
    'united states': ['dya', 'abd'],
    'united kingdom': ['brîtanya', 'birleşik krallık'],
    'soviet union': ['sovyet', 'sovyetler birliği'],
    'south korea': ['koreya başûr', 'güney kore'],
    'poland': ['polonya'],
    'spain': ['îspanya', 'ispanya'],
    'turkey': ['tirkiye', 'türkiye'],
    'iraq': ['iraq', 'irak'],
    'syria': ['sûriye', 'suriye'],
    'senegal': ['senegal'],
    'brazil': ['brezîlya', 'brezilya'],
    'mexico': ['meksîka', 'meksika'],
    'china': ['çîn', 'çin'],
    'hong kong': ['hong kong'],
    'taiwan': ['taywan', 'tayvan'],
    'russia': ['rûsya', 'rusya'],
    'austria': ['awistirya', 'avusturya'],
    'netherlands': ['hollanda'],
    'switzerland': ['swîsre', 'isviçre'],
    'belgium': ['belçîka', 'belçika'],
    'greece': ['yewnanistan', 'yunanistan'],
    'portugal': ['portekîz', 'portekiz'],
    'canada': ['kanada'],
    'australia': ['awistralya', 'avustralya'],
    'argentina': ['arjantîn', 'arjantin'],
  };

  late Map<String, Map<String, dynamic>> questions;
  late Map<String, Map<String, dynamic>> provenance;

  setUpAll(() {
    questions = {
      for (final q
          in (jsonDecode(File(bankPath).readAsStringSync()) as List)
              .cast<Map<String, dynamic>>())
        q['id'] as String: q,
    };
    provenance = {
      for (final p
          in (jsonDecode(File(provenancePath).readAsStringSync()) as List)
              .cast<Map<String, dynamic>>())
        p['originalQuestionId'] as String: p,
    };
  });

  /// Kurmancî ve Türkçe diakritikleri karşılaştırma için düzleştirir:
  /// «Îran» ile «iran», «Şerîf» ile «serif» aynı sayılır.
  String fold(String value) {
    const from = 'îêûçşğüöıİÎÊÛÇŞ';
    const to = 'ieucsguoiiieucs';
    final buffer = StringBuffer();
    for (final ch in value.toLowerCase().split('')) {
      final at = from.indexOf(ch);
      buffer.write(at < 0 ? ch : to[at]);
    }
    return buffer.toString();
  }

  test('kaynaktan alınan olgu cevap anahtarıyla tutuyor', () {
    final offenders = <String>[];
    var compared = 0;

    questions.forEach((id, q) {
      final p = provenance[id];
      if (p == null) return;
      final fact = (p['exactSupportingFact'] as String? ?? '').trim();
      final correct = q['correctAnswer'] as String;

      // ── «Country: Sweden» ────────────────────────────────────────────
      final country = RegExp(
        r'^country:\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(fact);
      if (country != null) {
        final name = country.group(1)!.split(',').first.trim().toLowerCase();
        final accepted = countryNames[name];
        if (accepted == null) {
          offenders.add(
            '$id: «$name» ülke eşlemesinde yok — tabloya eklenmeli, yoksa '
            'bu kayıt sessizce denetimsiz kalır',
          );
          return;
        }
        compared++;
        if (!accepted.map(fold).contains(fold(correct).trim())) {
          offenders.add('$id: kaynak «$name» diyor, cevap «$correct»');
        }
        return;
      }

      // ── «Year: 1966» ─────────────────────────────────────────────────
      final year = RegExp(
        r'^year:\s*(\d{4})',
        caseSensitive: false,
      ).firstMatch(fact);
      if (year != null) {
        compared++;
        if (!correct.contains(year.group(1)!)) {
          offenders.add(
            '$id: kaynak «${year.group(1)}» diyor, cevap «$correct»',
          );
        }
        return;
      }

      // ── «Director: Ingmar Bergman» / «Directed by ...» ───────────────
      final director = RegExp(
        r'^(?:director|directed by):?\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(fact);
      if (director != null) {
        // Ad tek parça eşleşmez: kaynak tam adı verirken cevap soyadı
        // taşıyabilir. Bu yüzden ad parçalarından biri yeterlidir.
        final parts = RegExp(
          r'[\p{L}]{4,}',
          unicode: true,
        ).allMatches(fold(director.group(1)!)).map((m) => m.group(0)!).toList();
        if (parts.isEmpty) return;
        compared++;
        final folded = fold(correct);
        if (!parts.any(folded.contains)) {
          offenders.add(
            '$id: kaynak «${director.group(1)}» diyor, cevap «$correct»',
          );
        }
      }
    });

    expect(
      compared,
      // Eşik 2026-08-19'da 35'ten 28'e indirildi: tekrar ayıklaması
      // `source_first` bankasından 11 kayıt aldı (96 -> 85) ve
      // karşılaştırılabilir olgu sayısı 30'a düştü. Eşiğin işi hâlâ
      // aynı — bekçinin KÖRELMESİNİ yakalamak; ölçtüğü havuz küçüldü.
      // 28, bugünkü 30'un iki altında: küçük dalgalanmaya izin verir,
      // havuzun yarıya düşmesini yakalar.
      greaterThanOrEqualTo(28),
      reason:
          'Karşılaştırılan kayıt sayısı $compared — beklenmedik biçimde '
          'düştü. Bekçi körelmiş olabilir: provenance yolu ya da olgu '
          'biçimi («Country:», «Year:», «Director:») değişti mi?',
    );
    expect(
      offenders,
      isEmpty,
      reason:
          'Cevap anahtarı, sorunun dayandığı kaynakla çelişiyor. Bileni '
          'cezalandıran soru budur:\n${offenders.join("\n")}',
    );
  });

  test('bekçi gerçekten yakalıyor', () {
    // Kural yanlış yazılırsa üstteki test boş listeyle sessizce geçer.
    // Persona kaydının kusurlu hâli burada yeniden kuruluyor.
    const fact = 'Country: Sweden';
    final match = RegExp(
      r'^country:\s*(.+)$',
    ).firstMatch(fact.toLowerCase().trim());
    expect(match, isNotNull, reason: 'Olgu biçimi tanınmadı');

    final accepted = countryNames[match!.group(1)!.trim()]!;
    expect(
      accepted.contains('fînlanda'),
      isFalse,
      reason: 'Kusurlu anahtar («Fînlanda») yakalanmalıydı',
    );
    expect(
      accepted.contains('swêd'),
      isTrue,
      reason: 'Doğru anahtar («Swêd») kabul edilmeliydi',
    );
  });
}
