// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

/// Şahnê bileşen galerisi: her bileşeni (her çeşidiyle) gece ve gündüz
/// temasında ayrı ekranlarda çizip PNG'ye basar.
///
/// ```bash
/// flutter test tool/screenshots/sahne_gallery_test.dart
/// ZANKURD_GALLERY_OUT_DIR=/tmp/galeri flutter test tool/screenshots/sahne_gallery_test.dart
/// ```
///
/// Niçin var: bileşenler 39 ekrana uygulanmadan önce maketle
/// (`zankurd-tasarim/design/render_sahne.png`) yan yana karşılaştırılır.
/// Test koşucusu yazı ve ikon yazı tiplerini kendiliğinden yüklemez; yükleme
/// `screen_tour_test.dart`taki gibi elle yapılır (yoksa her metin kutu
/// çizilir).
final _outDir =
    Platform.environment['ZANKURD_GALLERY_OUT_DIR'] ??
    '/Users/kocer/Projects/zankurd-tasarim/gallery';

final GlobalKey _boundaryKey = GlobalKey();

const _images = [
  'assets/question_images/cat_ziman.webp',
  'assets/question_images/cat_cand.webp',
  'assets/question_images/cat_dirok.webp',
  'assets/question_images/cat_muzik.webp',
  'assets/question_images/cat_edebiyat.webp',
  'assets/zankurd_icon.webp',
];

AssetImage _img(String name) =>
    AssetImage('assets/question_images/cat_$name.webp');

String _flutterSdkRoot() {
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.path != dir.parent.path) {
    if (Directory(
      '${dir.path}/bin/cache/artifacts/material_fonts',
    ).existsSync()) {
      return dir.path;
    }
    dir = dir.parent;
  }
  return '';
}

