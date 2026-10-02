import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../config/subcategory_config.dart';
import '../data/level_progress_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../utils/app_route.dart';
import '../widgets/category_band.dart';
import '../widgets/sahne/sahne.dart';
import 'level_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

class SubcategoryScreen extends StatefulWidget {
  const SubcategoryScreen({
    required this.repository,
    required this.category,
    super.key,
  });

  final ZanKurdRepository repository;
  final String category;

  @override
  State<SubcategoryScreen> createState() => _SubcategoryScreenState();
}

class _SubcategoryScreenState extends State<SubcategoryScreen> {
  ZanKurdRepository get repository => widget.repository;
  String get category => widget.category;

  /// Alt kategori kimliği → oynanmış seviye sayısı (seviye yolunun kendi
  /// deposundan, [LevelScreen] ile aynı kaynak).
  Map<String, int> _played = const {};

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final store = await LevelProgressStore.load();
    if (!mounted) return;
    final total = repository.levelsForCategory(category).length;
    final ids = [
      ...?SubcategoryConfig.subcategories[category]?.map((s) => s.id),
      'gisti',
    ];
    setState(() {
      _played = {
        for (final id in ids)
          id: [
            for (var n = 1; n <= total; n++)
              if (store.isPlayed(category, id, n)) n,
          ].length,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    // Ekranın gördüğü havuz, seviye yükleyicisinin (`loadLevelQuestions`)
    // kullandığı AYNI havuz olmalı — yoksa ekran bir kart gösterir, seviye
    // yükleyici o alt kategoride hiç eşleşen soru bulamaz. `playableQuestions`
    // zaten bu ortak nokta: `MockZanKurdRepository.loadLevelQuestions` da
    // `SupabaseZanKurdRepository` da (kendi `_offline`ı üzerinden) seviye
    // sorularını hep bu getter'dan süzer (2026-09-28).
    final rawList = SubcategoryConfig.visibleFor(
      category,
      repository.playableQuestions,
    );
    final list = rawList.isNotEmpty
        ? rawList
        : [
            SubcategoryInfo(
              id: 'gisti',
              nameKu: Tr.of(K.allQuestionsSubcategory, AppLanguage.ku),
              nameTr: Tr.of(K.allQuestionsSubcategory, AppLanguage.tr),
              // Kimlik ('Paradigma') değil görünen ad yazılır: 2026-09-30'da
              // kategori "Bilim ve Düşünce" oldu, bu satır hâlâ eski adı
              // gösteriyordu.
              descriptionKu:
                  'Têkelpêkel pirsên ${CategoryNames.localized(category, true)}',
              descriptionTr:
                  '${CategoryNames.localized(category, false)} kategorisindeki tüm sorular',
            ),
          ];

    // Konu akışının ortak bantlı başlığı ([CategoryBandScaffold]): kategori
    // tonu + kilim deseni, seviye ekranıyla AYNI bileşen.
    return CategoryBandScaffold(
      category: category,
      title: CategoryNames.localized(category, ku),
      subtitle: Tr.forKu(K.birAltAlanSecerek, ku),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          SahneSpace.page,
          SahneSpace.x4,
          SahneSpace.page,
          SahneSpace.x6,
        ),
        children: [
          SahneListGroup(
            children: [
              for (final sub in list) _subcategoryRow(context, sub, ku),
            ],
          ),
        ],
      ),
    );
  }

