/// "Kelimelerim" (Leitner) hesap eşitlemesi bekçisi (2026-11-04).
///
/// ## Kusur
///
/// Kullanıcının elle topladığı kelime listesi ve tekrar ilerlemesi
/// (`WordListStore`, kutu/vade) yalnız cihazdaki SharedPreferences'taydı;
/// telefon değişince, yeniden kurulumda ya da çıkışta sessizce giderdi.
/// Seri/rozet/ustalık zaten `player_progress` anlık görüntüsüyle hesaba
/// taşınıyordu, kelimeler dışarıda kalmıştı.
///
/// ## Niçin sessiz kalırdı
///
/// Yerel liste yerelde kusursuz çalışır; eksik olan şey başka bir cihazda
/// BİR ŞEYİN GELMEMESİdir. Hiçbir test, hata ya da ekran bunu "bozuk" göstermez
/// — kullanıcı ancak yeni telefonda boş liste görünce fark eder. Birleştirme
/// de sessiz bozulur: yanlış kural ya kelimeyi siler ya da eski cihaz yeni
/// tekrar ilerlemesini ezer.
///
/// ## Kural
///
/// * Kelimeler anlık görüntüde `words` alanında taşınır; biçim sürümü
///   ARTMAZ (eski istemci alanı yok sayar ve çalışmaya devam eder).
/// * Birleştirme: birleşim (hiçbir kelime kaybolmaz); aynı kelimede son tekrar
///   zamanı YENİ olan taraf kazanır, eşitlikte çok tekrar/yüksek kutu;
///   eklenme zamanı en erken olan.
/// * Zaman damgasız (eski) yerel kayıt, vade ve kutudan geri hesaplanır.
/// * Yerel okuma/yazma `WordListStore` JSON'uyla birebir uyumludur.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/progress_snapshot.dart';
import 'package:zankurd_mobile/src/data/progress_sync.dart';

const day = Duration.millisecondsPerDay;

ProgressSnapshot _w(Map<String, SnapshotWord> words) =>
    ProgressSnapshot(words: words);

void main() {
  group('birleştirme', () {
    test('birleşim: hiçbir kelime kaybolmaz (iki yönde)', () {
      final a = _w({'a': const SnapshotWord(added: 10)});
      final b = _w({'b': const SnapshotWord(added: 20)});
      expect(ProgressSnapshot.merge(a, b).words.keys, {'a', 'b'});
      expect(ProgressSnapshot.merge(b, a).words.keys, {'a', 'b'});
    });

    test('aynı kelimede son tekrarı yeni olan kazanır (simetrik)', () {
      const eski = SnapshotWord(
        box: 4,
        due: 100 * day,
        added: 5,
        reviews: 3,
        reviewedAt: 90 * day,
      );
      const yeni = SnapshotWord(
        box: 1,
        due: 120 * day,
        added: 8,
        reviews: 4,
        reviewedAt: 119 * day,
      );
      for (final merged in [
        ProgressSnapshot.merge(_w({'k': eski}), _w({'k': yeni})),
        ProgressSnapshot.merge(_w({'k': yeni}), _w({'k': eski})),
      ]) {
        final k = merged.words['k']!;
        expect(k.box, 1, reason: 'yanlış cevaplanıp 1. kutuya inen KAZANIR');
        expect(k.reviews, 4);
        expect(k.reviewedAt, 119 * day);
        expect(k.added, 5, reason: 'eklenme zamanı en erken');
      }
    });

    test('damgasız eski kayıt vade ve kutudan geri hesaplanır', () {
      // Kutu 2 (2 gün) vade 50. gün -> son tekrar 48. gün.
      const damgasiz = SnapshotWord(
        box: 2,
        due: 50 * day,
        added: 1,
        reviews: 2,
      );
      expect(damgasiz.effectiveReviewedAt, 48 * day);
      const hicTekrarYok = SnapshotWord(added: 7);
      expect(hicTekrarYok.effectiveReviewedAt, 7);
      const yeniCihaz = SnapshotWord(
        box: 3,
        due: 60 * day,
        added: 2,
        reviews: 3,
        reviewedAt: 52 * day,
      );
      final m = ProgressSnapshot.merge(
        _w({'k': damgasiz}),
        _w({'k': yeniCihaz}),
      );
      expect(m.words['k']!.box, 3);
    });

    test('JSON turu: words yazılır/okunur, boşken alan hiç yazılmaz', () {
      final s = _w({
        'k': const SnapshotWord(
          box: 2,
          due: 5,
          added: 1,
          reviews: 1,
          reviewedAt: 4,
        ),
      });
      final back = ProgressSnapshot.tryParse(s.toJson())!;
      expect(back.words['k']!.reviewedAt, 4);
      expect(back, s);
      expect(const ProgressSnapshot().toJson().containsKey('words'), isFalse);
      expect(s.isEmpty, isFalse);
    });

    test('eski istemcinin anlık görüntüsü (words yok) sorunsuz okunur', () {
      final legacy = ProgressSnapshot.tryParse({'v': 1, 'xp': 5})!;
      expect(legacy.words, isEmpty);
      // words, v2 şemasıyla gelen alanların biri (v1 istemci onu siliyordu).
      expect(ProgressSnapshot.currentVersion, greaterThanOrEqualTo(2));
    });
  });

  group('yerel okuma/yazma', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      LocalProgressScope.debugReset();
    });

    test(
      'WordListStore JSON\'u anlık görüntüye girer ve geri yazılır',
      () async {
        SharedPreferences.setMockInitialValues({
          'zankurd.wordList.v1':
              '{"rojbas":{"box":2,"due":1000,"added":10,"n":1,"r":900}}',
        });
        final prefs = await SharedPreferences.getInstance();
        final snap = LocalProgressSnapshot.read(prefs);
        expect(snap.words['rojbas']!.reviewedAt, 900);

        // Uzaktan yeni bir kelime ve daha yeni bir tekrar gelir.
        final remote = _w({
          'rojbas': const SnapshotWord(
            box: 3,
            due: 2000,
            added: 5,
            reviews: 2,
            reviewedAt: 1500,
          ),
          'evarbas': const SnapshotWord(added: 20),
        });
        expect(
          await LocalProgressSnapshot.write(
            prefs,
            ProgressSnapshot.merge(snap, remote),
          ),
          isTrue,
        );
        final after = LocalProgressSnapshot.read(prefs);
        expect(after.words.keys, {'rojbas', 'evarbas'});
        expect(after.words['rojbas']!.box, 3);
        expect(after.words['rojbas']!.added, 5);
      },
    );
  });
}
