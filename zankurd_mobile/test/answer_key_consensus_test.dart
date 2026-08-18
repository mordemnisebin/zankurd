import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_assets.dart';

/// Bankaya giren her sorunun cevap anahtarı çapraz doğrulamadan geçmiş olmalı.
///
/// ## Kusur
///
/// 2026-08-18'de bankaya 1240 üretilmiş soru eklendi. Yapısal denetimlerin
/// hepsinden geçmişlerdi: dört ayrı şık, çözülebilir doğru cevap, kaynak
/// adresi açılıyor, konum dengesi kurulu. Hepsi doğruydu ve hiçbiri sorunun
/// DOĞRU CEVABININ doğru olduğunu söylemiyordu.
///
/// Cevap anahtarını gizleyip soruları bağımsız yanıtlatan bir tur, 94
/// soruda çelişki buldu (%7.6). Yedisi tek tek okundu ve hiçbiri yanlış
/// alarm değildi: kimi anahtarı yanlıştı ("şal û şapik" yerine "xelat û
/// şelwar"), kimi iki doğru şık taşıyordu (Zap da Sirwan da Dicle'ye
/// dökülür), kimi tek soruda iki şey soruyordu. Bu sorular oyuncuya doğru
/// cevabı verip "yanlış" derdi.
///
/// ## Kural
///
/// Bekçi cevabın doğruluğunu KENDİ ölçemez — bunun için modele sormak
/// gerekir ve birim testi ağa çıkmaz. Ölçtüğü şey sürecin uygulanmış
/// olması: `docs/content_batches/capraz_kontrol.json` bankadaki üretilmiş
/// soruların hepsini kapsamalı ve çelişenler bankada KALMAMALI.
///
/// Yeni bir üretim dalgası çapraz doğrulamadan geçmeden eklenirse bu test
/// düşer ve neyin atlandığını söyler.
void main() {
  test('üretilmiş soruların anahtarı çapraz doğrulamadan geçmiş', () {
    final report = File('docs/content_batches/capraz_kontrol.json');
    expect(
      report.existsSync(),
      isTrue,
      reason:
          'Çapraz doğrulama raporu yok. Üretilmiş soru eklendiyse '
          '`tool/content_authoring/cross_check.py` koşturulmalı.',
    );
    final verdicts =
        jsonDecode(report.readAsStringSync()) as Map<String, dynamic>;

    // Üretilmiş sorular `ds_` önekiyle ayrılır; elle yazılmış editoryal
    // içerik bu kuralın dışındadır (onların denetimi insan incelemesidir).
    final generated = <Map<String, dynamic>>[];
    for (final asset in questionBankAssets) {
      final file = File(asset);
      if (!file.existsSync()) continue;
      for (final raw in jsonDecode(file.readAsStringSync()) as List) {
        final question = raw as Map<String, dynamic>;
        if ((question['id'] as String? ?? '').startsWith('ds_')) {
          generated.add(question);
        }
      }
    }
    if (generated.isEmpty) return; // üretilmiş soru yoksa kural boşta

    final unchecked = generated
        .map((q) => q['id'] as String)
        .where((id) => !verdicts.containsKey(id))
        .toList();
    expect(
      unchecked.length,
      lessThanOrEqualTo(0),
      reason:
          '${unchecked.length} üretilmiş soru çapraz doğrulamadan geçmemiş. '
          'İlk örnekler: ${unchecked.take(8).join(", ")}',
    );

    // Karşılaştırma HARF üzerinden değil METİN üzerinden yapılır.
    // Harf kırılgan: `tool/rebalance_answer_positions.py` şık sırasını
    // değiştirdiğinde kaydedilen harf başka bir şıkkı göstermeye başlıyor
    // ve doğrulama sessizce anlamsızlaşıyor. Bu tuzağa bir kez düşüldü —
    // dengeleme aracı çalıştıktan sonra bekçi 90'dan fazla sahte çelişki
    // bildirdi.
    // İnsan incelemesiyle BİLEREK aşılan çelişkiler.
    //
    // Bekçi baştan şu varsayımla yazıldı: model bankayla çelişiyorsa şüphe
    // bankanın üzerindedir. Bu çoğu zaman doğru. Ama 2026-08-19'da Dîrok
    // incelemesi tersi bir durumu ortaya çıkardı: soru DÜZELTİLDİKTEN sonra
    // çelişki BAŞLADI, çünkü artık doğru cevap yaygın yanlış kanıyı yeniyor.
    // Modelin sezgisel yanıtı verip yanılması, sorunun kötü değil ZOR
    // olduğunun işareti — kategoride en çok eksik olan da buydu.
    //
    // Buraya bir kayıt eklemek, kaynağını yazmayı gerektirir. Liste kısa
    // kalmalı; uzarsa bekçi anlamını yitirir.
    const reviewedOverrides = <String, String>{
      // Şerefxan adını Bidlîs mîrektiyêndan alır ama orada doğmadı: 1543'te
      // Qum yakınlarındaki Karahrud'da doğdu (Encyclopaedia Iranica,
      // "BEDLĪSĪ, ŠARAF-AL-DĪN KHAN"). Model adına bakıp "Bidlîs" diyor.
      'ds_dirok_0005': 'Karahrûd (nêzî Qumê)',
      // Bedirxan Paşa 1847 yenilgisinden sonra Girit'e sürüldü; model
      // Osmanlı sürgünleri için daha bilindik olan Kıbrıs'ı seçiyor.
      'ds_dirok_0114': 'Girît',
      // Kurdistan gazetesinin ilk sayısı 1898'de Kahire'de basıldı; model
      // Osmanlı basınının merkezi olduğu için İstanbul'u seçiyor.
      'ds_dirok_0134': 'Qahîre',
    };

    final contradicting = <String>[];
    for (final question in generated) {
      final given = verdicts[question['id']] as String?;
      if (given == null || given == '?') continue;
      final id = question['id'] as String;
      final answer = question['correctAnswer'];
      if (given == answer) continue;
      // Aşma yalnız hâlâ AYNI cevap için geçerlidir: soru sonradan
      // değişirse aşma düşer ve çelişki yeniden görünür olur.
      if (reviewedOverrides[id] == answer) continue;
      contradicting.add(id);
    }
    expect(
      contradicting,
      isEmpty,
      reason:
          'Bu soruların anahtarı bağımsız yanıtla çelişiyor ve bankada '
          'duruyor; oyuncu doğru cevabı verip "yanlış" görür:\n'
          '${contradicting.take(12).join("\n")}',
    );
  });
}
