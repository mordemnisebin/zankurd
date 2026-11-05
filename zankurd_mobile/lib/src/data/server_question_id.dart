import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/quiz_question.dart';

/// Yerel soru kimliğini SUNUCUDAKİ soru kimliğine (`questions.id`, uuid) çevirir.
///
/// ## Niçin var (2.1.2 W6, ChatGPT Pro alan 6 #1/#5/#3/#6)
///
/// Paketli bankadaki soru kimlikleri (`r12_sinema_001`, `hat_0011` …) uuid
/// DEĞİLDİR; sunucuya aktarılırken (`tool/sync_*_to_server.py`) kimlik
/// `uuid5(ad alanı, "zankurd-local:" + yerel id)` olarak türetildi. İstemci bu
/// çeviriyi bilmediği için:
///
/// * doğrulanmış solo turda sunucunun seçtiği uuid'ler yerel bankada hiç
///   bulunamıyor, tur sessizce yerel (doğrulanmamış) tura düşüyordu;
/// * yerel sorunun `report_question` sayacı uuid olmayan kimlikte no-op idi;
/// * aynı sorunun kalite oyu yerel ve sunucu kimliklerine bölünüyordu.
///
/// Bu dosya Python karşılığıyla (`tool/sync_sinema_to_server.py`, `NAMESPACE`)
/// BİREBİR aynı sonucu verir; bekçi: `test/server_question_id_test.dart`
/// (paketli gerçek kimlikler ↔ sunucu göçlerindeki uuid'ler).
///
/// Ad alanı DEĞİŞTİRİLMEZ: değişirse aynı sorular sunucuda ikinci kez oluşur.
const String zankurdQuestionNamespace = '5a1e2b7c-3d4f-4e60-9a8b-2c1d0f9e8a77';

final RegExp _uuidShape = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

List<int> _uuidBytes(String uuid) {
  final hex = uuid.replaceAll('-', '');
  return [
    for (var i = 0; i < 32; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ];
}

String _formatUuid(List<int> b) {
  final hex = [for (final v in b) v.toRadixString(16).padLeft(2, '0')].join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// RFC 4122 uuid5 (SHA-1) — Python `uuid.uuid5` ile aynı.
String uuid5(String namespace, String name) {
  final digest = sha1.convert([..._uuidBytes(namespace), ...utf8.encode(name)]);
  final bytes = digest.bytes.sublist(0, 16);
  bytes[6] = (bytes[6] & 0x0f) | 0x50; // sürüm 5
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 varyantı
  return _formatUuid(bytes);
}

/// [id] bir uuid mi (sunucu kimliği)?
bool isServerQuestionId(String id) => _uuidShape.hasMatch(id);

/// [id] zaten bir uuid ise (sunucudan gelen soru) küçük harfe çevrilmiş
/// hâliyle döner; değilse yerel kimliğin sunucu karşılığı olan uuid5'tir.
String serverQuestionId(String id) {
  if (_uuidShape.hasMatch(id)) return id.toLowerCase();
  return uuid5(zankurdQuestionNamespace, 'zankurd-local:$id');
}

/// Sunucu uuid'sinden yerel soruya giden harita (bkz. [serverQuestionId]).
///
/// Kaynak liste KİMLİĞİYLE önbelleğe alınır: banka yeniden yüklenince ya da
/// bir test listeyi değiştirince harita kendiliğinden yenilenir. Her solo
/// seçimde ~7.000 kimlik için yeniden uuid5 hesaplamak ve harita kurmak
/// (alan 9 #14) yerine bir kez kurulur.
class ServerQuestionIndex {
  List<QuizQuestion>? _source;
  Map<String, QuizQuestion> _map = const {};

  Map<String, QuizQuestion> of(List<QuizQuestion> source) {
    if (identical(_source, source)) return _map;
    final map = <String, QuizQuestion>{};
    for (final question in source) {
      map.putIfAbsent(serverQuestionId(question.id), () => question);
    }
    _source = source;
    return _map = map;
  }
}
