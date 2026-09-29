import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/avatar_presets.dart';
import '../data/achievement_store.dart';
import '../data/mastery_store.dart';
import '../data/zankurd_repository.dart';
import '../game/avatar_frames.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/avatar_identity.dart';
import '../models/mastery_level.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_state.dart';
import '../widgets/branded_loader.dart';
import '../widgets/player_avatar.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/zk_back_button.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Avatar/çerçeve/unvan düzenleyici. Kaydet ile repository'ye yazar ve
/// pop(true) döner; çağıran ekran görünümünü tazeler.
class AvatarEditorScreen extends StatefulWidget {
  const AvatarEditorScreen({
    required this.repository,
    this.imagePicker,
    super.key,
  });

  final ZanKurdRepository repository;

  /// Testlerde sahte seçici enjekte etmek için.
  final ImagePicker? imagePicker;

  @override
  State<AvatarEditorScreen> createState() => _AvatarEditorScreenState();
}

class _AvatarEditorScreenState extends State<AvatarEditorScreen> {
  static const int _maxPhotoBytes = 2 * 1024 * 1024;

  AvatarIdentity _identity = const AvatarIdentity();
  Set<AvatarFrame> _unlocked = const {};
  List<String> _earnedTitles = const [];
  String _displayName = '';
  bool _loading = true;
  bool _loadFailed = false;
  bool _saving = false;
  bool _uploadingPhoto = false;

  /// Ekran açıldığında kayıtlı bir fotoğraf var mıydı?
  ///
  /// Depodan silme yalnız GERÇEKTEN bir fotoğraf kaldırıldığında yapılır;
  /// hiç fotoğrafı olmayan kullanıcı yalnız rengini değiştirip kaydettiğinde
  /// gereksiz bir silme çağrısı gitmesin.
  bool _hadPhotoOnOpen = false;

  /// Bu OTURUMDA (ekran açıkken) yeni bir fotoğraf yüklendi mi?
  ///
  /// `uploadAvatarPhoto` her zaman aynı sabit yola (`{user_id}/avatar.ext`)
  /// yazar, yani bu oturumda kaç kez seçilirse seçilsin depoda tek bir
  /// nesne durur. Ama `_save()`in silme koşulu yalnız `_hadPhotoOnOpen`e
  /// bakıyordu — kullanıcı ekranı hiç fotoğrafsız açıp YENİ bir fotoğraf
  /// yükleyip sonra vazgeçtiğinde (kaldırıp kaydetti YA DA hiç kaydetmeden
  /// geri gitti) bu bayrak hep `false` kalıyordu, silme hiç tetiklenmiyor
  /// ve az önce yüklenen nesne herkese açık kovada yetim kalıyordu
  /// (2026-08-14 denetimi).
  bool _uploadedNewPhotoThisSession = false;

