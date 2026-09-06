// İnteraktif cihaz turu: gerçek uygulamayı simülatörde sürer, dokunur,
// her adımda PNG basar.
//
// Çalıştırma (simülatör açıkken):
//   flutter test integration_test/interactive_tour_test.dart -d <device-id>
//
// Kareler çalışma dizinindeki `interactive_tour/` altına yazılır; cihazda
// bu, uygulamanın sandbox'ıdır — çekme:
//   xcrun simctl get_app_container booted com.zankurd.app data
//
// Tur BİLEREK iddialı değildir (bekçi değil, göz turudur): bir adımın
// düğmesi bulunamazsa kareyi basıp yoluna devam eder, patlamaz. Böylece
// ekran akışları değiştikçe tur çürüyeceğine kısalır.
//
// Ekran turu (`tool/screenshots/screen_tour_test.dart`) ile farkı: bu tur
// gerçek dokunuşlarla gezer (sekme, diyalog, quiz cevaplama, dil/tema),
// o tur tek kareler basar. İkisi birbirini tamamlar.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zankurd_mobile/main.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/screens/level_placement_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

String get _outDir {
  // Cihazda `Directory.current` boştur; yazılabilir tek yersiz dizin
  // `systemTemp` (sandbox tmp). Kareler koşu bitiminde HEMEN çekilmelidir
  // (tmp baskıyla temizlenebilir): tur sonundaki dizin yolunu logdan alıp
  // tüm container'larda `tmp/interactive_tour` aranır.
  return '${Directory.systemTemp.path}/interactive_tour';
}

final GlobalKey _boundaryKey = GlobalKey();

Future<void> _settle(WidgetTester tester) async {
  // Gerçek saatli cihazda süresiz bekleme yok: 10sn'de kes, kareyi bas.
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 300),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
  } catch (_) {
    // Zaman aşımı ya da çakışan animasyon: ekranda ne varsa onu yakala.
  }
  try {
    await tester.pump();
  } catch (_) {}
}

Future<void> _shoot(WidgetTester tester, String name) async {
  try {
    await tester.runAsync(() async {
      final boundary =
          _boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$_outDir/$name.png');
      await file.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      final ok = await file.exists();
      final len = ok ? await file.length() : 0;
      // ignore: avoid_print
      print('✓ $name -> ${file.path} (exists=$ok, bytes=$len)');
      // Cihaz container'ı koşu bitiminde silinir; kare log üzerinden
      // host'a base64 ile taşınır (`PNG:<ad>:<base64>`).
      // ignore: avoid_print
      print('PNG:$name:${base64Encode(bytes.buffer.asUint8List())}');
    });
  } catch (e) {
    // ignore: avoid_print
    print('✗ $name: $e');
  }
}