Future<void> _loadFonts() async {
  const families = {
    'Onest': [
      'assets/fonts/Onest-Regular.ttf',
      'assets/fonts/Onest-Medium.ttf',
      'assets/fonts/Onest-SemiBold.ttf',
      'assets/fonts/Onest-Bold.ttf',
    ],
    'BricolageGrotesque': [
      'assets/fonts/BricolageGrotesque-Bold.ttf',
      'assets/fonts/BricolageGrotesque-ExtraBold.ttf',
    ],
  };
  for (final family in families.entries) {
    final loader = FontLoader(family.key);
    for (final path in family.value) {
      loader.addFont(
        File(path).readAsBytes().then((b) => ByteData.view(b.buffer)),
      );
    }
    await loader.load();
  }
  final materialIcons = File(
    '${_flutterSdkRoot()}/bin/cache/artifacts/material_fonts/'
    'MaterialIcons-Regular.otf',
  );
  if (materialIcons.existsSync()) {
    await (FontLoader('MaterialIcons')..addFont(
          materialIcons.readAsBytes().then((b) => ByteData.view(b.buffer)),
        ))
        .load();
  }
  // Lucide artık paket değil uygulamanın kendi varlığıdır (`pubspec.yaml`,
  // aile `Lucide`, `fontPackage` yok); öneksiz adla yüklenmeli.
  final lucide = File('assets/fonts/Lucide.ttf');
  if (lucide.existsSync()) {
    await (FontLoader('Lucide')
          ..addFont(lucide.readAsBytes().then((b) => ByteData.view(b.buffer))))
        .load();
  } else {
    print('UYARI: assets/fonts/Lucide.ttf bulunamadı — ikonlar kare çizilecek');
  }
  final packageConfig =
      jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
          as Map<String, dynamic>;
  String packageRoot(String name) {
    final entry = (packageConfig['packages'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((p) => p['name'] == name);
    final root = Uri.parse(entry['rootUri'] as String).toFilePath();
    return root.endsWith(Platform.pathSeparator)
        ? root
        : '$root${Platform.pathSeparator}';
  }

  const iconFonts = {
    'font_awesome_flutter': {
      'FontAwesomeSolid': 'lib/fonts/Font-Awesome-7-Free-Solid-900.otf',
      'FontAwesomeRegular': 'lib/fonts/Font-Awesome-7-Free-Regular-400.otf',
      'FontAwesomeBrands': 'lib/fonts/Font-Awesome-7-Brands-Regular-400.otf',
    },
  };
  for (final package in iconFonts.keys) {
    final base = packageRoot(package);
    for (final family in iconFonts[package]!.entries) {
      final file = File('$base${family.value}');
      if (!file.existsSync()) {
        print('UYARI: $package/${family.key} bulunamadı');
        continue;
      }
      await (FontLoader('packages/$package/${family.key}')
            ..addFont(file.readAsBytes().then((b) => ByteData.view(b.buffer))))
          .load();
    }
  }
}

/// Ekranı çizer ve basar. [page] `true` ise çocuk tam sayfa (iskelet)
/// olarak, değilse kayan bir galeri sütunu içinde çizilir.
Future<void> _shoot(
  WidgetTester tester,
  String name, {
  required bool dark,
  required Widget child,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool page = false,
}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = size * 3;
  addTearDown(tester.view.reset);

  final theme = dark ? AppTheme.dark() : AppTheme.light();
  final body = page
      ? child
      : Scaffold(
          backgroundColor: theme.extension<SahneTokens>()!.bg,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: child,
            ),
          ),
        );
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundaryKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              padding: const EdgeInsets.only(top: 44, bottom: 34),
              viewPadding: const EdgeInsets.only(top: 44, bottom: 34),
            ),
            child: body,
          ),
        ),
      ),
    ),
  );
  final context = _boundaryKey.currentContext!;
  await tester.runAsync(() async {
    for (final path in _images) {
      // ignore: use_build_context_synchronously
      await precacheImage(AssetImage(path), context);
    }
  });
  await tester.pump(const Duration(milliseconds: 600));
  final error = tester.takeException();
  if (error != null) print('HATA $name: $error');
  await tester.runAsync(() async {
    final boundary =
        _boundaryKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_outDir/$name.png');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
  print('✓ $name');
}

// ---------------------------------------------------------------- içerik

Widget _label(String text) => Builder(
  builder: (context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(
      text,
      style: SahneType.captionStrong.copyWith(
        color: SahneTokens.of(context).tx3,
      ),
    ),
  ),
);

void _noop() {}

/// Rafı ve rayı sayfa kenarına taşırır (galerinin 16'lık boşluğunu aşar).
Widget _bleed(Widget child) => LayoutBuilder(
  builder: (context, c) => Transform.translate(
    offset: const Offset(-16, 0),
    child: OverflowBox(
      fit: OverflowBoxFit.deferToChild,
      alignment: Alignment.centerLeft,
      minWidth: c.maxWidth + 32,
      maxWidth: c.maxWidth + 32,
      child: child,
    ),
  ),
);

Widget _buttons() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    _label('Birincil · tam genişlik · ok'),
    const SahneButton.primary(
      label: 'Devam et',
      onPressed: _noop,
      expand: true,
    ),
    _label('Birincil · ikonlu · kendi genişliğinde'),
    const Align(
      alignment: Alignment.centerLeft,
      child: SahneButton.primary(
        label: 'Tekrar oyna',
        icon: AppIcons.arrowRotateLeft,
        arrow: false,
        onPressed: _noop,
      ),
    ),
    _label('İkincil · metin · pasif'),
    const Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SahneButton.secondary(
          label: 'Soru çöz',
          icon: AppIcons.circleQuestion,
          onPressed: _noop,
        ),
        SahneButton.text(label: 'Tümü', onPressed: _noop),
        SahneButton.secondary(label: 'Sonraki', onPressed: null),
      ],
    ),
    _label('Pasif birincil'),
    const SahneButton.primary(label: 'Sonraki', onPressed: null, expand: true),
    _label('İki ikincil yan yana (sararak)'),
    const Row(
      children: [
        Expanded(
          child: SahneButton.secondary(
            label: 'Soru çöz',
            icon: AppIcons.circleQuestion,
            onPressed: _noop,
            expand: true,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: SahneButton.secondary(
            label: 'Kelime kartları',
            icon: AppIcons.layerGroup,
            onPressed: _noop,
            expand: true,
          ),
        ),
      ],
    ),
    _label('Joker dizisi (sonuncusu pasif)'),
    const SahneJokerBar(
      jokers: [
        SahneJokerButton(
          icon: AppIcons.circle,
          label: 'Nîv bi Nîv',
          price: 20,
          onPressed: _noop,
        ),
        SahneJokerButton(
          icon: AppIcons.lightbulb,
          label: 'Alîkariya Bersivê',
          price: 30,
          onPressed: _noop,
        ),
        SahneJokerButton(
          icon: AppIcons.listCheck,
          label: 'Du Bersiv',
          price: 50,
          onPressed: _noop,
        ),
        SahneJokerButton(
          icon: AppIcons.arrowsRotate,
          label: 'Pirsê Biguhere',
          price: 40,
          onPressed: null,
        ),
      ],
    ),
  ],
);