  /// `_save()` başarıyla tamamlandı mı? `dispose()`teki yetim temizliği
  /// yalnız kullanıcı GERÇEKTEN kaydetmeden ekrandan ayrılırsa çalışır.
  bool _savedSuccessfully = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    // Kaydedilmeden ekrandan çıkılırsa (geri tuşu, kaydırma, vb. — hepsi
    // `dispose()`u tetikler) bu oturumda yüklenip hiç saklanmamış
    // fotoğrafı temizle. `deleteAvatarPhoto` var olmayan yolu sorun
    // etmediği için burada `_identity.photoUrl` durumuna bakmaya gerek
    // yok: kaydedilmemişse zaten hiçbir profil satırı ona işaret etmiyor.
    if (_uploadedNewPhotoThisSession && !_savedSuccessfully) {
      widget.repository.deleteAvatarPhoto().catchError((error, stack) {
        ErrorReporter.record(
          error,
          stack,
          reason: 'avatar photo orphan cleanup',
        );
      });
    }
    super.dispose();
  }

  /// `hasPurchased` artık ağ hatasında yukarı fırlatıyor (shop_screen'in
  /// çevrimdışı durumunu tetiklemek için) — bu ekranın böyle bir durumu
  /// yok, üç çağrıdan biri geçici bir hıçkırıkla düşerse `_load()`ın
  /// TAMAMI (avatar kimliği, ad, ustalık) da kaybolmasın diye tek tek
  /// yutulur; kazanılmış çerçeve/rozet o denemede görünmez, ekranın geri
  /// kalanı yine de açılır.
  Future<bool> _safeHasPurchased(String itemId) async {
    try {
      return await widget.repository.hasPurchased(itemId);
    } catch (_) {
      return false;
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }
    try {
      final identity = await widget.repository.loadAvatarIdentity();
      _hadPhotoOnOpen = identity.photoUrl != null;
      final name = await widget.repository.getProfileName();
      final masteryStore = await MasteryStore.load();
      final achievementStore = await AchievementStore.load();
      final hasGoldFrame = await _safeHasPurchased('avatar_frame_gold');
      // Neon çerçeve 2026-07-31'e kadar mağaza kataloğunda tanımlıydı ama
      // hiçbir yerde açılmıyordu: 600 coin ödeyen oyuncu karşılığında
      // hiçbir şey görmüyordu. Altın çerçevenin birebir aynı deseni.
      final hasNeonFrame = await _safeHasPurchased('avatar_frame_neon');
      final hasVipBadge = await _safeHasPurchased('profile_badge_vip');

      final masteryByCategory = {
        for (final cat in widget.repository.categories)
          cat: masteryStore.correctCount(cat),
      };
      // Unvan adları dil ayarından bağımsız hep Kurmancî'dir (Xwendekar/
      // Pispor/Mamoste) — vitrine marka gibi yansır, çeviriye girmez.
      final titles = <String>[];
      for (final cat in widget.repository.categories) {
        final level = masteryStore.levelFor(cat);
        if (level != MasteryLevel.none) {
          titles.add(
            '${level.titleKu} · ${CategoryNames.localized(cat, true)}',
          );
        }
      }
      if (hasVipBadge && !titles.contains('VIP')) titles.add('VIP');

      final frames = unlockedFrames(
        unlockedBadgeCount: achievementStore.unlockedAchievements.length,
        masteryCorrectByCategory: masteryByCategory,
      );
      if (hasGoldFrame) frames.add(AvatarFrame.gold);
      if (hasNeonFrame) frames.add(AvatarFrame.neon);

      if (!mounted) return;
      setState(() {
        _identity = identity;
        _displayName = name;
        _unlocked = frames;
        _earnedTitles = titles;
        _loading = false;
        _loadFailed = false;
      });
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'avatar editor load failed');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  Future<void> _pickPhoto() async {
    // Fotoğraf seçimi asenkron: hata metinleri `context` async boşluğun
    // ötesine taşınmasın diye burada, senkron olarak çözülür.
    final tooLargeMessage = context.t(K.photoTooLarge);
    final uploadFailedMessage = context.t(K.uploadFailed);
    setState(() => _uploadingPhoto = true);
    try {
      final picker = widget.imagePicker ?? ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxPhotoBytes) {
        _showSnack(tooLargeMessage);
        return;
      }
      final contentType = file.name.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';
      final url = await widget.repository.uploadAvatarPhoto(
        Uint8List.fromList(bytes),
        contentType,
      );
      // Widget dispose olsa bile (mounted=false) nesne artık depoda —
      // `dispose()` bunu görüp temizleyebilsin diye `mounted` kontrolünden
      // ÖNCE işaretlenir.
      _uploadedNewPhotoThisSession = true;
      if (!mounted) return;
      setState(() => _identity = _identity.copyWith(photoUrl: url));
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'avatar photo upload failed');
      if (mounted) {
        _showSnack(uploadFailedMessage);
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // Fotoğraf kaldırıldıysa DEPODAKİ nesne de silinmelidir.
      //
      // 2026-08-02 denetimine kadar "fotoğrafı kaldır" yalnız
      // `profiles.avatar_url`i boşaltıyordu; dosya herkese açık `avatars`
      // kovasında `{user_id}/avatar.jpg` gibi tahmin edilebilir bir yolda
      // kalmaya devam ediyordu. Kullanıcı fotoğrafını kaldırdığını sanıyor,
      // görsel ise erişilebilir kalıyordu.
      //
      // Silme, kaldırma dokunuşunda değil KAYDETMEDE yapılır: kullanıcı
      // kaldırıp vazgeçerse nesne durmalı, yoksa profil hâlâ ona işaret
      // ederken dosya yok olur ve avatar kırık görünür.
      //
      // Sıra da önemli: önce depo, sonra profil. Ters sırada silme
      // başarısız olursa sütun boşalmış ama dosya erişilebilir kalırdı —
      // yani düzeltmek istediğimiz durumun aynısı.
      //
      // `_hadPhotoOnOpen` yalnız ekran açıldığında ZATEN kayıtlı bir
      // fotoğrafı kapsar; `_uploadedNewPhotoThisSession` bu oturumda YENİ
      // yüklenip sonra vazgeçilen fotoğrafı da kapsar — ikisi ayrı
      // senaryolar, ikisi de aynı silme çağrısını gerektirir
      // (2026-08-14 denetimi).
      if (_identity.photoUrl == null &&
          (_hadPhotoOnOpen || _uploadedNewPhotoThisSession)) {
        await widget.repository.deleteAvatarPhoto();
      }
      await widget.repository.updateAvatarIdentity(_identity);
      _savedSuccessfully = true;
      if (mounted) Navigator.of(context).pop(true);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'avatar save failed');
      if (mounted) {
        setState(() => _saving = false);
        _showSnack(context.t(K.saveFailed));
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    final t = SahneTokens.of(context);
    // 2026-09-29 Şahnê: B iskeleti — "Avatarım / Simge, renk ve çerçeve
    // seç" çubukta; eski mor kimlik kartı kalktı. Bölümler tek biçimli
    // bölüm başlığıyla; seçimler yüzey kartı ve liste grubunda. Tek
    // birincil eylem: Kaydet.
    return Scaffold(
      backgroundColor: t.bg,
      appBar: zkAppBar(context, title: Text(context.t(K.myAvatar))),
      body: SafeArea(
        top: false,
        child: _loading
            ? const BrandedLoaderCenter()
            : _loadFailed
            ? AppErrorState(
                title: context.t(K.loadFailedShort),
                message: context.t(K.checkConnection),
                retryLabel: context.t(K.retry),
                onRetry: _load,
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  SahneSpace.page,
                  SahneSpace.x2,
                  SahneSpace.page,
                  SahneSpace.x8,
                ),
                children: [
                  Center(
                    child: PlayerAvatar(
                      key: const ValueKey('avatar-preview'),
                      radius: 52,
                      photoUrl: _identity.photoUrl,
                      iconId: _identity.iconId,
                      colorHex: _identity.colorHex,
                      frameId: _identity.frameId,
                      displayName: _displayName,
                    ),
                  ),
                  const SizedBox(height: SahneSpace.x4),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: SahneSpace.x2,
                    runSpacing: SahneSpace.x2,
                    children: [
                      SahneButton.secondary(
                        key: const ValueKey('avatar-pick-photo'),
                        label: context.t(K.uploadPhoto),
                        icon: AppIcons.images,
                        onPressed: _uploadingPhoto ? null : _pickPhoto,
                      ),
                      if (_identity.photoUrl != null)
                        SahneButton.secondary(
                          key: const ValueKey('avatar-remove-photo'),
                          label: context.t(K.removeAction),
                          icon: AppIcons.xmark,
                          onPressed: () => setState(
                            () => _identity = _identity.copyWith(
                              clearPhoto: true,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SahneSectionHeader(title: context.t(K.symbol)),
                  SahneSurfaceCard(
                    padding: const EdgeInsets.all(SahneSpace.x3),
                    child: GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: SahneSpace.x2,
                      crossAxisSpacing: SahneSpace.x2,
                      children: [
                        // Ekran okuyucu 2026-07-31'e kadar bu ızgarada
                        // 16 kez yalnız "button" diyordu: hücrenin tek
                        // çocuğu etiketsiz bir Icon'du. Görme engelli
                        // oyuncu hangi sembolü seçtiğini anlayamıyordu.
                        // Adlar `avatarIcons` anahtarlarında zaten
                        // vardı, yalnız kullanılmıyordu.
                        for (final entry in avatarIcons.entries)
                          _IconCell(
                            key: ValueKey('avatar-icon-${entry.key}'),
                            icon: entry.value,
                            semanticLabel: context.t(
                              avatarIconLabelKeys[entry.key] ?? K.avatarIconRoj,
                            ),
                            selected: _identity.iconId == entry.key,
                            onTap: () => setState(
                              () => _identity = _identity.copyWith(
                                iconId: entry.key,
                                clearPhoto: true,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SahneSectionHeader(title: context.t(K.colorWord)),
                  SahneSurfaceCard(
                    padding: const EdgeInsets.all(SahneSpace.x2),
                    child: Wrap(
                      children: [
                        // Aynı kusur renklerde de vardı: InkWell'in tek
                        // çocuğu renkli bir Container, hiç metin yok.
                        // Renk adları `avatarColors` listesinin yorum
                        // satırlarında yazılıydı.
                        for (final hex in avatarColors)
                          _ColorSwatch(
                            key: ValueKey('avatar-color-$hex'),
                            color: colorFrom(hex, fallback: t.s3),
                            label: context.t(
                              avatarColorLabelKeys[hex] ?? K.colorWord,
                            ),
                            selected: _identity.colorHex == hex,
                            onTap: () => setState(
                              () =>
                                  _identity = _identity.copyWith(colorHex: hex),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SahneSectionHeader(title: context.t(K.frame)),
                  SahneListGroup(
                    dividerIndent: _choiceTextInset,
                    children: [
                      _ChoiceRow(
                        key: const ValueKey('avatar-frame-none'),
                        leading: _FrameSwatch(color: t.tx3, locked: false),
                        label: context.t(K.noFrame),
                        selected: _identity.frameId == null,
                        onTap: () => setState(
                          () =>
                              _identity = _identity.copyWith(clearFrame: true),
                        ),
                      ),
                      for (final frame in AvatarFrame.values)
                        _ChoiceRow(
                          key: ValueKey('avatar-frame-${frame.name}'),
                          leading: _FrameSwatch(
                            color: frameColor(frame),
                            locked: !_unlocked.contains(frame),
                          ),
                          label: switch (frame) {
                            AvatarFrame.bronze => context.t(K.bronze),
                            AvatarFrame.silver => context.t(K.silver),
                            AvatarFrame.gold => context.t(K.gold),
                            AvatarFrame.mamoste => 'Mamoste',
                            AvatarFrame.neon => context.t(K.frameNeon),
                          },
                          locked: !_unlocked.contains(frame),
                          selected: _identity.frameId == frame.name,
                          subtitle: _unlocked.contains(frame)
                              ? null
                              : frameRequirementLabel(frame, ku),
                          onTap: () {
                            if (!_unlocked.contains(frame)) {
                              _showSnack(
                                '${context.t(K.locked)} — '
                                '${frameRequirementLabel(frame, ku)}',
                              );
                              return;
                            }
                            setState(
                              () => _identity = _identity.copyWith(
                                frameId: frame.name,
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  SahneSectionHeader(title: context.t(K.titleWord)),
                  SahneListGroup(
                    dividerIndent: _choiceTextInset,
                    children: [
                      _ChoiceRow(
                        key: const ValueKey('avatar-title-none'),
                        leading: const _MedalTile(selected: false),
                        label: context.t(K.hideAction),
                        selected: _identity.showcaseTitle == null,
                        onTap: () => setState(
                          () =>
                              _identity = _identity.copyWith(clearTitle: true),
                        ),
                      ),
                      if (_earnedTitles.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(SahneSpace.x4),
                          child: Text(
                            context.t(K.noTitlesYet),
                            style: SahneType.caption.copyWith(color: t.tx2),
                          ),
                        ),
                      for (final title in _earnedTitles)
                        _ChoiceRow(
                          key: ValueKey('avatar-title-$title'),
                          leading: _MedalTile(
                            selected: _identity.showcaseTitle == title,
                          ),
                          label: title,
                          selected: _identity.showcaseTitle == title,
                          onTap: () => setState(
                            () => _identity = _identity.copyWith(
                              showcaseTitle: title,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: SahneSpace.x6),
                  SahneButton.primary(
                    key: const ValueKey('avatar-save'),
                    label: context.t(K.save),
                    icon: AppIcons.floppyDisk,
                    arrow: false,
                    expand: true,
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
      ),
    );
  }
}

/// Seçim satırında metnin başladığı hiza: 12 + 44'lük öncül + 12.
const double _choiceTextInset = SahneSpace.x3 + 44 + SahneSpace.x3;

/// Simge hücresi — seçim rayı çipinin karo çeşidi: M pah; seçili Kulis +
/// Halka 2 birincil metin, ikon birincil metin; seçili değil Perde +
/// kenar, ikon ikincil metin.
class _IconCell extends StatelessWidget {
  const _IconCell({
    required this.icon,
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;

  /// Ekran okuyucunun söyleyeceği ad. Sembolün kendisi görsel; adı
  /// olmadan hücre yalnız "button" diye duyulur.
  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: SahneTappable(
        shape: selected
            ? SahneShape.withSide(SahneShape.m, t.tx, width: SahneRing.r2)
            : SahneShape.withSide(SahneShape.m, t.edge, width: 1),
        color: selected ? t.s3 : t.s2,
        onTap: onTap,
        child: Center(
          child: Icon(icon, size: 24, color: selected ? t.tx : t.tx2),
        ),
      ),
    );
  }
}

/// Renk örneği — avatarla aynı elmas biçim; seçili olan Halka 2 + ✓ ile
/// (seçim yalnız renkle verilmez). Kullanıcının seçtiği renk bir belirteç
/// değil, veridir; ✓ rengi dolguya göre okunur tondan seçilir.
class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: SizedBox.square(
        // 48: dokunma kılavuzu; elmas 36.
        dimension: 52,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: SahneShape.diamond(52),
            onTap: onTap,
            excludeFromSemantics: true,
            child: Center(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: color,
                  shape: SahneShape.diamond(
                    40,
                    side: selected
                        ? BorderSide(
                            color: t.tx,
                            width: SahneRing.r2,
                            strokeAlign: BorderSide.strokeAlignOutside,
                          )
                        : BorderSide.none,
                  ),
                ),
                child: SizedBox.square(
                  dimension: 40,
                  child: selected
                      ? Icon(
                          AppIcons.check,
                          size: 18,
                          color: sahneOnFill(color),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Çerçeve önizlemesi: 44'lük Kulis karonun içinde çerçeve renginde
/// halkalı elmas (avatar biçimi). Kilitliyse ortasında kilit.
class _FrameSwatch extends StatelessWidget {
  const _FrameSwatch({required this.color, required this.locked});

  final Color color;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(color: t.s2, shape: SahneShape.m),
      child: SizedBox.square(
        dimension: 44,
        child: Center(
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: SahneShape.diamond(
                28,
                side: BorderSide(
                  color: color,
                  width: SahneRing.r3,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
            ),
            child: SizedBox.square(
              dimension: 28,
              child: locked
                  ? Icon(AppIcons.lock, size: 12, color: t.tx2)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Unvan satırının öncülü: 44'lük karo içinde madalya; seçili unvan Zêr
/// (vitrine çıkan bir ödül), ötekiler nötr.
class _MedalTile extends StatelessWidget {
  const _MedalTile({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: selected ? t.goldTint : t.s2,
        shape: SahneShape.m,
      ),
      child: SizedBox.square(
        dimension: 44,
        child: Icon(
          AppIcons.medal,
          size: 24,
          color: selected ? t.goldTx : t.tx2,
        ),
      ),
    );
  }
}

/// Tek seçimli liste satırı — [SahneListRow] geometrisi (≥ 64, 44'lük
/// öncül, 12 aralık, Gövde 700 başlık + Açıklama alt satır), öncülü
/// özel: çerçeve ya da madalya önizlemesi. Seçili satır sağda ✓ taşır
/// ve ekran okuyucuda "seçili"dir; kilitli satırın başlığı ikincil metin.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.leading,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.locked = false,
    super.key,
  });

  final Widget leading;
  final String label;
  final String? subtitle;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: [label, ?subtitle].join(', '),
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              SahneSpace.x3,
              SahneSpace.x2,
              SahneSpace.x4,
              SahneSpace.x2,
            ),
            child: Row(
              children: [
                leading,
                const SizedBox(width: SahneSpace.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: SahneType.bodyStrong.copyWith(
                          color: locked ? t.tx2 : t.tx,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: SahneType.caption.copyWith(color: t.tx2),
                        ),
                    ],
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: SahneSpace.x2),
                  Icon(AppIcons.circleCheck, size: 24, color: t.tx),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