  /// Alt kategori satırı: Zimrût tonlu ikon karosu + ad + açıklama; sağda
  /// ilerleme ("2/5", yalnız oynanmış seviye varsa) ve chevron.
  ///
  /// 2026-09-29 doğallık (K7): sağda her satırda aynı "5 seviye" rozeti
  /// vardı. Aynı sayı her satırda tekrarlanınca bilgi değil şablon oluyordu
  /// (listenin altındaki "1 → 5" kartı bunu zaten söyler). Rozet kalktı;
  /// yerine yalnız o alt kategorideki gerçek ilerleme durur. Hiç
  /// oynanmamışsa sıfır sayaç gösterilmez (K6).
  Widget _subcategoryRow(BuildContext context, SubcategoryInfo sub, bool ku) {
    final played = _played[sub.id] ?? 0;
    final total = repository.levelsForCategory(category).length;
    // Satır ikonu konunun KENDİ renginde (bkz. [CategoryIconTile]): eskiden
    // her konuda aynı Zimrût karo vardı, başlık bandı mor iken satırlar
    // yeşildi.
    return SahneListRow.leading(
      key: ValueKey('subcategory-card-${sub.id}'),
      leading: CategoryIconTile(
        category: category,
        icon: _iconForSubcategory(sub.id),
      ),
      title: ku ? sub.nameKu : sub.nameTr,
      subtitle: ku ? sub.descriptionKu : sub.descriptionTr,
      trailing: played > 0 && total > 0
          ? SahneRowValue.meta('$played/$total')
          : null,
      chevron: true,
      onTap: () {
        Navigator.of(context)
            .push(
              AppRoute.to(
                LevelScreen(
                  repository: repository,
                  category: category,
                  subCategory: sub.id,
                ),
              ),
            )
            // Seviye yolundan dönünce ilerleme sayısı tazelenir.
            .then((_) => _loadProgress());
      },
    );
  }
}

// 2026-07-22 canlı UX denetimi: alt kategori ikon eşleştirmesi
//
// 2026-09-30 simülatör: Sînema'da "Fîlm û Derhêner" ile "Belgefîlm û
// Festîval" (ve "Yılmaz Güney") eşlemesiz kalıp ikisi de yer imi ikonunu
// alıyordu; tanımsız her alt konu sessizce yer imine düşüyordu. Artık her
// alt konu kimliğinin kendi ikonu var ve aynı kategori altında hiçbir ikon
// iki kez kullanılmaz. Yeni bir alt konu eklenirse buraya da eklenmeli
// (bekçi: subcategory_icons_test.dart); yer imi yalnız 'gisti' gibi
// tanımsız kimliklerin yedeğidir.
IconData _iconForSubcategory(String id) {
  return switch (id) {
    // ── Ziman ──
    'reziman' => AppIcons.language,
    'peyvnasi' => AppIcons.font,
    'rastnivisin' => AppIcons.pen,
    // ── Çand ──
    'folklor' => AppIcons.masksTheater,
    'cejn' => AppIcons.champagneGlasses,
    'dastangotin' => AppIcons.bookOpenReader,
    'tistonek' => AppIcons.lightbulb,
    // ── Dîrok ──
    'diroka_kevn' => AppIcons.hourglass,
    'diroka_nujen' => AppIcons.calendarDays,
    'sexsiyet' => AppIcons.idBadge,
    // ── Edebiyat ──
    'helbest' => AppIcons.quoteLeft,
    'klasik' => AppIcons.book,
    'roman' => AppIcons.bookOpen,
    // ── Coğrafya ──
    'ciya_cem' => AppIcons.mountain,
    'bajar_ci' => AppIcons.house,
    'sinor_duma' => AppIcons.locationDot,
    // ── Muzîk ──
    'dengbeji' => AppIcons.microphone,
    'nujen' => AppIcons.circlePlay,
    'amur' => AppIcons.music,
    // ── Siyaset ──
    'diroka_siyasi' => AppIcons.buildingColumns,
    'siyaseta_nujen' => AppIcons.squareCheck,
    'tevger' => AppIcons.flag,
    // ── Paradigma (Bilim ve Düşünce) ──
    'civak_maf' => AppIcons.scaleBalanced,
    'raman_felsefe' => AppIcons.lightbulb,
    'zanist_jiyan' => AppIcons.leaf,
    // ── Teknolojî ──
    'bingehên_teknolojiyê' => AppIcons.gear,
    'programkirin' => AppIcons.robot,
    'dijital_internet' => AppIcons.globe,
    // ── Sînema ──
    'filmen_kurdi' => AppIcons.clapperboard,
    'yilmaz_guney' => AppIcons.star,
    'festival_belgefilm' => AppIcons.camera,
    // ── Cîhan ──
    'sinema_cihan' => AppIcons.clapperboard,
    'erdnigari_cihan' => AppIcons.globe,
    'dirok_gisti' => AppIcons.graduationCap,
    _ => AppIcons.bookmark,
  };
}

/// Yalnız bekçi testi için: eşleme özel kalır, test ona buradan bakar.
@visibleForTesting
IconData subcategoryIconForTest(String id) => _iconForSubcategory(id);