/// Varsa dokun, yoksa sessizce geç. Sonucu loglar (tur teşhisi).
///
/// Küçük ekranda (SE: 667pt) kat altında kalan düğmeye kör dokunuş boşa
/// gider (`warnIfMissed` yalnız uyarır, hata vermez) — tur "tamam" sanır
/// ama gezinme olmaz. Bu yüzden dokunmadan ÖNCE öğenin gerçekten
/// viewport ile kesiştiği doğrulanır; kesişmiyorsa ekran ortasından
/// yukarı sürükleyerek görünür alana getirilir (en çok 10 deneme).
Future<bool> _tapIf(
  WidgetTester tester,
  Finder finder, [
  String label = '',
]) async {
  // Zaman uyumsuz içerik (seviye yolu, rozetler) geç gelebilir: en çok
  // ~8sn belirene kadar bekle.
  var found = false;
  for (var w = 0; w < 16; w++) {
    try {
      if (finder.evaluate().isNotEmpty) {
        found = true;
        break;
      }
    } catch (_) {}
    try {
      await tester.pump(const Duration(milliseconds: 500));
    } catch (_) {}
  }
  if (!found) {
    // ignore: avoid_print
    print('TAP $label: yok');
    return false;
  }
  final view = tester.view;
  final viewport = Offset.zero & (view.physicalSize / view.devicePixelRatio);
  // Alt gezinti çubuğu opak ve dokunuşları yutar: onunla kesişen nokta
  // "viewport içinde" olsa da dokunulabilir değildir. Dokunuş noktası
  // (öğe merkezi) çubuğun üstünde kalmalıdır.
  var clearBottom = viewport.bottom;
  var hasNav = false;
  Rect navRect = Rect.zero;
  try {
    final nav = find.byType(NavigationBar);
    if (nav.evaluate().isNotEmpty) {
      navRect = tester.getRect(nav.first);
      clearBottom = navRect.top;
      hasNav = true;
    }
  } catch (_) {}
  if (label.isNotEmpty) {
    // ignore: avoid_print
    print('VIEWPORT $label: $viewport clearBottom=$clearBottom');
  }
  for (var i = 0; i < 12; i++) {
    var visible = false;
    try {
      final rect = tester.getRect(finder.first);
      final center = rect.center;
      // Çubuk kendi butonları için dokunulabilirdir; başkaları için duvar.
      // Ayrıca çubuğun hemen üstündeki dar şerit de risklidir: dokunuş
      // yalnız üst yarıda sayılır (aşağıdaki DIAG'lar 560-590 bandındaki
      // dokunuşların sessizce yutulduğunu gösterdi).
      final insideNav = hasNav && navRect.contains(center);
      // Üst sınır 40: durum çubuğu (20pt) üstü dokunulmaz, geri oku (~60)
      // dahildir.
      const safeTop = 40.0;
      final safeBottom = insideNav ? viewport.bottom : (clearBottom - 60.0);
      visible =
          center.dx >= 0 &&
          center.dx <= viewport.right &&
          center.dy >= safeTop &&
          center.dy <= safeBottom;
      if (label.isNotEmpty && !visible) {
        // ignore: avoid_print
        print('RECT $label: $rect');
      }
    } catch (_) {}
    if (visible) {
      try {
        await tester.tap(finder.first);
        await _settle(tester);
        // ignore: avoid_print
        print('TAP $label: tamam');
        return true;
      } catch (_) {
        // ignore: avoid_print
        print('TAP $label: hata');
        return false;
      }
    }
    try {
      // Hedef güvenli bandın altında kaldıysa yukarı, üstündeyse aşağı.
      var dy = -320.0;
      try {
        final c = tester.getRect(finder.first).center;
        final bottom = clearBottom - 60.0;
        if (c.dy < 40.0) {
          dy = 320.0;
        } else if (c.dy >= 40.0 && c.dy <= bottom) {
          dy = 0.0;
        }
      } catch (_) {}
      if (dy != 0.0) {
        await tester.dragFrom(viewport.center, Offset(0, dy));
        await _settle(tester);
      } else {
        break;
      }
    } catch (_) {
      break;
    }
  }
  // ignore: avoid_print
  print('TAP $label: görünmedi');
  return false;
}

/// Metinle dokun: verilen adaylardan ekranda olan ilkine basar.
Future<bool> _tapTextIf(WidgetTester tester, List<String> candidates) async {
  for (final text in candidates) {
    final finder = find.text(text);
    if (finder.evaluate().isNotEmpty) {
      try {
        await tester.tap(finder.first);
        await _settle(tester);
        return true;
      } catch (_) {}
    }
  }
  return false;
}

