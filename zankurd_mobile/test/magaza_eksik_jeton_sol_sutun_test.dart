// 2026-10-28 kurul K11 — mağazada AYRI "N jeton eksik" satırı yok.
//
// ## Geçersiz kılınan eski karar
//
// 2026-10-20 tur 9b / kurul 4. tur: kilitli ürünün "N jeton eksik" sözü ürün
// adının altında, sol sütunda kehribar renkte yazılırdı ve bekçi onun yerini
// ve rengini sabitlerdi. K11: ekranın en kalabalık yeri buydu (her satırda
// fiyat + eksik söz + kilit); yetmeyen fiyat artık yalnız nötr, pasif bir
// fiyat hapıdır ("720") ve eksik miktar yalnız (a) ekran okuyucu etiketinde,
// (b) hapa uzun basınca çıkan ipucunda, (c) satıra dokununca açılan
// pencerede (jeton kazanma yoluyla) söylenir.
//
// ## Niçin sessiz kalırdı
//
// Eksik söz bir metin düğümü olarak geri eklense hiçbir işlev testi
// kırılmazdı; kalabalık yalnız ekran görüntüsünde fark edilir.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';

import 'support/widget_test_helpers.dart';

class _Repo extends MockZanKurdRepository {
  @override
  Future<int> loadCoinBalance() async => 300;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'yetmeyen üründe "eksik" satırı yok; hap yalnız tutarı gösterir',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(390, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        testShell(child: ShopScreen(repository: _Repo())),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('eksik'), findsNothing);
      expect(
        find.byKey(const ValueKey('shop-short-note-profile_badge_vip')),
        findsNothing,
      );

      final card = find.byKey(
        const ValueKey('shop-item-surface-profile_badge_vip'),
      );
      final pill = find.byKey(const ValueKey('shop-short-profile_badge_vip'));
      expect(pill, findsOneWidget);
      expect(
        find.descendant(of: pill, matching: find.text('720')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: pill, matching: find.byType(FilledButton)),
        findsNothing,
        reason: 'hap düğme değil durumdur',
      );
      // Ad, fiyat hapı ve (varsa) tek ikon/glif dışında kartta başka metin yok.
      final texts = find
          .descendant(of: card, matching: find.byType(Text))
          .evaluate()
          .map((e) => (e.widget as Text).data)
          .toSet();
      // 2026-10-29 vay 2B (B9): önizleme avatarı artık büyük (64 px) ve VIP
      // ürününde avatarın kendi "VIP" işaretini taşır — ürünün GÖRÜNÜŞÜ.
      expect(texts.difference({'VIP'}), {'VIP rozeti', '720'});

      // Bilgi kaybolmadı: ekran okuyucu eksik miktarı söyler.
      expect(find.bySemanticsLabel(RegExp('420 jeton eksik')), findsWidgets);
      semantics.dispose();
    },
  );
}