Widget _stageCards() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    _label('Ders'),
    const SahneStageCard.lesson(
      eyebrow: 'Günün dersi',
      title: 'Selamlaşma',
      meta: '5 soru • yaklaşık 3 dakika',
      done: 2,
      total: 5,
      actionLabel: 'Devam et',
      onAction: _noop,
    ),
    _label('Ders · rozetli'),
    const SahneStageCard.lesson(
      tag: SahneBadge(label: 'Sana önerilen'),
      title: 'Selamlaşma',
      meta: '5 soru • yaklaşık 3 dakika',
      done: 2,
      total: 5,
      actionLabel: 'Devam et',
      onAction: _noop,
    ),
    _label('Düello'),
    const SahneStageCard.duel(
      eyebrow: 'Hızlı düello',
      title: 'Seviyene yakın rakip',
      meta: '~2 dakika',
      emblem: SahneVsEmblem(),
      actionLabel: 'Rakip bul',
      onAction: _noop,
    ),
    _label('Mini'),
    const SahneStageCard.mini(
      eyebrow: 'Sahne kartı',
      title: 'Günün dersi',
      meta:
          'Kahraman içerik; gündüzde de gece kalır. Üst kenarda rol renkli '
          'kilim şeridi.',
    ),
  ],
);

Widget _lists() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    _label('Yüzey kartı'),
    SahneSurfaceCard(
      child: Builder(
        builder: (context) {
          final t = SahneTokens.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Wrap(
                spacing: 8,
                children: [
                  SahneStatChip(
                    leading: SahneGlyph(SahneGlyphKind.coin),
                    label: '+30 jeton',
                    gold: true,
                  ),
                  SahneStatChip(
                    leading: SahneGlyph(SahneGlyphKind.bolt),
                    label: '+200 XP',
                    gold: true,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Seviye 1',
                      style: SahneType.bodyStrong.copyWith(color: t.tx),
                    ),
                  ),
                  Text(
                    '200 / 1000 XP',
                    style: SahneType.caption.copyWith(color: t.tx2),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const SahneProgressBar(value: 0.2, tone: SahneProgressTone.gold),
            ],
          );
        },
      ),
    ),
    _label('Liste grubu · standart'),
    const SahneListGroup(
      children: [
        SahneListRow.icon(
          icon: AppIcons.peopleGroup,
          role: SahneRole.race,
          title: 'Oda kur',
          subtitle: 'Arkadaşlarını kodla çağır',
          chevron: true,
          onTap: _noop,
        ),
        SahneListRow.icon(
          icon: AppIcons.calendarDays,
          role: SahneRole.race,
          title: 'Günün Etkinliği',
          subtitle: '10 soru • 20 sn/soru',
          trailing: SahneBadge(label: 'Bugün', tone: SahneBadgeTone.race),
          chevron: true,
          onTap: _noop,
        ),
        SahneListRow.icon(
          icon: AppIcons.layerGroup,
          role: SahneRole.learn,
          title: 'Kelime kartları',
          subtitle: 'Qertên peyvan • 24 kart',
          chevron: true,
          onTap: _noop,
        ),
        SahneListRow.icon(
          icon: AppIcons.shuffle,
          title: 'Sırayla düello',
          subtitle: 'Sırası gelen oynar',
          enabled: false,
          trailing: SahneBadge(label: 'Yakında', tone: SahneBadgeTone.soon),
        ),
      ],
    ),
    _label('Bilgi 52 · küçük resim'),
    SahneListGroup(
      children: [
        SahneListRow.thumb(
          image: _img('cand'),
          title: 'Çay evinde',
          subtitle: 'Li çayxanê',
          trailing: const SahneRowValue.meta('4 dk'),
          chevron: true,
          onTap: _noop,
        ),
        SahneListRow.thumb(
          image: _img('ziman'),
          title: 'Dil',
          trailing: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SahneRowValue('1/1'),
              SizedBox(width: 12),
              SahneStatusBadge.square(correct: true, label: 'Doğru'),
            ],
          ),
        ),
        SahneListRow.thumb(
          image: _img('dirok'),
          title: 'Tarih',
          trailing: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SahneRowValue('0/1'),
              SizedBox(width: 12),
              SahneStatusBadge.square(correct: false, label: 'Yanlış'),
            ],
          ),
        ),
      ],
    ),
    _label('Sıra 56 · Sen'),
    const SahneListGroup(
      children: [
        SahneListRow.rank(
          rank: 4,
          initial: 'A',
          title: 'Azad',
          trailing: SahneRowValue('5980'),
        ),
        SahneListRow.rank(
          rank: 5,
          initial: 'Z',
          title: 'Zelal',
          trailing: SahneRowValue('5410'),
        ),
        SahneListRow.rank(
          rank: 6,
          initial: 'H',
          title: 'Hêvî',
          trailing: SahneRowValue('4870'),
        ),
      ],
    ),
    const SizedBox(height: 12),
    const SahneListRow.me(
      rank: 14,
      title: 'Sen',
      subtitle: 'İlk 10\'a 1.640 puan',
      trailing: SahneRowValue('2310'),
    ),
  ],
);

