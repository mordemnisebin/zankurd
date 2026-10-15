import 'dart:math';

/// İstemcinin ürettiği RFC 4122 v4 UUID (`claim_solo_reward`ın tekillik
/// anahtarı).
///
/// Kusur: solo tur ödülünün sunucuda tekillik anahtarı yoktu; yanıtı kaybolan
/// ilk çağrı sunucuda işlenmişken kuyruktaki yeniden gönderim ikinci kez
/// jeton yazıyordu. Kimlik turun İLK denemesinde üretilir, kuyruğa yazılır ve
/// her yeniden denemede aynen gider.
String newClientRoundId([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // sürüm 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // varyant 10xx
  String hex(int from, int to) => bytes
      .sublist(from, to)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// [value] sunucunun `uuid` sütununa girebilecek bir kimlik mi.
bool isClientRoundId(String? value) =>
    value != null && _uuidPattern.hasMatch(value.toLowerCase());
