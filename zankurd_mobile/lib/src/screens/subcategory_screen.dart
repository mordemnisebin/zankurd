import 'dart:math' as math;

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
    final slots = _kilimSlots(
      MediaQuery.sizeOf(context).width,
      MediaQuery.textScalerOf(context).scale(10) / 10,
    );
    PreferredSizeWidget bar(BuildContext barContext) => zkAppBar(
      barContext,
      backgroundColor: Colors.transparent,
      // Çubuk gece başlığının üstünde: saat ve pil açık renkte olmalı
      // (bkz. `AppTheme.overlayOnDarkHeader`).
      systemOverlayStyle: AppTheme.overlayOnDarkHeader,
      title: Text(CategoryNames.localized(category, ku)),
      // 2026-09-30 simülatör: büyük yazıda (%235) alt satır iki satırda
      // "…" ile kesiliyordu ("Barekî hilbijêre û dest bi lîsti…"); üç satıra
      // iner, çubuk ve bant yüksekliği aynı üç satırla ölçülür.
      subtitle: Text(
        Tr.forKu(K.birAltAlanSecerek, ku),
        maxLines: _subtitleMaxLines(
          MediaQuery.textScalerOf(barContext).scale(10) / 10,
        ),
      ),
      // Kilim deseni sağ kenardadır: çubuk onun genişliği kadar yer bırakır
      // ([_kilimSlots] x 48 boş yuva), metin desenin altına girmez. Alt satır
      // sarılır (tek satırda kesilirse cümle yarım kalırdı). Motifsiz konuda
      // yuva açılmaz.
      actions: CategoryVisuals.mark(category) == null
          ? null
          : [
              for (var i = 0; i < slots; i++)
                const SizedBox(width: sahneTapTarget),
            ],
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
            _CategoryHeader(
              category: category,
              slots: slots,
              // Durum çubuğu payı Scaffold'un DIŞINDAN okunur: gövdenin
              // içinde `padding.top` çubuğun yüksekliğini de içerir.
              topInset: MediaQuery.paddingOf(context).top,
              barHeight: bar(context).preferredSize.height,
            ),
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

/// Kilim desenine ayrılan yuva sayısı: 360 px ve üstünde üç (desen 132 px'e
/// kadar), daha dar ekranda iki (84 px) — 320 px'te başlık ve alt satır
/// yeterli genişlik bulur. Büyük yazıda (x1,3 ve üstü) bir yuva eksilir: alt
/// satır en çok iki satırdır ve dar metin alanında ("Bir alt alan seçe...")
/// yarım kalırdı; desen o zaman daha az sütun gösterir.
///
/// 2026-09-30 simülatör: %200'ü aşan yazıda (iPhone 17e en büyük boyut,
/// %235) bir yuva daha eksilir (en az bir kalır); metin alanı genişler ve
/// alt satır (bkz. [_subtitleMaxLines]) kesilmeden yerleşir.
int _kilimSlots(double width, double textScale) {
  final base = width >= 360 ? 3 : 2;
  if (textScale > 2) return math.max(1, base - 2);
  return textScale > 1.3 ? base - 1 : base;
}

/// Alt satır en çok kaç satıra iner: %200'e kadar 3, üstünde 4. Ölçüm ve
/// çizim [zkAppBar] içinde aynı sayıyla yapılır.
int _subtitleMaxLines(double textScale) => textScale > 2 ? 4 : 3;

/// [slots] yuvanın desene bıraktığı genişlik: yuvalar eksi 12 px nefes.
double _kilimReserved(int slots) => slots * sahneTapTarget - SahneSpace.x3;

/// Kategori başlığı: kategorinin düz tonu ([SahneCategoryTone.ground]) ve
/// sağ kenardan taşan K1 kilim deseni ([SahneKilimBandPainter]).
///
/// 2026-09-30 kimlik: başlık eskiden kategorinin fotoğraf benzeri çiziminin
/// (`CategoryVisuals.ownImagePath`) üstüne gece perdesi çekilerek kuruluyordu;
/// çizimi olmayan kategoriler (Ziman, Sînema) yalnız düz bir renk çubuğu
/// alıyordu, yani yedi konudan ikisi başka bir dilde konuşuyordu. Kullanıcı
/// K1'i seçti: yedi konunun hepsi (çizimi olanlar dahil) kendi dokuma
/// motifini taşır; çizim bu ekrandan çekildi. Motif her temada aynı çizilir
/// (bant kimlik taşır, gece değerleriyle): çubuktaki gece metni tonun koyu
/// zemininde okunur, desen bandın sağındadır ve başlığın altına girmez (bkz.
/// `SahneKilimBandPainter.reservedWidth`). Alt kenardaki kilim göz şeridi
/// 2026-09-29'da kalktı (K4: şerit yalnız onboarding, zafer ve girişte).
///
/// 2026-09-30 bant: bant eskiden çubuğun altına 88 px'lik boş bir bant
/// ekliyordu (uzun, alt yarısı boş, desen köşede küçük bir blok). Şimdi
/// yükseklik içeriğe oturur: durum çubuğu payı + çubuk (geri düğmesi, ad,
/// en çok iki satır alt yazı; büyük yazıda çubuğun kendisi uzar) + alt
/// kenarda [_bottomGap]; sonuç 9'un katına yükseltilir (alt kenarda 16-24
/// px boşluk kalır) ki desenin tam sayı hücresi bandın tepesinden dibine
/// yetsin. Motifi olmayan konu (Siyaset, Paradigma, Teknolojî) aynı
/// yükseklikte düz tonda kalır.
class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.category,
    required this.slots,
    required this.topInset,
    required this.barHeight,
  });

  final String category;

  /// Desene ayrılan 48'lik yuva sayısı ([_kilimSlots]).
  final int slots;

  /// Durum çubuğu payı: düz tonla boyanır, desen bu payın ALTINDA başlar.
  /// 2026-09-30 simülatör: desen durum çubuğunun arkasına uzanınca açık
  /// motif hücreleri (Sînema lilası, Çand mercanı) saat, sinyal ve pil
  /// simgelerini okunmaz yapıyordu; test koşucusu payı 0 aldığı için tur
  /// karelerinde görünmüyordu.
  final double topInset;

  /// Çubuğun (durum çubuğu payı hariç) yüksekliği: metne göre ölçülür.
  final double barHeight;

  /// Çubuğun altında bırakılan boşluk (çubuğun kendi 8 px iç payına ek).
  static const double _bottomGap = SahneSpace.x2;

  /// Desenli kısmın yüksekliği: çubuk + boşluk, 9'un katına yükseltilmiş
  /// (durum çubuğu payı hariç; o pay desensiz düz tondur).
  static double heightFor(double barHeight) =>
      SahneKilimBandPainter.snapHeight(barHeight + _bottomGap);

  @override
  Widget build(BuildContext context) {
    final height = heightFor(barHeight);
    final mark = CategoryVisuals.mark(category);
    final tone = CategoryVisuals.tone(category);
    return ColoredBox(
      color: tone.ground,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: SizedBox(
          height: height,
          child: mark == null
              ? null
              : ExcludeSemantics(
                  child: CustomPaint(
                    key: const ValueKey('subcategory-kilim-band'),
                    painter: SahneKilimBandPainter(
                      mark: mark,
                      tone: tone,
                      reservedWidth: _kilimReserved(slots),
                    ),
                  ),
                ),
        ),
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
