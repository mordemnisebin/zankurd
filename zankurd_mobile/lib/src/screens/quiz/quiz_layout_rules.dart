part of '../quiz_screen.dart';

// Bu dosya `quiz_screen.dart`tan AYRILDI (2026-08-24, A8).
//
// Ana dosya 3784 satırdı ve bakım riskiydi. Buradaki blok ayrılmaya en
// uygun olanıydı: iki sabit ve iki SAF işlev — hiçbiri `_QuizScreenState`e
// dokunmuyor, hepsi girdiden çıktı üretiyor. Yani taşınması davranışı
// değiştiremez; en güvenli ilk adım budur.
//
// Proje kuralı büyük refactor yasaklıyor. Bu bir refactor değil, bir
// bölme: tek satır kod değişmedi, yalnız yeri değişti.

// ─── Quiz yerleşim dalı seçimi ───────────────────────────────────────────
//
// Quiz'in iki yerleşimi var: dikey (stacked) akış ve telefonu yan çevirince
// devreye giren iki sütunlu "compact landscape" düzeni. İkincisi *yalnız*
// yüksekliği gerçekten kısıtlı, gerçekten yatay ekranlar için tasarlandı:
// soru solda, ilerleme ve birincil eylem sağda.
//
// Dal eskiden yalnız `constraints.maxWidth >= 700` ile seçiliyordu ve
// değişkenin adı `landscape` idi — ama yönelim hiç ölçülmüyordu. Bu yüzden
// 700px'ten geniş her viewport iki sütuna düşüyordu: bütün masaüstü
// tarayıcılar ve *dikey* tabletler dahil. Orada sağ sütun kısa kalıp tepeye
// yapıştığı için birincil eylem şıkların üstünde ve uzağında duruyor, ekranın
// altı boş kalıyordu (2026-07-31 denetimi ZKR-P1-001, 1440×900 ölçümü).
//
// Doğru ayrım genişlik değil, **kısa ve yatay** olmaktır:
//   • Masaüstü tarayıcılar genelde `width > height` olur ama telefon-yatay
//     değildir — yükseklikleri boldur, dikey akışı rahat taşırlar.
//   • Dikey tabletlerde zaten `height > width`.
// Bu yüzden koşul üç şart birden arar; yalnız biri yetmez.

/// Compact landscape dalının aradığı en küçük genişlik.
const double _compactLandscapeMinWidth = 700.0;

/// Compact landscape dalının kabul ettiği en büyük yükseklik. Telefonlar yan
/// çevrildiğinde ~375–430px'e iner; masaüstü ve tabletler bunun çok üstünde
/// kalır ve dikey akışı kullanır.
const double _compactLandscapeMaxHeight = 600.0;

/// Terminal 1v1 çağrısı sonsuza dek bekleyip geri dönüşü kilitlememeli.
const Duration _onlineResultRequestTimeout = Duration(seconds: 15);

/// İki sütunlu telefon-yatay düzeni bu viewport için uygun mu?
///
/// Beklenmeyen veya sonsuz bir yükseklik kısıtı gelirse güvenli varsayılan
/// dikey (stacked) akıştır — iki sütunlu düzen dar bir özel durumdur.
bool _useCompactLandscapeLayout(double width, double height) =>
    height.isFinite &&
    width >= _compactLandscapeMinWidth &&
    width > height &&
    height <= _compactLandscapeMaxHeight;

/// Bot düellosunda ekranda gösterilecek rakip adını seçer.
///
/// `matchmaking_screen.dart` bot rakibi bulunca kullanıcıya "X ile
/// eşleştin" diye duyurur VE `room.players`e o adı yazar. Ama bu ekran
/// eskiden o ismi hiç okumuyordu — kendi rastgele adını `BotNames.pool`dan
/// yeniden çekiyordu. Sonuç: duyurulan isim ile yarış boyunca görünen isim
/// farklıydı (2026-08-14 denetimi). `roomPlayers`de ikinci oyuncu (index 1,
/// matchmaking'in kurduğu sabit sıra: [sen, bot]) varsa onun adı kullanılır;
/// yoksa (ör. bu ekranı doğrudan kuran testler) eski rastgele seçime düşülür.
String botOpponentDisplayName(
  List<Player> roomPlayers,
  List<String> pool,
  Random random,
) {
  if (roomPlayers.length > 1) {
    final name = roomPlayers[1].name.trim();
    if (name.isNotEmpty) return name;
  }
  return pool[random.nextInt(pool.length)];
}
