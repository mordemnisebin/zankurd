import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../config/category_visuals.dart';
import '../config/subcategory_config.dart';
import '../data/level_progress_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../widgets/app_panel.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/zk_back_button.dart';
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
              descriptionKu: 'Têkelpêkel pirsên $category',
              descriptionTr: '$category kategorisindeki tüm sorular',
            ),
          ];
    final t = SahneTokens.of(context);

    // 2026-09-29 Şahnê: B iskeleti + kategori başlığı. Kategori çizimi bu
    // ekranda başlığın zeminidir (maket kuralı: çizim yalnız karo, kategori
    // başlığı ve soru sahnesi zemininde). Zemin her temada gecedir; çubuk
    // (geri + ad + alt satır) onun üstünde gece metinleriyle yazılır ve
    // durum çubuğu açık ikon ister. Eski palet dışı kategori degradesi,
    // parlama daireleri ve bulanık gölge kalktı.
    //
    // 2026-09-29 doğallık (K1): çubuk gece TEMASIYLA kurulur. Eskiden gece
    // rengi yalnız metnin biçemine yazılıyordu; `zkAppBar` başlığı temanın
    // metin rengiyle yeniden çizdiği için gündüzde ad çizimin üstünde
    // lacivert kalıyor, geri plakası beyaz bir kutu oluyordu (okunmuyordu).
    PreferredSizeWidget bar(BuildContext barContext) => zkAppBar(
      barContext,
      backgroundColor: Colors.transparent,
      // Çubuk gece başlığının üstünde: saat ve pil açık renkte olmalı
      // (bkz. `AppTheme.overlayOnDarkHeader`).
      systemOverlayStyle: AppTheme.overlayOnDarkHeader,
      title: Text(CategoryNames.localized(category, ku)),
      subtitle: Text(Tr.forKu(K.birAltAlanSecerek, ku)),
    );
    return Scaffold(
      backgroundColor: t.bg,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: bar(context).preferredSize,
        child: Theme(
          data: AppTheme.stage,
          child: Builder(builder: bar),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CategoryHeader(category: category),
            Expanded(
              child: ListView(
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
                  const SizedBox(height: SahneSpace.cardGap),
                  _SubcategoryProgressHint(isKu: ku),
                ],
              ),
            ),
          ],
        ),
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
    return SahneListRow.icon(
      key: ValueKey('subcategory-card-${sub.id}'),
      icon: _iconForSubcategory(sub.id),
      role: SahneRole.learn,
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

/// Listenin sonundaki bilgi kartı: "Kolaydan zora doğru ilerle" ve 1 → 5
/// basamakları.
class _SubcategoryProgressHint extends StatelessWidget {
  const _SubcategoryProgressHint({required this.isKu});

  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    // Bu kart yalnız BİLGİLENDİRİR: hangi alt kategoriye ait olduğu
    // belirsiz olduğu için tıklanınca gidebileceği anlamlı tek bir hedef
    // yok (seviye seçimi her zaman bir alt kategoriye bağlı). Eskiden sağ
    // ucunda `chevronRight` ikonu vardı; listedeki her tıklanabilir satır
    // aynı ikonla bittiği için bu kart da dokunulabilir görünüyordu ama
    // `onTap` yoktu — dokunan kullanıcı hiçbir tepki almıyordu (2026-08-14
    // denetimi). Kart InkWell'siz ve chevron'suz kalır.
    return AppPanel(
      child: Row(
        children: [
          DecoratedBox(
            decoration: ShapeDecoration(
              color: t.learnTint,
              shape: SahneShape.m,
            ),
            child: SizedBox.square(
              dimension: 44,
              child: Icon(AppIcons.stairs, color: t.learnTx, size: 24),
            ),
          ),
          const SizedBox(width: SahneSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Tr.forKu(K.kolaydanZoraDogruIlerle, isKu),
                  style: SahneType.bodyStrong.copyWith(color: t.tx),
                ),
                const SizedBox(height: SahneSpace.x1),
                Wrap(
                  spacing: SahneSpace.x1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (var step = 1; step <= 5; step++) ...[
                      Text(
                        '$step',
                        style: SahneType.captionStrong.copyWith(
                          color: t.learnTx,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (step < 5)
                        Icon(AppIcons.arrowRight, size: 12, color: t.tx3),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kategori başlığı: kategorinin KENDİ çizimi, üstünde gece perdesi;
/// çizimi yoksa kategorinin düz tonu.
///
/// 2026-09-29 doğallık (K1): çizim yalnız kendi çizimi olan kategoride
/// (`CategoryVisuals.ownImagePath`). Ziman, Siyaset, Paradigma ve ödünç
/// görselli kategoriler çizim bandı almaz: başlık yalnız çubuk boyundadır
/// ve kategorinin düz tonunu taşır (boş bir renk bandı süs olurdu). Perde
/// her iki temada gecedir ve bandın dibinde de kalır (%45): çizim gündüzde
/// tam parlaklığıyla açık kalıyor, başlığın altında bağıran bir afiş
/// oluyordu. Alt kenardaki kilim göz şeridi kalktı (K4: şerit yalnız
/// onboarding, zafer ve girişte).
class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category});

  final String category;

  /// Çubuğun altında çizimin açık kaldığı bant.
  static const double _band = 88;

  @override
  Widget build(BuildContext context) {
    const night = SahneTokens.night;
    final topInset = MediaQuery.paddingOf(context).top;
    final image = CategoryVisuals.ownImagePath(category);
    final tone = CategoryVisuals.tone(category);
    if (image == null) {
      return SizedBox(
        height: topInset + 64,
        child: ColoredBox(color: tone.ground),
      );
    }
    return SizedBox(
      height: topInset + 64 + _band,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: night.bg),
          ExcludeSemantics(
            child: Image.asset(
              image,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.2),
              errorBuilder: (_, _, _) => ColoredBox(color: tone.ground),
            ),
          ),
          // Gece perdesi: çubuk bölgesinde %80 — beyaz çizimin üstünde bile
          // gece metni AA geçer —, bandın dibinde %45.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  night.bg.withValues(alpha: 0.8),
                  night.bg.withValues(alpha: 0.8),
                  night.bg.withValues(alpha: 0.45),
                ],
                stops: [0, (topInset + 64) / (topInset + 64 + _band), 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 2026-07-22 canlı UX denetimi: alt kategori ikon eşleştirmesi
IconData _iconForSubcategory(String id) {
  return switch (id) {
    // ── Ziman ──
    'reziman' ||
    'diroka_kevn' ||
    'helbest' ||
    'dastangotin' ||
    'diroka_siyasi' ||
    'demokratik' => AppIcons.book,
    // ── Çand & Edebiyat ──
    'peyvnasi' ||
    'folklor' ||
    'diroka_nujen' ||
    'klasik' ||
    'bajar_ci' ||
    'nujen' ||
    'siyaseta_nujen' ||
    'ekoloji' => AppIcons.bookOpen,
    // ── Yazım & Sanat ──
    'rastnivisin' || 'sexsiyet' || 'roman' => AppIcons.pen,
    // ── Sınırlar & Coğrafi Yapı ──
    'sinor_duma' => AppIcons.locationDot,
    // ── Müzik Aletleri ──
    'amur' => AppIcons.music,
    // ── Hareket & Mücadele ──
    'tevger' => AppIcons.flag,
    // ── Jineolojî ──
    'jineoloji' => AppIcons.venus,
    // ── Kutlama & Gelenek ──
    'cejn' => AppIcons.champagneGlasses,
    // ── Bilmece & Zekâ ──
    'tistonek' => AppIcons.lightbulb,
    // ── Coğrafya ──
    'ciya_cem' => AppIcons.mountain,
    // ── Müzik ──
    'dengbeji' => AppIcons.microphone,
    // ── Teknoloji ──
    'bingehên_teknolojiyê' => AppIcons.gear,
    'programkirin' => AppIcons.robot,
    'dijital_internet' => AppIcons.globe,
    _ => AppIcons.bookmark,
  };
}
