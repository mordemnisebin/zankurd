/// Tamamlanmış görev/devir belgelerinin geri gelmediğinin bekçisi.
///
/// ## Kusur
///
/// `docs/OTONOM_IS_LISTESI.md`, `KALAN_ISLER_GOREVI.md`,
/// `TASARIM_TAMAMLAMA_GOREVI.md` ve `TASARIM_DEVAM_NOTU.md` tamamlanmış
/// görev/devir notlarıydı — hepsi "TARİHÎ" şeridi taşıyordu ve 2026-09-27
/// belge temizliğinde silindi (bulgular artık kodda, testlerde ve
/// `applied.md`'de). Onları koruyan tek bekçi kendi şeritlerini
/// doğruluyordu; dosyalarla birlikte o bekçi de gitti. Geriye, "bu tür bir
/// dosya bir daha eklenmesin" diyen hiçbir kapı kalmamıştı — bir sonraki
/// ajan "kalan işler" sanıp benzer bir GOREVI/DEVAM_NOTU/OTONOM_ dosyasını
/// sessizce geri getirebilirdi.
///
/// ## Niçin sessiz kalırdı
///
/// Yeni bir `..._GOREVI.md` ya da `..._DEVAM_NOTU.md` eklemek
/// `dart analyze`yi kırmaz, hiçbir testi bozmaz, uygulama çalışır; yalnız
/// kökteki `CLAUDE.md`'nin "eski handoff, tamamlanmış plan ... bilerek
/// silinmiştir. Bunları güncel kaynak gibi yeniden oluşturma." politikasını
/// ihlal eder. Bekçi yalnız `zankurd_mobile/docs/` ve kök `docs/`ün ÜST
/// düzeyine bakar; `docs/content_batches/SPARK_GOREVI_sik_kalitesi.md` gibi
/// editoryal içerik dosyaları (bu bekçinin kapsamı dışında, dokunulmaz)
/// alt klasörlerde kalır ve "GOREVI" kelimesini farklı, meşru bir anlamda
/// (soru kalitesi görevi) kullanır — bu yüzden tarama alt klasörlere inmez.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dir in ['docs', '../docs']) {
    test('$dir üst düzeyinde tamamlanmış görev/devir belgesi yok', () {
      expect(
        Directory(dir).existsSync(),
        isTrue,
        reason: 'Bekçi kör kalmasın: $dir bulunamadı.',
      );

      final eskiler = Directory(dir)
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where(
            (name) =>
                name.endsWith('.md') &&
                (name.contains('GOREVI') ||
                    name.contains('DEVAM_NOTU') ||
                    name.contains('OTONOM_')),
          )
          .toList();

      expect(
        eskiler,
        isEmpty,
        reason:
            'Tamamlanmış görev/devir belgesi gibi görünen dosya bulundu: '
            '${eskiler.join(", ")}. CLAUDE.md: eski handoff/tamamlanmış '
            'plan belgeleri bilerek silinmiştir, geri getirme; bulguyu '
            'koda, teste ya da applied.md\'ye yaz.',
      );
    });
  }
}
