/// `offline_tf_` tanım-takası kalıbının Rast/Şaş oranının bekçisi.
///
/// ## Kusur
///
/// `tool/author_replacement_questions.py` ve
/// `tool/author_replacements_wave2.py` (2026-07-26) her terimden iki soru
/// üretti: biri kendi tanımıyla ("Rast"), biri BAŞKA bir terimin gerçek
/// tanımıyla ("Şaş") — bkz. `retired_question_ids.dart`'ın "İkinci dalga"
/// belgesi. Üretim 133/133 dengeliydi, ama 2026-09-27 denetiminde oynanan
/// kümede 80 Rast / 152 Şaş çıktı: hep "Şaş" diyen bir strateji %66
/// kazanıyordu. Oran sorunun İÇERİĞİNDEN değil, hangi terimlerin hangi
/// kategoriye/kalıba düştüğünden kaynaklanıyordu — kimse bunu ölçmüyordu.
///
/// 152 Şaş'ın 87'si (sorulan terimden farklı TÜRDEN bir tanım taşıyanlar:
/// göl↔dağ, kişi↔çalgı, dergi↔kişi…) ve Ziman'daki 10'u (orada kalıbın hiç
/// "Rast" örneği yoktu) emekliye ayrıldı; yeni oran 80/55.
///
/// ## Niçin sessiz kalırdı
///
/// `retired_question_ids_test.dart` yalnız "emekli id bankada var mı" ve
/// "emekli id oynanmıyor mu" diye bakar — RAKAMIN NE OLDUĞUNU değil, id
/// listesinin kendi içindeki tutarlılığını denetler. Biri ileride bu
/// kalıba yeni terimler eklerken (ör. üçüncü bir dalga) hepsini "Rast"
/// (ya da hepsini "Şaş") yazsa, ya da emekliye ayırma sırasında yalnızca
/// bir taraftan (yalnız Şaş'lardan) id çıkarmaya devam etse, iki bekçi de
/// yeşil kalır: id'ler bankada duruyor, emekliler oynanmıyor — ama kalan
/// kalıbın cevap dağılımı tekrar tek yöne kayar ve "önce şıklara bak,
/// hangi kalıp Şaş baskınsa onu seç" stratejisi sessizce geri döner. Bu
/// bekçi kalan (oynanabilir, emekli olmayan) kalıbın toplam Rast/Şaş
/// oranını doğrudan ölçer.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';

void main() {
  const policy = QuestionContentPolicy();

  test('kalan tanım-takası kalıbında Rast/Şaş oranı 1:1e yakın', () {
    final playableTf = QuestionBankLoader.instance.allQuestions
        .where((q) => q.id.startsWith('offline_tf_'))
        .where(policy.isPlayable)
        .toList();

    // Kapsamın gerçekten "Rast e an şaş e" tipi bir doğru/yanlış sorusu
    // olduğunu doğrula — id öneki tek başına yeterli bir süzgeç değil.
    // Dört gövde kalıbı da (bkz. `author_replacement_questions.py`
    // TEMPLATES) bu alt dizeyi büyük/küçük harf farkıyla taşır; tekil
    // "tê vê wateyê" dizesi yalnız İLK kalıpta var, dördünde değil — bu
    // yüzden ortak payda kullanılır. Bu, ileride `offline_tf_` altına
    // farklı türden bir soru eklenirse bekçinin sessizce yanlış kümeyi
    // ölçmesini engeller.
    final offPattern = playableTf
        .where((q) => !q.prompt.toLowerCase().contains('rast e an şaş e'))
        .map((q) => q.id)
        .toList();
    expect(
      offPattern,
      isEmpty,
      reason:
          '`offline_tf_` önekli ama tanım-takası kalıbında olmayan sorular '
          'bulundu; bu bekçinin kapsamı daralmalı: $offPattern',
    );

    final rast = playableTf.where((q) => q.correctAnswer == 'Rast').length;
    final sas = playableTf.where((q) => q.correctAnswer == 'Şaş').length;
    final total = rast + sas;

    expect(
      total,
      playableTf.length,
      reason:
          'Rast/Şaş dışında bir correctAnswer değeri var; oran hesabı '
          'geçersiz.',
    );

    final rastShare = rast / total;
    final sasShare = sas / total;
    final majorityShare = rastShare > sasShare ? rastShare : sasShare;

    expect(
      majorityShare,
      lessThanOrEqualTo(0.60),
      reason:
          'Kalan kalıpta tek bir cevap ($rast Rast / $sas Şaş, toplam '
          '$total) %${(majorityShare * 100).toStringAsFixed(1)} '
          'oranında baskın — "hep aynı cevabı ver" stratejisi yeniden '
          'kazanmaya başladı. Ya yeni sorular dengesiz eklendi ya da '
          'emekliye ayırma yalnızca bir taraftan yapıldı.',
    );

    // 2026-09-27 (ikinci dalga sonrası): 80 Rast / 55 Şaş, toplam 135.
    // Bu iki sayı BİRLİKTE değişmeli: biri değişip diğeri aynı kalırsa
    // ya yeni bir tanım-takası sorusu tek taraflı eklenmiş ya da
    // emekliye ayırma yalnızca Rast/Şaş'ın birinden yapılmıştır.
    expect(
      rast,
      80,
      reason: 'Oynanabilir Rast sayısı değişti (bkz. yukarıdaki yorum).',
    );
    expect(
      sas,
      55,
      reason: 'Oynanabilir Şaş sayısı değişti (bkz. yukarıdaki yorum).',
    );
  });
}
