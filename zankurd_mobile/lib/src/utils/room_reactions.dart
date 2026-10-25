import '../l10n/strings.dart';

/// Odadaki hazır tepkiler (lobi ve canlı quiz aynı beşliyi gönderir).
const roomReactionKeys = [
  K.reactionBravo,
  K.reactionGoodLuck,
  K.reactionFast,
  K.reactionSmiley,
  K.reactionFire,
];

final _leadingNonLetters = RegExp(r'^[^\p{L}]+', unicode: true);

/// Yayından gelen tepki metnini alıcının dilinde döndürür; hazır tepkilerden
/// biri değilse `null` (çizilmez).
///
/// Oda yayını sohbet süzgecinden geçmez: değiştirilmiş bir istemci her
/// oyuncunun ekranına serbest metin (küfür, bağlantı) basabiliyordu
/// (2026-10-25). Gönderen kendi dilindeki etiketi yollar; alıcı da karşı
/// tarafın dilini görüyordu.
String? localizedRoomReaction(Object? raw, {required bool isKu}) {
  if (raw is! String) return null;
  // Eski istemciler etiketin önüne emoji koyuyordu ("👏 Destxweş!").
  final text = raw.trim().replaceFirst(_leadingNonLetters, '');
  for (final key in roomReactionKeys) {
    if (Tr.forKu(key, true) == text || Tr.forKu(key, false) == text) {
      return Tr.forKu(key, isKu);
    }
  }
  return null;
}
