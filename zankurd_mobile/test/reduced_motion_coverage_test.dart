import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// "Hareketi azalt" tercihi uygulamanın yarısında yok sayılıyordu
/// (2026-08-02 denetimi).
///
/// `ReducedMotionProvider` ve Ayarlar'daki anahtar zaten vardı ve bazı
/// yerlerde doğru uygulanıyordu (konfeti, kilim, iskelet yükleyici, quiz
/// zamanlayıcı). Ama en çok hareket üreten dört kaynak onu HİÇ okumuyordu:
///
///   * quiz şık kartlarının sarsıntı/zıplama animasyonu — uygulamanın en
///     çok görülen ekranı,
///   * `BouncingButton` — uygulamanın her yerinde,
///   * `AppRoute` sayfa geçişleri — her gezinmede,
///   * çarkın 3.8 saniyelik dönüşü.
///
/// Bir erişilebilirlik tercihi kısmen uygulandığında, uygulanmamış gibi
/// davranır: tercihi açan kullanıcı yine sallanan kartlar ve kayan sayfalar
/// görüyordu. Vestibüler rahatsızlığı olan biri için bu, ayarın hiç
/// olmamasından farksızdır.
///
/// Bekçi kaynak düzeyinde çalışır: bu dosyalar animasyon barındırdığı
/// sürece tercihi de okumak ZORUNDADIR.
void main() {
  /// Animasyon üreten ve tercihi okumak zorunda olan dosyalar.
  const mustHonour = <String>[
    'lib/src/screens/quiz/quiz_option_tile.dart',
    'lib/src/widgets/bouncing_button.dart',
    'lib/src/utils/app_route.dart',
    'lib/src/screens/spin_wheel_screen.dart',
    // Zaten uyanlar — geri gitmesinler diye listede.
    'lib/src/widgets/confetti_overlay.dart',
    'lib/src/widgets/skeleton_loader.dart',
    'lib/src/screens/quiz/quiz_effects.dart',
  ];

  for (final path in mustHonour) {
    test('${path.split('/').last} hareketi azalt tercihini okuyor', () {
      final src = File(path).readAsStringSync();
      expect(
        src,
        anyOf(
          contains('ReducedMotionProvider'),
          contains('reduceMotion'),
          contains('isReducedIn'),
        ),
        reason:
            '$path animasyon üretiyor ama "hareketi azalt" tercihini hiç '
            'okumuyor; tercih kısmen uygulandığında hiç uygulanmamış gibi '
            'davranır',
      );
    });
  }

  /// RATCHET: bilinen borç dondurulur, BÜYÜMESİ engellenir.
  ///
  /// Denetimde 12 dosyanın daha animasyon üretip tercihi okumadığı
  /// bulundu. Hepsini tek turda düzeltmek sorumsuzca olurdu — her biri
  /// ayrı bir davranış kararı (bir animasyon süs mü, yoksa durum mu
  /// taşıyor?). Bu yüzden borç sayı olarak dondurulur: yeni bir ihlal
  /// eklenirse test kırılır, düzeltildikçe sayı DÜŞÜRÜLMELİDİR.
  ///
  /// Aynı desen depoda zaten var (`*_ratchet_test.dart`).
  test('hareketi azalt borcu büyümüyor', () {
    const knownDebt = 12;

    /// Sürekli/işlevsel göstergeler: süs değil, durum taşıyorlar.
    const exempt = <String>{
      'lib/src/widgets/branded_loader.dart',
      'lib/src/widgets/kilim_progress_bar.dart',
      'lib/src/widgets/loading_overlay.dart',
      'lib/src/widgets/mission_toast.dart',
      'lib/src/widgets/coach_mark.dart',
      'lib/src/widgets/roj_mascot.dart',
      'lib/src/animations/load_animations.dart',
    };

    /// Yorumları atar.
    ///
    /// Tarama ham metinde arıyordu ve bir YORUMDA geçen
    /// `AnimationController` sözcüğü de ihlal sayılıyordu. 2026-08-12'de
    /// `question_timer_resume.dart` tam bu yüzden listeye girdi: dosyada tek
    /// satır animasyon kodu yok, yalnız kusuru anlatan belge o sınıfı adıyla
    /// anıyor. Borcu bir artırmak kusuru gizlerdi; ölçüm düzeltildi.
    String withoutComments(String source) => source
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), ' ')
        .split('\n')
        .map((line) {
          final index = line.indexOf('//');
          return index == -1 ? line : line.substring(0, index);
        })
        .join('\n');

    final offenders = <String>[];
    for (final entity in Directory('lib/src').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final src = withoutComments(entity.readAsStringSync());
      final animates =
          src.contains('AnimationController') ||
          src.contains('TweenAnimationBuilder');
      if (!animates) continue;
      final honours =
          src.contains('ReducedMotionProvider') ||
          src.contains('reduceMotion') ||
          src.contains('isReducedIn');
      if (!honours && !exempt.contains(entity.path)) {
        offenders.add(entity.path);
      }
    }

    expect(
      offenders.length,
      lessThanOrEqualTo(knownDebt),
      reason:
          'Tercihi okumayan yeni bir animasyon kaynağı eklendi. Ya tercihi '
          'okuyun ya da gerekçesiyle exempt listesine alın:\n'
          '${offenders.join('\n')}',
    );

    // Borç azaldıysa sayacı düşürmeyi hatırlat: ratchet ancak sıkıldıkça
    // işe yarar.
    expect(
      offenders.length,
      greaterThanOrEqualTo(knownDebt - 2),
      reason:
          'Borç ${offenders.length}e düştü; knownDebt sabitini güncelleyin '
          'ki kazanım kalıcı olsun.',
    );
  });
}