Widget _jewels() => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    _label('Raf (kenara taşar)'),
    _bleed(
      SizedBox(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SahneJewelTile(
                name: 'Dil',
                otherName: 'Ziman',
                image: _img('ziman'),
                onTap: _noop,
              ),
              const SizedBox(width: 12),
              SahneJewelTile(
                name: 'Kültür',
                otherName: 'Çand',
                image: _img('cand'),
                mastered: true,
                masteredLabel: 'Ustalık',
                onTap: _noop,
              ),
              const SizedBox(width: 12),
              SahneJewelTile(
                name: 'Tarih',
                otherName: 'Dîrok',
                image: _img('dirok'),
                onTap: _noop,
              ),
            ],
          ),
        ),
      ),
    ),
    _label('Çeşitler: çizimli · ustalık · çizimsiz'),
    Wrap(
      spacing: 12,
      runSpacing: 16,
      children: [
        SahneJewelTile(
          name: 'Müzik',
          otherName: 'Muzîk',
          image: _img('muzik'),
          onTap: _noop,
        ),
        SahneJewelTile(
          name: 'Kültür',
          otherName: 'Çand',
          image: _img('cand'),
          mastered: true,
          masteredLabel: 'Ustalık',
          onTap: _noop,
        ),
        const SahneJewelTile(name: 'Sinema', otherName: 'Sînema', onTap: _noop),
        const SahneJewelTile(
          name: 'Teknoloji',
          otherName: 'Teknolojî',
          icon: AppIcons.robot,
          onTap: _noop,
        ),
      ],
    ),
  ],
);

