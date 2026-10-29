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

/// Test ortamında da doğru şıkkı kaydıran `_revealCorrectAnswer`ı açar.
///
/// Kaydırma test koşucusunda kapalıdır (yerleşim testleri sabit konuma
/// güvenir); ama tam o yüzden fotoğrafı ekran dışına iten kaydırma hiçbir
/// testte çalışmıyordu. Yalnız bunu ölçen testler açar.
@visibleForTesting
bool revealCorrectAnswerInTests = false;

/// Soru kartının üstünü korurken hedefin görünür kalması gereken en az
/// yükseklik (pt).
const double _minTargetVisible = 96.0;

/// Cevaptan sonraki kaydırmada soru fotoğrafından görünür kalması gereken
/// en az yükseklik (pt).
const double _questionPhotoMinVisible = 64.0;

/// [target]'ı kayan gövdede [alignment] hizasına getirir, ama soru
/// fotoğrafını [_questionPhotoMinVisible]'dan aşağı kaybettirmez.
///
/// `Scrollable.ensureVisible` yalnız "hedef görünsün" der; fotoğraf gövdenin
/// ilk öğesi olduğundan hedef aşağıdaysa fotoğraf üst kenarın arkasına kayıp
/// ince bir şeride (ya da hiç) iniyordu. Burada hedef konum, fotoğrafın
/// alt kenarından [_questionPhotoMinVisible] pt görünür kalacak konumla
/// sınırlanır; oyuncu zaten daha aşağı kaydırmışsa onu geri çekmeyiz.
void _revealKeepingPhoto(
  BuildContext target, {
  required GlobalKey photoKey,
  GlobalKey? topKey,
  required double alignment,
  required Duration duration,
  Curve curve = Curves.easeOutCubic,
}) {
  final renderObject = target.findRenderObject();
  if (renderObject == null || !renderObject.attached) return;
  final scrollable = Scrollable.maybeOf(target);
  final viewport = RenderAbstractViewport.maybeOf(renderObject);
  if (scrollable == null || viewport == null) return;
  final position = scrollable.position;

  // 2026-10-29 son kurul tur 2 (B): hedef zaten TAMAMEN görünüyorsa gövde
  // kaydırılmaz. Hizalama (ör. 0.12) görünür bir hedefi de istenen orana
  // çekiyor, cevap anında soru kartını ve şıkları gereksizce yukarı
  // kaydırıyordu; soru ve şıklar cevaptan sonra yerinde kalır.
  final shownFrom = viewport.getOffsetToReveal(renderObject, 1.0).offset;
  final shownTo = viewport.getOffsetToReveal(renderObject, 0.0).offset;
  if (position.pixels >= shownFrom - 0.5 && position.pixels <= shownTo + 0.5) {
    return;
  }

  var offset = viewport.getOffsetToReveal(renderObject, alignment).offset;
  final photo = photoKey.currentContext?.findRenderObject();
  if (photo is RenderBox && photo.attached && photo.hasSize) {
    final photoTop = viewport.getOffsetToReveal(photo, 0).offset;
    final keep = min(photo.size.height, _questionPhotoMinVisible);
    final cap = photoTop + photo.size.height - keep;
    offset = min(offset, max(cap, position.pixels));
  }
  // W12: soru kartının ÜST kenarı görünür kalır. Açıklama kutusu uzun olunca
  // hizalama kartı üst kenarın arkasına itiyor, ilk satır kesiliyordu
  // (iOS gezinti, ios_15). Kart ekranda kalır; açıklamanın kalanı kayarak
  // okunur.
  final card = topKey?.currentContext?.findRenderObject();
  if (card is RenderBox && card.attached && card.hasSize) {
    final cardTop = viewport.getOffsetToReveal(card, 0).offset;
    final capped = min(offset, cardTop - 4);
    // Kart üstü ile hedef BİRLİKTE sığmıyorsa hedefin en az bu kadarı
    // (başlık + birkaç satır) görünür kalmalı; yoksa kuralı bırak: çok
    // uzun soru + uzun şıklarda açıklama perdenin arkasında kalmasın
    // (`quiz_stage_scroll_test` S1).
    final hidden = offset - capped;
    final targetHeight = renderObject is RenderBox && renderObject.hasSize
        ? renderObject.size.height
        : 0.0;
    if (hidden <= max(0.0, targetHeight - _minTargetVisible)) {
      offset = capped;
    } else {
      // Birlikte sığmıyor: soru kartı YARIM kesik kalmasın (ilk satırı
      // görünüp gerisi gizli kötü okunur). Ya tam görünür ya tamamen kayar.
      final cardBottom = cardTop + card.size.height;
      if (offset > cardTop - 4 && offset < cardBottom) offset = cardBottom;
    }
  }
  offset = offset.clamp(position.minScrollExtent, position.maxScrollExtent);
  if (duration == Duration.zero) {
    position.jumpTo(offset);
  } else {
    unawaited(position.animateTo(offset, duration: duration, curve: curve));
  }
}

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

@visibleForTesting
bool useCompactLandscapeLayoutForTesting(double width, double height) =>
    _useCompactLandscapeLayout(width, height);

// ─── Soru görseli yüksekliği (compact-landscape DIŞI dallar) ────────────
//
// Kusur: `_QuestionImage` görseli bu yükseklikte ÇİZERKEN,
// `_buildQuestionPanel`deki şık bütçesi (`contentBudget`) görsel hiç yokmuş
// gibi hesaplanıyordu — iki yer aynı sayıyı bilmesi gerekirken yalnız biri
// biliyordu. Sonuç: kart, görselin kapladığı kadar `minHeight`i aşıyor;
// dikey düzende D şıkkı kaydırılabilir alanın dışına, görünür ekranın
// altına düşüyordu (iPhone 17, 402×874, görselli dört şıklı soru — 2026-09-27
// simülatör turu). Tek doğru kaynak: iki çağrı yeri de BU işlevi kullanır.
double questionImagePortraitHeight(Size size, {required bool isCompact}) {
  if (isCompact) {
    // Dar/sıkışık düzende görsel de küçülür (bkz. `_QuestionImage.forcedHeight`
    // ile aynı formül: ekranın %19'u, 64–132pt arası).
    return (size.height * 0.19).clamp(64.0, 132.0);
  }
  // Rahat dikey düzende 16/9 çerçeve dar ama uzun görsellerde büyük boş
  // alan bırakıyordu; yükseklik ekranın %30'u ile sınırlanır (bkz.
  // `_QuestionImage.portraitHeight` ile aynı formül, 120–260pt arası).
  return min(size.width * 9 / 16, size.height * 0.30).clamp(120.0, 260.0);
}

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