/// Kaydırarak bul: bulamazsa patlamaz.
Future<bool> _scrollTo(WidgetTester tester, Finder finder) async {
  try {
    await tester.scrollUntilVisible(finder, 200);
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> _backIfPossible(WidgetTester tester) async {
  final back = find.byTooltip('Vegere');
  if (back.evaluate().isNotEmpty) {
    await _tapIf(tester, back);
    return;
  }
  final backTr = find.byTooltip('Geri');
  if (backTr.evaluate().isNotEmpty) {
    await _tapIf(tester, backTr);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.profileName.completed.user': true,
      'zankurd.lang': 'tr',
      // İlk açılış öğreticisi kapalı: tur temiz soru karesi basar.
      // (Gerçek ilk deneyim ayrıca 14. kare öncesi metin-dokunuşla atlanır.)
      'zankurd.quiz_tutorial.seen': true,
    });
    await QuestionBankLoader.instance.load();
  });

  testWidgets('İnteraktif tur: dokun, gez, yakala', (tester) async {
    final repo = MockZanKurdRepository();
    final auth = AuthProvider.test(authenticated: true);

    await tester.pumpWidget(
      RepaintBoundary(
        key: _boundaryKey,
        child: ZanKurdApp(repository: repo, authProvider: auth),
      ),
    );
    await _settle(tester);
    await _shoot(tester, '00_launch');

    // Cihazda mock pref işlemezse gerçek akış: tanıtım + ad kapısı.
    for (var i = 0; i < 6; i++) {
      if (find.byKey(const ValueKey('nav-learn')).evaluate().isNotEmpty) {
        break;
      }
      await _shoot(tester, '00_onboarding_$i');
      // Ad kapısı: isimsiz geç.
      if (await _tapTextIf(tester, const ['Şimdilik geç', 'Paşê bike'])) {
        continue;
      }
      // Tanıtım: önce atla dene, yoksa ileri.
      if (await _tapTextIf(tester, const ['Atla', 'Derbas bike'])) break;
      if (!await _tapTextIf(tester, const [
        'Sonraki',
        'Bidomîne',
        'Başla',
        'Dest pê bike',
      ])) {
        break;
      }
    }
    await _shoot(tester, '01_learn_home');

    // Yarış sekmesi.
    await _tapIf(tester, find.byKey(const ValueKey('nav-play')));
    await _shoot(tester, '02_play_hub');

    // Hızlı düello → eşleşme ekranı (geri sayım bitmeden dön).
    if (await _tapIf(
      tester,
      find.byKey(const ValueKey('play-hub-quick-duel')),
    )) {
      await tester.pump(const Duration(seconds: 2));
      await _shoot(tester, '03_matchmaking');
      await _backIfPossible(tester);
    }

    // Liderlik + arkadaşlar + davet diyaloğu.
    await _tapIf(tester, find.byKey(const ValueKey('nav-leaderboard')));
    await _shoot(tester, '04_leaderboard');
    if (await _tapIf(
      tester,
      find.byKey(const ValueKey('leaderboard-friends-button')),
    )) {
      await _shoot(tester, '05_friends');
      if (await _tapIf(
        tester,
        find.byKey(const ValueKey('friends-enter-code-button')),
      )) {
        await _shoot(tester, '06_referral_dialog');
        await _backIfPossible(tester);
      }
      await _backIfPossible(tester);
    }

    // Profil + mağaza + çark.
    await _tapIf(tester, find.byKey(const ValueKey('nav-profile')));
    await _shoot(tester, '07_profile');
    if (await _tapIf(
      tester,
      find.byKey(const ValueKey('profile-menu-icon-Dukan')),
    )) {
      await _shoot(tester, '08_shop');
      if (await _tapIf(
        tester,
        find.byKey(const ValueKey('shop-spin-wheel-entry')),
      )) {
        await _shoot(tester, '09_spin_wheel');
        await _backIfPossible(tester);
      }
      await _backIfPossible(tester);
    }

    // Ayarlar: dil KU'ya al, kare bas, geri dön.
    await _tapIf(tester, find.byKey(const ValueKey('nav-learn')));
    if (await _tapIf(
      tester,
      find.byKey(const ValueKey('home-profile-header')),
    )) {
      // Profil başlığı ayarlara götürmüyorsa zararsız dokunuş olur.
    }
    await _shoot(tester, '10_learn_home_tr');

    // Solo quiz girişi: ders yolu → kategoriler → Ziman → Rêziman →
    // seviye 1 (süresiz ders modu: her cevaptan sonra açıklama gelir).
    await _tapIf(tester, find.byKey(const ValueKey('nav-learn')));
    await _scrollTo(
      tester,
      find.byKey(const ValueKey('home-browse-categories-row')),
    );
    if (await _tapIf(
      tester,
      find.byKey(const ValueKey('home-browse-categories-row')),
      'browse-categories',
    )) {
      await _shoot(tester, '11_categories');
      if (await _tapIf(
        tester,
        find.byKey(const ValueKey('category-card-Ziman')),
        'category-Ziman',
      )) {
        await _shoot(tester, '12_subcategories');
        if (await _tapIf(
          tester,
          find.byKey(const ValueKey('subcategory-card-reziman')),
          'subcategory-reziman',
        )) {
          await _shoot(tester, '13_level_path');
          await _scrollTo(tester, find.byKey(const ValueKey('level-node-1')));
          if (await _tapIf(
            tester,
            find.byKey(const ValueKey('level-node-1')),
            'level-node-1',
          )) {
            // İlk açılış öğreticisi açıksa kapat (temiz karesi için).
            await _tapTextIf(tester, const ['Derbas bike', 'Geç']);
            await _shoot(tester, '14_quiz_question');
          }
        }
      }
    }

    // Quiz döngüsü: şıklı soruları cevapla → Sonraki → sonuç ekranına.
    // (Boşluk-doldurma ve kelime-sıralama tipleri turda atlanır; şık
    // cevaplama ve sonuç akışı yerleşim yolunda uçtan uca basılır.)
    var answeredShots = 0;
    for (var round = 0; round < 16; round++) {
      if (find.byType(QuizResultScreen).evaluate().isNotEmpty) break;
      if (find.byType(QuizScreen).evaluate().isEmpty) break;
      final options = find.byType(QuizOptionTile);
      if (options.evaluate().isEmpty) {
        // Şık yoksa (boşluk-doldurma vb.) Sonraki'yi dene, yoksa bekle.
        if (!await _tapIf(
          tester,
          find.byKey(const ValueKey('quiz-next-button')),
        )) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        continue;
      }
      // İlk turda ilk şık, sonra son şık: iki geri bildirim hâli de basılır.
      final pick = (round.isEven ? options.first : options.last);
      await tester.tap(pick);
      await _settle(tester);
      if (answeredShots < 2) {
        await _shoot(tester, '15_quiz_answered_$answeredShots');
        answeredShots++;
      }
      await _tapIf(tester, find.byKey(const ValueKey('quiz-next-button')));
    }
    if (find.byType(QuizResultScreen).evaluate().isNotEmpty) {
      await _shoot(tester, '16_quiz_result');
    }

    // Seviye tespiti (yedek quiz yolu): ayarlar → yeniden ölç → 12 soru.
    // Önce quiz yığınından ana kabuğa dön (geri oku en çok 4 kez).
    if (find.byType(QuizResultScreen).evaluate().isEmpty) {
      for (var i = 0; i < 4; i++) {
        if (find.byKey(const ValueKey('nav-profile')).evaluate().isNotEmpty) {
          break;
        }
        await _backIfPossible(tester);
      }
      await _tapIf(
        tester,
        find.byKey(const ValueKey('nav-profile')),
        'nav-profile-2',
      );
      if (await _tapIf(tester, find.byIcon(AppIcons.gear), 'settings-gear')) {
        await _shoot(tester, '17_settings');
        await _scrollTo(
          tester,
          find.byKey(const ValueKey('retake-placement-action')),
        );
        if (await _tapIf(
          tester,
          find.byKey(const ValueKey('retake-placement-action')),
          'retake-placement',
        )) {
          await _shoot(tester, '18_placement_question');
          // Yerleşim 12 sorudur; tamamı doğru cevaplanıp sonuç basılır.
          for (var i = 0; i < 12; i++) {
            if (find
                .byKey(const ValueKey('placement-result-level'))
                .evaluate()
                .isNotEmpty) {
              break;
            }
            try {
              final state =
                  tester.state(
                        find.byType(LevelPlacementScreen),
                        // ignore: avoid_dynamic_calls
                      )
                      as dynamic;
              // ignore: avoid_dynamic_calls
              final current = state.currentQuestionForTest;
              await tester.tap(find.text(current.correctAnswer).last);
              await _settle(tester);
              if (i == 0) await _shoot(tester, '19_placement_answered');
            } catch (_) {
              break;
            }
          }
          await _shoot(tester, '20_placement_result');
        }
      }
    }

    // ignore: avoid_print
    print('TUR BITTI');
  });
}