Widget _chips() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    _label('Stat çipleri (jeton dokunulabilir: 44 alan)'),
    const Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SahneStatChip(
          leading: SahneGlyph(SahneGlyphKind.flame),
          label: '3 gün',
          semanticLabel: '3 günlük seri',
        ),
        SahneStatChip(
          leading: SahneGlyph(SahneGlyphKind.coin),
          label: '120',
          semanticLabel: '120 jeton',
          onTap: _noop,
        ),
        SahneStatChip(leading: SahneGlyph(SahneGlyphKind.star), label: '240'),
      ],
    ),
    _label('Seçim rayı (kayar)'),
    _bleed(
      SizedBox(
        child: SahneRail(
          children: [
            for (final (i, l) in const [
              'Günlük',
              'Dilbilgisi',
              'Kültür',
              'Yemek',
              'Seyahat',
            ].indexed)
              SahneRailChip(label: l, selected: i == 0, onTap: _noop),
          ],
        ),
      ),
    ),
    _label('Seçim rayı · sığan çeşit (altın)'),
    SahneRail.fit(
      children: [
        for (final (i, l) in const ['Gün', 'Hafta', 'Ay', 'Arkadaş'].indexed)
          SahneRailChip(
            label: l,
            selected: i == 1,
            role: SahneRole.gold,
            onTap: _noop,
          ),
      ],
    ),
    _label('Rol rozetleri'),
    const Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        SahneBadge(label: 'Bugün', tone: SahneBadgeTone.race),
        SahneBadge(label: 'Sana önerilen'),
        SahneBadge(label: 'En iyi', tone: SahneBadgeTone.gold),
        SahneBadge(label: 'Yakında', tone: SahneBadgeTone.soon),
      ],
    ),
    _label('Durum rozetleri'),
    const Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SahneStatusBadge(correct: true, label: 'Doğru'),
        SahneStatusBadge(correct: false, label: 'Yanlış'),
        SahneStatusBadge.square(correct: true, label: 'Doğru'),
        SahneStatusBadge.square(correct: false, label: 'Yanlış'),
      ],
    ),
  ],
);

const _dias = [
  SahneDiamondState.correct,
  SahneDiamondState.wrong,
  SahneDiamondState.correct,
  SahneDiamondState.pending,
  SahneDiamondState.pending,
  SahneDiamondState.pending,
  SahneDiamondState.pending,
  SahneDiamondState.pending,
  SahneDiamondState.pending,
  SahneDiamondState.pending,
];

Widget _progress() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    const SahneSectionHeader(
      title: 'Konular',
      actionLabel: 'Tümü',
      onAction: _noop,
    ),
    const SahneSectionHeader(title: 'Bu turdan öğrendiklerin'),
    _label('Çubuk'),
    const SahneProgressBar(value: 0.4, trailing: '2/5'),
    const SizedBox(height: 12),
    const SahneProgressBar(
      value: 0.2,
      tone: SahneProgressTone.gold,
      trailing: '200 XP',
    ),
    _label('Elmas dizisi (şimdiki: 4.)'),
    const SahneDiamondRow(
      states: _dias,
      currentIndex: 3,
      semanticLabel: '4/10: 2 doğru, 1 yanlış',
    ),
    _label('Ders elması · sayaç · sayaç ≤ 5 sn · yol düğümleri'),
    const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SahneLessonDiamond(done: 2, total: 5),
        SahneTimerDiamond(
          secondsLeft: 17,
          fraction: 17 / 20,
          semanticLabel: '17 saniye kaldı',
        ),
        SahneTimerDiamond(
          secondsLeft: 4,
          fraction: 4 / 20,
          semanticLabel: '4 saniye kaldı',
        ),
        Row(
          children: [
            SahnePathNode(
              state: SahnePathNodeState.done,
              semanticLabel: 'Bitti',
            ),
            SahnePathNode(
              state: SahnePathNodeState.inProgress,
              semanticLabel: 'Sürüyor',
            ),
            SahnePathNode(
              state: SahnePathNodeState.locked,
              semanticLabel: 'Kilitli',
            ),
          ],
        ),
      ],
    ),
    _label('Ödül glifleri (20 · 32)'),
    Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final k in SahneGlyphKind.values) SahneGlyph(k),
        for (final k in SahneGlyphKind.values) SahneGlyph(k, size: 32),
        const SahneGlyph(SahneGlyphKind.star, size: 32, filled: false),
      ],
    ),
  ],
);

List<Widget> _stats() => const [
  SahneStatChip(leading: SahneGlyph(SahneGlyphKind.flame), label: '3 gün'),
  SahneStatChip(
    leading: SahneGlyph(SahneGlyphKind.coin),
    label: '120',
    onTap: _noop,
  ),
];

