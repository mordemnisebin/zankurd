/// Açılış tırnağını sonraki kelimeye yapıştırır (W17, 2026-10-28 tur 5).
///
/// Kusur: hikâye balonlarında `ki: "Hoş geldin!"` satır sonunda tırnak
/// işaretini tek başına bırakıp kelimeyi alt satıra atıyordu (öksüz tırnak,
/// Android/iOS gezinti). Çözüm: tırnak ile kelime arasına U+2060 (word
/// joiner, genişliksiz) konur; satır kırılımı oraya düşmez.
///
/// Yalnız GÖRÜNTÜ için; sesli okuma ve sözlük aramasına özgün metin gider.
String glueOpeningQuotes(String text) =>
    text.replaceAllMapped(RegExp('(["“„«‹])(?=[^\\s⁠])'), (m) => '${m[1]}⁠');
