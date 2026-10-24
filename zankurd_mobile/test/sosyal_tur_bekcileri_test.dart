import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/utils/player_identity.dart';

/// 2026-10-21 iki simülatörlü oyun testinin bekçileri.
///
/// 1. Sonuç ekranının üst satırında depo kimliği "crowd" ham basılıyordu.
/// 2. Adsız oyuncu dört ayrı biçimde görünüyordu.
void main() {
  test('depo kimlikleri (crowd, 1vs1) başlıkta ham yazılmaz', () {
    String title(String name) => quizRoundTitle(
      roomId: null,
      roomCode: '',
      roomName: name,
      category: '',
      isKu: false,
      roomWord: 'Oda',
      raceWord: 'Yarış',
      crowdTitle: 'Grup yarışı',
    );
    expect(title('crowd'), 'Grup yarışı');
    expect(title('1vs1'), 'Yarış');
    expect(title('Günün Dersi'), 'Günün Dersi');
  });

  test('özel kategori kimlikleri yerelleştirilir', () {
    for (final slug in ['mixed', 'random', 'crowd']) {
      expect(CategoryNames.localized(slug, false), isNot(slug));
      expect(CategoryNames.localized(slug, true), isNot(slug));
    }
    expect(
      CategoryNames.localized('mixed', false),
      Tr.forKu(K.catTevlihev, false),
    );
  });

  test('adsız oyuncu her yerde aynı biçimde: Oyuncu [+ ZK kodu]', () {
    for (final raw in [null, '', 'ZanKurd Oyuncusu', 'Oyuncu', 'Lîstikvan']) {
      expect(
        PlayerIdentity.resolveNameWithTag(raw, isKu: false, tag: 'R5C4'),
        'Oyuncu ZK-R5C4',
      );
      expect(
        PlayerIdentity.resolveNameWithTag(raw, isKu: true, tag: 'ZK-R5C4'),
        'Lîstikvan ZK-R5C4',
      );
      expect(PlayerIdentity.resolveNameWithTag(raw, isKu: false), 'Oyuncu');
    }
    expect(
      PlayerIdentity.resolveNameWithTag('Ayşe', isKu: false, tag: 'R5C4'),
      'Ayşe',
    );
  });
}