Widget _tabPage() => SahneTabPage(
  title: 'Hoş geldin, Oyuncu!',
  subtitle: 'Her gün birkaç soru. Dil güçlenir.',
  stats: _stats(),
  children: [
    const SahneStageCard.lesson(
      eyebrow: 'Günün dersi',
      title: 'Selamlaşma',
      meta: '5 soru • yaklaşık 3 dakika',
      done: 2,
      total: 5,
      actionLabel: 'Devam et',
      onAction: _noop,
    ),
    const SahneSectionHeader(
      title: 'Konular',
      actionLabel: 'Tümü',
      onAction: _noop,
    ),
    _bleed(
      SizedBox(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SahneJewelTile(
                name: 'Dil',
                otherName: 'Ziman',
                image: _img('ziman'),
                onTap: _noop,
              ),
              const SizedBox(width: 12),
              SahneJewelTile(
                name: 'Kültür',
                otherName: 'Çand',
                image: _img('cand'),
                mastered: true,
                onTap: _noop,
              ),
              const SizedBox(width: 12),
              SahneJewelTile(
                name: 'Tarih',
                otherName: 'Dîrok',
                image: _img('dirok'),
                onTap: _noop,
              ),
            ],
          ),
        ),
      ),
    ),
    const SizedBox(height: 24),
    const SahneListGroup(
      children: [
        SahneListRow.icon(
          icon: AppIcons.calendarDays,
          role: SahneRole.race,
          title: 'Günün Etkinliği',
          subtitle: '10 soru • 20 sn/soru',
          trailing: SahneBadge(label: 'Bugün', tone: SahneBadgeTone.race),
          chevron: true,
          onTap: _noop,
        ),
      ],
    ),
  ],
);

