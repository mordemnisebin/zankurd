import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/server_question_id.dart';

/// Yerel soru kimliği → sunucu uuid'i çevirisi Python (`tool/sync_*_to_server.py`)
/// ile birebir aynı sonucu vermeli.
///
/// ## Kusur (alan 6 #1)
///
/// Doğrulanmış solo tur, sunucunun seçtiği uuid'leri yerel bankada
/// `local.containsKey(id)` ile arıyordu; paketli kimlikler uuid olmadığından
/// HİÇBİRİ bulunmuyor, tur sessizce yerel tura düşüyordu. Eski test
/// (`verified_solo_daily_test.dart`) yalnız doğrudan uuid kimlikli yapay soru
/// kullandığından bunu yakalamıyordu.
///
/// ## Bekçi
///
/// Paketli GERÇEK kimlikler (yeni, yeni2, yeni3 bankaları) için üretilen uuid,
/// sunucu göçlerinde (`2026-11-07/10/14_*.sql`) yazılı uuid ile eşleşmeli.
/// Göçler zaten Python üreticisiyle yazıldığından bu, Dart ↔ Python eşitliğinin
/// kanıtıdır.
void main() {
  test('örnek kimlikler Python uuid5 ile aynı (altın değerler)', () {
    expect(
      serverQuestionId('r12_sinema_001'),
      '12a14403-bff0-520a-b6cf-11578ede5b51',
    );
    expect(
      serverQuestionId('r12_sinema_002'),
      '23f6f149-01a2-51f5-abe5-febfe7720abe',
    );
  });

  test('uuid olan kimlik aynen (küçük harf) döner, uuid olmayan çevrilir', () {
    const server = 'E9100141-DF1C-48A6-B4EC-9D0D9AD9A956';
    expect(serverQuestionId(server), server.toLowerCase());
    expect(isServerQuestionId(server), isTrue);
    expect(isServerQuestionId('hat_0011'), isFalse);
    expect(isServerQuestionId(serverQuestionId('hat_0011')), isTrue);
    // Çeviri tek yönlü ve kararlı: aynı girdi hep aynı uuid.
    expect(serverQuestionId('hat_0011'), serverQuestionId('hat_0011'));
    expect(
      serverQuestionId(serverQuestionId('hat_0011')),
      serverQuestionId('hat_0011'),
      reason: 'zaten uuid olan ikinci kez çevrilmez',
    );
  });

  for (final pair in const [
    ('yeni_2026_11_07_questions.json', '2026-11-07_yeni_sorular.sql'),
    ('yeni2_2026_11_10_questions.json', '2026-11-10_yeni_sorular_2.sql'),
    ('yeni3_2026_11_14_questions.json', '2026-11-14_yeni_sorular_3.sql'),
  ]) {
    test(
      '${pair.$1}: her paketli kimlik sunucu göçündeki uuid ile eşleşir',
      () {
        final bank =
            jsonDecode(File('assets/data/${pair.$1}').readAsStringSync())
                as List<dynamic>;
        final sql = File('supabase/${pair.$2}').readAsStringSync();
        expect(bank, isNotEmpty);
        final missing = <String>[];
        for (final raw in bank) {
          final id = (raw as Map<String, dynamic>)['id'] as String;
          if (!sql.contains("'${serverQuestionId(id)}'")) missing.add(id);
        }
        expect(missing, isEmpty, reason: 'göçte uuid5 karşılığı yok: $missing');
      },
    );
  }
}
