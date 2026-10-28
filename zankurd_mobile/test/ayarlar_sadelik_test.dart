/// Ayarlar sade: 5 grup + hesap silme altlığı, uzun paragraf yok
/// (2026-10-28 kurul K17).
///
/// ## Kusur
///
/// Ayarlar on iki bölüm başlığına bölünmüştü (Hesap, Öğrenme, Güvenlik,
/// Gizlilik, Görünüm, Ses ve bildirim, Seslendirme, Engellenenler, Premium,
/// Hakkında, SSS, Hesap işlemleri) ve ayar satırlarının altında iki
/// cümlelik açıklamalar, kartta uygulama tanıtım paragrafı, tehlike
/// alanında ayrı bir uyarı paragrafı vardı. Kurul: "4–5 grup, açıklama yalnız
/// gereken yerde tek kısa satır".
///
/// ## Geçersiz kılınan eski kararlar
///
/// * 2026-07-22: "Hesap işlemleri"nde ayrı uyarı notu ("geri alınamaz") —
///   kaldırıldı; silme satırının kendi tek satırlık açıklaması var.
/// * 2026-10-20: "Süresiz oyna" satırının altında iki cümlelik açıklama —
///   bilgi simgesine (ipucu) ve ekran okuyucu ipucuna taşındı.
/// * Bildirim türlerinin alt satırları ve veri dışa aktarma açıklaması
///   satırdan kalktı (ekran okuyucu etiketinde yaşar).
///
/// ## Niçin sessiz kalırdı
///
/// Her ayar yine çalışıyordu; testler yalnız anahtarların varlığına bakıyordu.
/// Bölüm sayısı ve paragraf uzunluğu ölçülmeyince sayfa sessizce yeniden
/// şişerdi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final lang in ['tr', 'ku']) {
    testWidgets(
      '$lang: en çok 5 grup + altlık (6 başlık), kaldırılan paragraflar yok',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 6000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          testShell(
            languageProvider: LanguageProvider()..setLang(lang),
            child: SettingsScreen(repository: MockZanKurdRepository()),
          ),
        );
        await tester.pumpAndSettle();

        final headers = find.byType(SahneSectionHeader).evaluate().length;
        // 5 grup + "Hesap işlemleri" (hesap silme) altlığı; Premium satırı Pro
        // kapalıyken gizli.
        expect(headers, lessThanOrEqualTo(6), reason: 'bölüm başlığı sayısı');
        expect(headers, greaterThanOrEqualTo(5));

        final ku = lang == 'ku';
        String tr(String key) => Tr.forKu(key, ku);
        for (final removed in [
          K.aboutBody,
          K.dangerNote,
          K.untimedSoloSub,
          K.exportDataSub,
          K.notifContestSub,
          K.notifStreakSub,
          K.notifDuelSub,
          K.notifSocialSub,
        ]) {
          expect(find.text(tr(removed)), findsNothing, reason: removed);
        }
        // Eski ayrı başlıklar yok.
        for (final gone in [K.secSafety, K.secTts, K.secSoundNotif]) {
          expect(find.text(tr(gone)), findsNothing, reason: gone);
        }
        // Yeni beş grup başlığı var.
        for (final key in [
          K.secAccountPrivacy,
          K.secLearning,
          K.secAppSound,
          K.secNotifications,
          K.secAboutHelp,
        ]) {
          expect(
            find.descendant(
              of: find.byType(SahneSectionHeader),
              matching: find.text(tr(key)),
            ),
            findsOneWidget,
            reason: key,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'her ayar hâlâ işlevsel: anahtarlar yerinde, süresiz oyna bilgi ipucu taşır',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        testShell(child: SettingsScreen(repository: MockZanKurdRepository())),
      );
      await tester.pumpAndSettle();
      for (final key in [
        'untimed-solo-switch',
        'reduce-motion-switch',
        'analytics-consent-switch',
        'settings-notif-master',
        'settings-player-name-field',
        'settings-export-data',
        'settings-report-abuse',
        'retake-placement-action',
        'delete-account-action',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
      }
      // Süresiz oyna açıklaması paragraf değil ipucudur.
      final tip = find.byWidgetPredicate(
        (w) => w is Tooltip && (w.message ?? '').contains('süre'),
      );
      expect(tip, findsOneWidget);
      // Bilgi simgesi ≥ 48 dokunma hedefidir.
      final target = find.ancestor(
        of: find.byIcon(AppIcons.circleInfo),
        matching: find.byType(SizedBox),
      );
      expect(
        tester
            .getSize(
              find.descendant(of: tip, matching: find.byType(SizedBox)).first,
            )
            .shortestSide,
        greaterThanOrEqualTo(48),
      );
      expect(target, findsWidgets);
    },
  );
}
