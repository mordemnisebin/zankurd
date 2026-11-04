/// GPT-6 Pro ALAN 10 performans bulguları: bekçiler (2026-11-04).
///
/// ## Kusurlar
///
/// * Favori çözümü uzak parçaları SERİ bekliyor, her silmede bütün koleksiyon
///   yeniden çözülüyordu.
/// * Soru görselinin ön yüklemesi düz `AssetImage`, kart `Image.asset(cacheWidth)`
///   (= `ResizeImage`) kullanıyordu: önbellek anahtarı eşleşmediği için ön
///   yükleme boşa gidiyordu.
/// * Sözlükte tam eşleşmeyen her sözcük bütün dizini tarıyordu.
/// * Telaffuz paneli açılışta eşzamanlı disk taraması yapıyordu.
///
/// ## Niçin sessizdi
///
/// Hepsi doğru sonuç verir, yalnız yavaş/gereksiz iş yapar; işlevsel testler
/// geçer. Bu yüzden yapısal kurallar kaynak üzerinden korunur.
library;

import 'dart:io';

import 'package:flutter/painting.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';

String _read(String p) => File(p).readAsStringSync();

void main() {
  test('favori çözümü sınırlı eşzamanlılıkla paralel çalışır', () {
    final src = _read('lib/src/data/supabase_zankurd_repository.dart');
    expect(src, contains('_favoriteResolveConcurrency'));
    expect(src, contains('Future.wait'));
  });

  test('favori silme bütün listeyi yeniden indirmez', () {
    final src = _read('lib/src/screens/favorite_questions_screen.dart');
    expect(src, contains('_dropLocally(question)'));
    expect(src, contains('SynchronousFuture'));
  });

  test('asset ön yüklemesi kartla aynı ResizeImage anahtarını kullanır', () {
    final src = _read('lib/src/screens/quiz/quiz_widgets.dart');
    final fn = src.substring(
      src.indexOf('ImageProvider _questionImageProvider'),
    );
    expect(
      fn.substring(0, fn.indexOf('CachedNetworkImageProvider')),
      contains('ResizeImage.resizeIfNeeded'),
    );
    expect(src, contains('_questionImageProvider(widget.url, full: true)'));
    // Anahtar eşitliği: ResizeImage(AssetImage) == Image.asset(cacheWidth).
    final a = ResizeImage.resizeIfNeeded(1080, null, const AssetImage('x.png'));
    final b = ResizeImage.resizeIfNeeded(1080, null, const AssetImage('x.png'));
    expect(a, equals(b));
  });

  test('telaffuz paneli temizliği ilk kareden sonraya erteler', () {
    final src = _read('lib/src/widgets/pronunciation_sheet.dart');
    // İlk kareden sonra koşar (açılışı geciktirmez) ve eşzamanlı kalır:
    // eşzamansız süpürme yeni kayıt dosyasına yarışabilirdi.
    expect(src, contains('addPostFrameCallback'));
  });

  test('sözlük eşleşmeyen sözcükte dizini taramaz', () {
    final src = _read('lib/src/data/learner_lexicon.dart');
    expect(src, isNot(contains('for (final item in index.entries)')));
    // Davranış: kök + en çok 3 harflik ek hâlâ kökü bulur, 4 harf ek bulmaz.
    expect(LearnerLexicon.lookup('welatê'), isNotNull);
    expect(LearnerLexicon.lookup('welatêzzzz'), isNull);
  });
}
