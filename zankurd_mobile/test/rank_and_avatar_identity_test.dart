import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/avatar_presets.dart';

/// Sıfır puanla lig sırası iddia edilmez; ad değişikliği rengi silmez.
///
/// ## Kusur 1 — sıfır puanla altın lig birinciliği
///
/// Liderlik ekranı `_myRank`i doğrudan sunucunun döndürdüğü sıradan
/// alıyordu. Herkesin sıfırda eşitlendiği bir haftada o sıra
/// gelişigüzeldir: canlı denetimde iki oyuncu da 0 puandayken ekran
/// "Lîga Zêr · Rêza te ya heftane: #1" diyordu.
///
/// `profile_screen.dart` bu kapıyı 2026-07-27'de zaten koymuştu ve niçini
/// yorumunda yazılıydı: "profil '#85' derken toplam puan 0'dı ... oyuncuya
/// '85. sıradasın' demek yanlıştı." Karar verildi ama liderlik ekranına
/// uygulanmadı — iki ekran birbiriyle çelişiyordu: profil "—", liderlik
/// "#1" (2026-08-01 canlı denetimi).
///
/// Kapı iki yere birden gerekli: banner susarsa alttaki sabit "benim
/// sıram" satırı aynı yanlış iddiayı sürdürürdü.
///
/// ## Kusur 2 — ad değiştiren avatar rengini kaybediyordu
///
/// `upsertProfile`ın `avatarColor` varsayılanı `'#E94560'` idi ve o hex
/// marka paletlerinin İKİSİNDE DE yok — ne kullanıcının seçebildiği 8
/// tonda (`avatarColors`) ne isim hash'ine eşlenen 12 tonda
/// (`avatarNamePalette`). Her yeni kullanıcı hiç seçmediği ve hiçbir
/// yerden seçemeyeceği bir pembeyle başlıyordu.
///
/// Daha kötüsü: `updateProfileName` de aynı fonksiyonu çağırıyor ve
/// varsayılan yazıldığı için adını değiştiren kullanıcının SEÇTİĞİ renk
/// eziliyordu.
void main() {
  test('liderlik sırası puan kapısından geçiyor', () {
    final source = File(
      'lib/src/screens/leaderboard_screen.dart',
    ).readAsStringSync();
    final code = source
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .where((line) => !line.trimLeft().startsWith('///'))
        .join('\n')
        .replaceAll(RegExp(r'\s+'), ' ');

    expect(
      code,
      contains('return entry.totalScore > 0 ? entry.rank : null;'),
      reason:
          'Sıra doğrudan döndürülürse sıfır puanlı oyuncuya lig '
          'birinciliği verilir.',
    );
    expect(
      code,
      contains('me.rank <= 0 || me.totalScore <= 0'),
      reason:
          'Sabit "benim sıram" satırı da kapıdan geçmeli; yoksa yanlış '
          'iddia banner\'dan oraya taşınır.',
    );
  });

  test('varsayılan avatar rengi yazılmıyor', () {
    final source = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
    final code = source
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .where((line) => !line.trimLeft().startsWith('///'))
        .join('\n');

    expect(
      code,
      isNot(contains("String avatarColor = '#E94560'")),
      reason:
          'Varsayılan renk yazılırsa ad değiştiren kullanıcı seçtiği '
          'rengi kaybeder.',
    );
    expect(
      code,
      contains('String? avatarColor'),
      reason: 'Renk isteğe bağlı olmalı.',
    );
    expect(
      code.replaceAll(RegExp(r'\s+'), ' '),
      contains("'avatar_color': ?avatarColor"),
      reason: 'Renk verilmediğinde sütuna hiç dokunulmamalı.',
    );
  });

  test('paletlerde yer almayan hex hiçbir yerde varsayılan değil', () {
    // Kusurun özü buydu: `#E94560` kullanıcının hiçbir yerden
    // seçemeyeceği bir renkti. Kural genelleşiyor — üretim kodunda
    // varsayılan olarak yazılan her avatar rengi bir paletten gelmeli.
    final palette = {
      ...avatarColors.map((hex) => hex.toUpperCase()),
      ...avatarNamePalette.map(
        (color) =>
            '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}',
      ),
    };
    expect(
      palette,
      isNotEmpty,
      reason: 'Bekçi kör kalmasın: palet okunamadıysa kural boşa döner.',
    );
    expect(
      palette.contains('#E94560'),
      isFalse,
      reason:
          'Eski varsayılan gerçekten palet dışıydı; palete eklendiyse bu '
          'bekçinin gerekçesi değişti.',
    );

    final repository = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
    final defaults = RegExp(r"avatarColor\s*=\s*'(#[0-9A-Fa-f]{6})'")
        .allMatches(repository)
        .map((m) => m.group(1)!.toUpperCase())
        .toList();
    for (final hex in defaults) {
      expect(
        palette,
        contains(hex),
        reason: '$hex palet dışı bir varsayılan.',
      );
    }
  });
}