Widget _pushedPage() => SahnePushedPage(
  title: 'Kurmancî öğren',
  subtitle: 'Ders ders, konu konu ilerle',
  onBack: _noop,
  slivers: [
    SliverToBoxAdapter(
      child: SahneRail(
        children: [
          for (final (i, l) in const [
            'Günlük',
            'Dilbilgisi',
            'Kültür',
            'Yemek',
            'Seyahat',
          ].indexed)
            SahneRailChip(label: l, selected: i == 0, onTap: _noop),
        ],
      ),
    ),
    SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      sliver: SliverList.list(
        children: [
          const Row(
            children: [
              SahnePathNode(
                state: SahnePathNodeState.inProgress,
                semanticLabel: 'Sürüyor',
              ),
              SizedBox(width: 8),
              Expanded(
                child: SahneStageCard.lesson(
                  tag: SahneBadge(label: 'Sana önerilen'),
                  title: 'Selamlaşma',
                  meta: '5 soru • yaklaşık 3 dakika',
                  done: 2,
                  total: 5,
                  actionLabel: 'Devam et',
                  onAction: _noop,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SahnePathNode(
                state: SahnePathNodeState.locked,
                semanticLabel: 'Kilitli',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SahneSurfaceCard(
                  child: Builder(
                    builder: (context) {
                      final t = SahneTokens.of(context);
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tanışma',
                                  style: SahneType.bodyStrong.copyWith(
                                    color: t.tx2,
                                  ),
                                ),
                                Text(
                                  'Selamlaşma bitince açılır',
                                  style: SahneType.caption.copyWith(
                                    color: t.tx2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(AppIcons.lock, size: 20, color: t.tx3),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(
                child: SahneButton.secondary(
                  label: 'Soru çöz',
                  icon: AppIcons.circleQuestion,
                  onPressed: _noop,
                  expand: true,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: SahneButton.secondary(
                  label: 'Kelime kartları',
                  icon: AppIcons.layerGroup,
                  onPressed: _noop,
                  expand: true,
                ),
              ),
            ],
          ),
          const SahneSectionHeader(title: 'Günlük hikâyeler'),
          SahneListGroup(
            children: [
              SahneListRow.thumb(
                image: _img('cand'),
                title: 'Çay evinde',
                subtitle: 'Li çayxanê',
                trailing: const SahneRowValue.meta('4 dk'),
                chevron: true,
                onTap: _noop,
              ),
              SahneListRow.thumb(
                image: _img('edebiyat'),
                title: 'Kendini tanıtma',
                subtitle: 'Xwe nasandin',
                trailing: const SahneRowValue.meta('3 dk'),
                chevron: true,
                onTap: _noop,
              ),
            ],
          ),
        ],
      ),
    ),
  ],
);

Widget _question({
  required String question,
  required List<String> answers,
  required bool hot,
  required bool jokers,
}) => SahneStageScaffold(
  onClose: _noop,
  backdrop: _img('ziman'),
  center: SahneTimerDiamond(
    secondsLeft: hot ? 4 : 17,
    fraction: (hot ? 4 : 17) / 20,
    semanticLabel: '${hot ? 4 : 17} saniye kaldı',
  ),
  score: const SahneStatChip(
    leading: SahneGlyph(SahneGlyphKind.star),
    label: '240',
    semanticLabel: '240 puan',
  ),
  progress: SahneDiamondRow(
    states: _dias,
    currentIndex: hot ? 3 : 2,
    semanticLabel: '3/10',
  ),
  body: Builder(
    builder: (context) {
      final t = SahneTokens.of(context);
      return SahneStageBody(
        children: [
          Text(
            'DİL  •  SORU 3/10',
            style: SahneType.eyebrow.copyWith(color: t.tx),
          ),
          const SizedBox(height: 8),
          Text(question, style: SahneType.title.copyWith(color: t.tx)),
          const SizedBox(height: 16),
          for (final (i, a) in answers.indexed) ...[
            DecoratedBox(
              decoration: ShapeDecoration(color: t.s2, shape: SahneShape.m),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: ShapeDecoration(
                        color: t.s3,
                        shape: SahneShape.m,
                      ),
                      child: SizedBox.square(
                        dimension: 36,
                        child: Center(
                          child: Text(
                            'ABCD'[i],
                            style: SahneType.button.copyWith(color: t.tx),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        a,
                        style: SahneType.bodyStrong.copyWith(color: t.tx),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      );
    },
  ),
  dock: jokers
      ? const SahneJokerBar(
          jokers: [
            SahneJokerButton(
              icon: AppIcons.circle,
              label: 'Nîv bi Nîv',
              price: 20,
              onPressed: _noop,
            ),
            SahneJokerButton(
              icon: AppIcons.lightbulb,
              label: 'Alîkarî',
              price: 30,
              onPressed: _noop,
            ),
            SahneJokerButton(
              icon: AppIcons.listCheck,
              label: 'Du Bersiv',
              price: 50,
              onPressed: _noop,
            ),
            SahneJokerButton(
              icon: AppIcons.arrowsRotate,
              label: 'Biguhere',
              price: 40,
              onPressed: _noop,
            ),
          ],
        )
      : const SahneButton.primary(
          label: 'Sonraki',
          onPressed: _noop,
          expand: true,
        ),
);

Widget _bigText() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    const SahneSectionHeader(
      title: 'Arkadaşlarınla',
      actionLabel: 'Tümü',
      onAction: _noop,
    ),
    const SahneButton.primary(
      label: 'Devam et',
      onPressed: _noop,
      expand: true,
    ),
    const SizedBox(height: 12),
    const SahneStageCard.lesson(
      eyebrow: 'Dersê rojane',
      title: 'Silavdayîn',
      meta: '5 pirs • nêzîkî 3 deqe',
      done: 2,
      total: 5,
      actionLabel: 'Bidomîne',
      onAction: _noop,
    ),
    const SizedBox(height: 12),
    const SahneListGroup(
      children: [
        SahneListRow.icon(
          icon: AppIcons.calendarDays,
          role: SahneRole.race,
          title: 'Çalakiya Rojê',
          subtitle: '10 pirs • 20 çirke/pirs',
          trailing: SahneBadge(label: 'Îro', tone: SahneBadgeTone.race),
          chevron: true,
          onTap: _noop,
        ),
      ],
    ),
    const SizedBox(height: 12),
    const Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        SahneStatChip(
          leading: SahneGlyph(SahneGlyphKind.flame),
          label: '3 roj',
        ),
        SahneBadge(label: 'Sana önerilen'),
        SahneStatusBadge(correct: false, label: 'Şaş'),
      ],
    ),
    const SizedBox(height: 12),
    SahneRail.fit(
      children: [
        for (final (i, l) in const ['Roj', 'Hefte', 'Meh', 'Heval'].indexed)
          SahneRailChip(
            label: l,
            selected: i == 1,
            role: SahneRole.gold,
            onTap: _noop,
          ),
      ],
    ),
    const SizedBox(height: 12),
    const SahneJokerBar(
      jokers: [
        SahneJokerButton(
          icon: AppIcons.circle,
          label: 'Nîv bi Nîv',
          price: 20,
          onPressed: _noop,
        ),
        SahneJokerButton(
          icon: AppIcons.lightbulb,
          label: 'Alîkarî',
          price: 30,
          onPressed: _noop,
        ),
        SahneJokerButton(
          icon: AppIcons.listCheck,
          label: 'Du Bersiv',
          price: 50,
          onPressed: _noop,
        ),
        SahneJokerButton(
          icon: AppIcons.arrowsRotate,
          label: 'Biguhere',
          price: 40,
          onPressed: _noop,
        ),
      ],
    ),
  ],
);

void main() {
  setUpAll(_loadFonts);

  for (final dark in [true, false]) {
    final theme = dark ? 'gece' : 'gunduz';
    testWidgets('$theme 01 düğmeler', (t) async {
      await _shoot(t, '${theme}_01_dugmeler', dark: dark, child: _buttons());
    });
    testWidgets('$theme 02 sahne kartları', (t) async {
      await _shoot(
        t,
        '${theme}_02_sahne_kartlari',
        dark: dark,
        size: const Size(390, 1040),
        child: _stageCards(),
      );
    });
    testWidgets('$theme 03 yüzey ve liste', (t) async {
      await _shoot(
        t,
        '${theme}_03_yuzey_liste',
        dark: dark,
        size: const Size(390, 1240),
        child: _lists(),
      );
    });
    testWidgets('$theme 04 mücevher karo', (t) async {
      await _shoot(t, '${theme}_04_mucevher', dark: dark, child: _jewels());
    });
    testWidgets('$theme 05 çip ve rozet', (t) async {
      await _shoot(t, '${theme}_05_cip_rozet', dark: dark, child: _chips());
    });
    testWidgets('$theme 06 başlık, ilerleme, glif', (t) async {
      await _shoot(
        t,
        '${theme}_06_ilerleme_glif',
        dark: dark,
        child: _progress(),
      );
    });
    testWidgets('$theme 07 A sekme sayfası', (t) async {
      await _shoot(
        t,
        '${theme}_07_A_sekme',
        dark: dark,
        page: true,
        child: _tabPage(),
      );
    });
    testWidgets('$theme 08 B açılan sayfa', (t) async {
      await _shoot(
        t,
        '${theme}_08_B_acilan',
        dark: dark,
        page: true,
        child: _pushedPage(),
      );
    });
    testWidgets('$theme 09 C oyun sahnesi', (t) async {
      await _shoot(
        t,
        '${theme}_09_C_sahne',
        dark: dark,
        page: true,
        child: _question(
          question:
              'Kurmancî yazım kurallarına göre, et ve ekmek kesmeye yarayan '
              'alet ("bıçak") nasıl yazılır?',
          answers: const ['ker', 'kêr', 'kir', 'kar'],
          hot: false,
          jokers: false,
        ),
      );
    });
    testWidgets('$theme 10 C joker, son 4 sn, 360', (t) async {
      await _shoot(
        t,
        '${theme}_10_C_joker_360',
        dark: dark,
        page: true,
        size: const Size(360, 740),
        child: _question(
          question: 'Kîjan hevok qaîdeya ergatîfê rast nîşan dide?',
          answers: const [
            'Min çûm bajêr, lê ez li wir hevalê xwe dît',
            'Ez çûm bajêr, lê ez li wir hevalê xwe dît',
            'Min çûm bajêr, lê min li wir hevalê xwe dîtim',
            'Ez çûm bajêr, lê min li wir hevalê xwe dît',
          ],
          hot: true,
          jokers: true,
        ),
      );
    });
    testWidgets('$theme 11 büyük yazı 320 @2.0', (t) async {
      await _shoot(
        t,
        '${theme}_11_buyuk_yazi_320',
        dark: dark,
        size: const Size(320, 1400),
        textScale: 2,
        child: _bigText(),
      );
    });
  }
}
