import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../data/placement_store.dart';
import '../data/learning_goal_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../utils/player_identity.dart';
import '../l10n/strings.dart';
import '../utils/app_route.dart';
import 'level_placement_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/analytics_consent_provider.dart';
import '../providers/reduced_motion_provider.dart';
import '../providers/untimed_mode_provider.dart';
import '../providers/sound_provider.dart';
import '../providers/theme_provider.dart';
import '../services/notification_service.dart';
import '../services/analytics_service.dart';
import '../services/premium_service.dart';
import '../services/tts_service.dart';
import '../utils/percent_format.dart';
import '../utils/external_link.dart';

import '../config/app_config.dart';
import '../models/friend.dart';
import '../models/learning_goal.dart';
import '../services/display_name_policy.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_panel.dart';
import '../widgets/legal_links.dart';
import '../widgets/branded_loader.dart';
import '../widgets/language_toggle.dart';
import '../widgets/roj_mascot.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/zk_back_button.dart';
import '../widgets/learning_goal_chooser.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'image_credits_screen.dart';
import 'paywall_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.repository,
    this.packageInfoLoader,
    super.key,
  });

  final ZanKurdRepository repository;
  final Future<PackageInfo> Function()? packageInfoLoader;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final Future<PlacementStore> _placementStoreFuture =
      PlacementStore.load();
  LearningGoal? _learningGoal;
  final _nameController = TextEditingController();
  bool _deleting = false;
  bool _loadingName = true;
  String _versionLabel = '—';
  bool _savingName = false;
  String _currentName = '';
  NotificationService? _notificationService;
  bool _notificationsEnabled = false;
  String _notificationTime = '19:00';
  bool _systemPermissionDenied = false;

  @override
  void initState() {
    super.initState();
    // 'Tomar Bike' yalnız isim gerçekten değiştiğinde aktif olur (dirty-state).
    _nameController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadPlayerName();
    _loadNotificationSettings();
    _loadPackageVersion();
    _loadLearningGoal();
  }

  Future<void> _loadLearningGoal() async {
    final store = await LearningGoalStore.load();
    if (mounted) setState(() => _learningGoal = store.goal);
  }

  Future<void> _setLearningGoal(LearningGoal goal) async {
    final store = await LearningGoalStore.load();
    final saved = await store.save(goal);
    if (!mounted) return;
    if (!saved) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t(K.saveFailed))));
      return;
    }
    setState(() => _learningGoal = goal);
  }

  bool get _isNameDirty {
    final name = _nameController.text.trim();
    return name.isNotEmpty && name != _currentName;
  }

  Future<void> _loadPackageVersion() async {
    try {
      final info =
          await (widget.packageInfoLoader ?? PackageInfo.fromPlatform)();
      if (!mounted) return;
      setState(() {
        _versionLabel = '${info.version}+${info.buildNumber}';
      });
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'settings_load');
      // Keep the neutral label on unsupported or unavailable platforms.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadPlayerName() async {
    try {
      final raw = await widget.repository.getProfileName();
      if (!mounted) return;
      // Sunucu/mock, gerçek bir seçim olmayan `ZanKurd Oyuncusu` yer
      // tutucusunu döndürür. Diğer ekranlar bunu `PlayerIdentity` üzerinden
      // dile çevirir; ayarlar ekranı ham değeri kutuya yazıyordu ve
      // Kurmancî arayüzde oyuncu adını Türkçe görüyordu (2026-07-26).
      //
      // 2026-09-29 doğallık: çözülen yedek ("Oyuncu") kutuya DEĞER olarak
      // yazılıyordu; oyuncu adı hiç seçmemişken "Oyuncu" adlı biri gibi
      // görünüyordu ve kutuyu önce silmesi gerekiyordu. Yer tutucuda kutu
      // boş kalır, `K.playerNameHint` ipucu olarak görünür.
      final name = PlayerIdentity.isPlaceholderDisplayName(raw)
          ? ''
          : PlayerIdentity.resolveName(raw, isKu: context.isKu);
      setState(() {
        _currentName = name;
        _nameController.text = name;
        _loadingName = false;
      });
    } catch (error, stack) {
      ErrorReporter.record(
        error,
        stack,
        reason: 'settings profile name load failed',
      );
      if (mounted) {
        setState(() => _loadingName = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t(K.playerNameLoadFailed))),
        );
      }
    }
  }

  /// Kötüye kullanım bildirimi için konusu hazır e-posta açar.
  ///
  /// Apple 1.2, UGC barındıran uygulamada iletişim bilgisinin
  /// yayımlanmasını şart koşar ve kullanıcı ona uygulamadan ulaşabilmeli.
  Future<void> _openAbuseReport() => openExternalUri(
    context,
    AppConfig.abuseReportUri(subject: context.t(K.abuseMailSubject)),
    reason: 'abuse report mailto',
  );

  Future<void> _openBetaFeedback() => openExternalUri(
    context,
    AppConfig.feedbackUri(subject: context.t(K.betaMailSubject)),
    reason: 'beta feedback mailto',
  );

  Future<void> _setAnalyticsConsent(bool enabled) async {
    final saved = await context.read<AnalyticsConsentProvider>().setEnabled(
      enabled,
    );
    if (!mounted) return;
    if (!saved) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t(K.saveFailed))));
      return;
    }
    if (enabled) {
      await AnalyticsService.instance.initialize(enabled: true);
    } else {
      await AnalyticsService.instance.disable();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    final t = SahneTokens.of(context);

    // 2026-09-29 Şahnê: B iskeleti. Sayfa adı ve alt başlığı çubukta
    // (`zkAppBar`); eski "ikon karosu + başlık" kimlik kartı ve kilim
    // ayırıcı kalktı — ekranın tepesinde aynı söz iki kez görünmüyor.
    // Bölümler tek biçimli [SahneSectionHeader]; satırlar liste grubu.
    return Scaffold(
      backgroundColor: t.bg,
      appBar: zkAppBar(context, title: Text(context.t(K.settings))),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            SahneSpace.page,
            0,
            SahneSpace.page,
            SahneSpace.x8,
          ),
          children: [
            // ============ HESAP / ACCOUNT ============
            SahneSectionHeader(title: context.t(K.secAccount)),
            SahneSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.t(K.playerName),
                    style: SahneType.captionStrong.copyWith(color: t.tx2),
                  ),
                  const SizedBox(height: SahneSpace.x2),
                  TextField(
                    key: const ValueKey('settings-player-name-field'),
                    controller: _nameController,
                    enabled: !_loadingName && !_savingName,
                    style: SahneType.body.copyWith(color: t.tx),
                    decoration: InputDecoration(
                      hintText: context.t(K.playerNameHint),
                      prefixIcon: const Icon(AppIcons.idBadge, size: 20),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _savePlayerName(),
                  ),
                  const SizedBox(height: SahneSpace.x3),
                  // Ayarlarda ekranın tek bir ana eylemi yok: ad kaydetmek
                  // bir alanın onayıdır, birincil (Agir) değil ikincil.
                  SahneButton.secondary(
                    label: Tr.forKu(K.save, ku),
                    icon: AppIcons.floppyDisk,
                    expand: true,
                    onPressed: _loadingName || _savingName || !_isNameDirty
                        ? null
                        : _savePlayerName,
                  ),
                ],
              ),
            ),

            // ============ ÖĞRENME / LEARNING ============
            SahneSectionHeader(title: context.t(K.secLearning)),
            SahneSurfaceCard(
              key: const ValueKey('settings-learning-goal'),
              child: LearningGoalChooser(
                isKu: ku,
                selected: _learningGoal,
                compact: true,
                onSelected: _setLearningGoal,
              ),
            ),
            const SizedBox(height: SahneSpace.cardGap),
            SahneListGroup(
              children: [
                FutureBuilder<PlacementStore>(
                  future: _placementStoreFuture,
                  builder: (context, snap) {
                    final level = snap.data?.level;
                    final String sub;
                    if (level == null) {
                      sub = context.t(K.retakePlacementSub);
                    } else {
                      final name = ku ? level.labelKu : level.labelTr;
                      sub = context.t(K.currentLevel, {'name': name});
                    }
                    return SahneListRow.plain(
                      key: const ValueKey('retake-placement-action'),
                      title: context.t(K.retakePlacement),
                      subtitle: sub,
                      chevron: true,
                      onTap: _openPlacement,
                    );
                  },
                ),
              ],
            ),

            // ============ GÜVENLİK / SAFETY ============
            //
            // Apple 1.2 dördüncü şart: UGC barındıran uygulamada
            // iletişim bilgisi YAYIMLANMIŞ olmalı. Oda sohbeti
            // 2026-07-31'de moderasyonuyla geri geldi; bu satır
            // kullanıcının taciz bildirimini nereye yapacağını söyler.
            // Web sayfasında durması yetmez — uygulamadan ulaşılmalı.
            SahneSectionHeader(title: context.t(K.secSafety)),
            // İki eylem TEK bir yüzeyde durur (bkz.
            // `beta_release_experience_test`: ortak `AppPanel` atası).
            // `AppPanel` Şahnê'de yüzey kartıdır; satırlar liste grubunun
            // diliyle, aralarında ikon hizasından başlayan ayırıcıyla.
            AppPanel(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SahneListRow.plain(
                    key: const ValueKey('settings-report-abuse'),
                    title: context.t(K.reportAbuse),
                    chevron: true,
                    onTap: _openAbuseReport,
                  ),
                  const _RowDivider(),
                  SahneListRow.plain(
                    key: const ValueKey('settings-beta-feedback'),
                    title: context.t(K.betaFeedback),
                    subtitle: context.t(K.betaFeedbackSub),
                    chevron: true,
                    onTap: _openBetaFeedback,
                  ),
                ],
              ),
            ),

            // ============ GİZLİLİK / PRIVACY ============
            SahneSectionHeader(title: context.t(K.secPrivacy)),
            SahneListGroup(
              dividerIndent: _rowTextInset,
              children: [
                Consumer<AnalyticsConsentProvider>(
                  builder: (context, consent, _) => SahneListRow.plain(
                    title: context.t(K.analyticsConsent),
                    subtitle: context.t(K.analyticsConsentSub),
                    trailing: Switch(
                      key: const ValueKey('analytics-consent-switch'),
                      value: consent.enabled,
                      onChanged: _setAnalyticsConsent,
                    ),
                  ),
                ),
              ],
            ),

            // ============ GÖRÜNÜM / APPEARANCE ============
            SahneSectionHeader(title: context.t(K.secAppearance)),
            SahneListGroup(
              dividerIndent: _rowTextInset,
              children: [
                SahneListRow.plain(
                  title: context.t(K.appLanguage),
                  trailing: const LanguageToggle(
                    kuKey: ValueKey('settings-language-ku'),
                    trKey: ValueKey('settings-language-tr'),
                  ),
                ),
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, _) => SahneListRow.plain(
                    title: context.t(K.darkLightMode),
                    trailing: Switch(
                      value: themeProvider.isDark,
                      onChanged: (_) {
                        themeProvider.toggleDarkLight();
                      },
                    ),
                  ),
                ),
                Consumer<ReducedMotionProvider>(
                  builder: (context, motion, _) => SahneListRow.plain(
                    title: context.t(K.reduceMotion),
                    trailing: Switch(
                      key: const ValueKey('reduce-motion-switch'),
                      value: motion.userReduce,
                      onChanged: (v) => motion.setUserReduce(v),
                    ),
                  ),
                ),
                // WCAG 2.2.1: zaman sınırı olan içerikte sınırı kapatma
                // yolu bulunmalı. Öğrenme ve tekrar akışları zaten
                // sayaçsızdı; kategori ve alıştırma turunda kapatmanın
                // hiçbir yolu yoktu.
                Consumer<UntimedModeProvider>(
                  builder: (context, untimed, _) => SahneListRow.plain(
                    title: context.t(K.untimedSolo),
                    subtitle: context.t(K.untimedSoloSub),
                    trailing: Switch(
                      key: const ValueKey('untimed-solo-switch'),
                      value: untimed.enabled,
                      onChanged: (v) => untimed.setEnabled(v),
                    ),
                  ),
                ),
              ],
            ),

            // ============ SES & BİLDİRİM / SOUND & NOTIFICATIONS ============
            SahneSectionHeader(title: context.t(K.secSoundNotif)),
            SahneListGroup(
              dividerIndent: _rowTextInset,
              children: [
                // Ses efektleri web'de HİÇ çalmıyor: `SoundProvider._play`
                // ikinci satırında `if (kIsWeb) return;` diyor. Anahtar
                // yine de koşulsuz gösteriliyordu, yani web kullanıcısı
                // hiçbir şey yapmayan bir kontrolü açıp kapatıyordu
                // (2026-07-31 denetimi). Ölü kontrol, bozuk kontroldür.
                if (!kIsWeb)
                  Consumer<SoundProvider>(
                    builder: (context, sound, _) => SahneListRow.plain(
                      title: context.t(K.soundEffects),
                      trailing: Switch(
                        value: sound.enabled,
                        onChanged: (_) => sound.toggle(),
                      ),
                    ),
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SahneListRow.plain(
                      title: context.t(K.dailyReminder),
                      subtitle: context.t(K.dailyReminderAt, {
                        'time': _notificationTime,
                      }),
                      trailing: Switch(
                        value: _notificationsEnabled,
                        onChanged: _toggleNotifications,
                      ),
                    ),
                    if (_notificationsEnabled && _systemPermissionDenied)
                      _InlineNotice(
                        icon: AppIcons.bellSlash,
                        text: context.t(K.notifPermDeniedInline),
                        error: true,
                      ),
                  ],
                ),
                if (_notificationsEnabled)
                  SahneListRow.plain(
                    title: context.t(K.changeTime, {'time': _notificationTime}),
                    chevron: true,
                    onTap: _pickNotificationTime,
                  ),
              ],
            ),

            // ============ SESLENDİRME (TTS) ============
            SahneSectionHeader(title: context.t(K.secTts)),
            const _TtsSettingsSection(),

            // ============ ENGELLENENLER ============
            // 2026-08-02 denetimi: `unblockPlayer` depoda vardı ama TEK
            // bir çağıranı bile yoktu — kullanıcı birini engelledikten
            // sonra kararını geri alamıyordu. Engelleme, geri alınabilir
            // olmadıkça bir moderasyon aracı değil tek yönlü bir kapıdır.
            SahneSectionHeader(title: context.t(K.secBlocked)),
            _BlockedUsersSection(repository: widget.repository),

            // ============ PREMIUM ABONELİK ============
            // Diğer her blok gibi premium de kendi bölüm başlığını taşır.
            // Başlıksızken kart, bir üstteki "Seslendirme" bölümünün
            // devamı gibi görünüyor ve para kazandıran tek giriş noktası
            // ayarların içinde kayboluyordu (2026-07-25 canlı denetimi).
            //
            // Abone olmayana + yapılandırma yoksa bölüm gizlenir: ürünsüz
            // paywall ölü sokaktır (2026-09-05 canlı turu). Abone, durum
            // satırını her zaman görür.
            Consumer<PremiumService>(
              builder: (context, premium, _) {
                final isPremium = premium.isPremium;
                if (!isPremium && !AppConfig.hasRevenuecatConfig) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SahneSectionHeader(title: 'Premium'),
                    SahneListGroup(
                      children: [
                        SahneListRow.icon(
                          icon: AppIcons.gem,
                          role: SahneRole.gold,
                          title: isPremium
                              ? context.t(K.premiumBrand)
                              : context.t(K.premiumCta),
                          subtitle: isPremium
                              ? context.t(K.premiumActive)
                              : context.t(K.premiumPerks),
                          trailing: SahneBadge(
                            label: isPremium
                                ? context.t(K.premiumBadgeOn)
                                : context.t(K.premiumBadgeOff),
                            tone: isPremium
                                ? SahneBadgeTone.gold
                                : SahneBadgeTone.soon,
                          ),
                          chevron: true,
                          onTap: () => Navigator.of(context).push(
                            AppRoute.to(
                              PaywallScreen(repository: widget.repository),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),

            // ============ HAKKINDA / ABOUT ============
            SahneSectionHeader(title: context.t(K.secAbout)),
            SahneListGroup(
              dividerIndent: _rowTextInset,
              children: [
                _ExpandableRow(
                  title: context.t(K.howToPlay),
                  body: context.t(K.howToPlayBody),
                ),
                _ExpandableRow(
                  title: context.t(K.privacy),
                  body: context.t(K.privacyBody),
                ),
              ],
            ),
            const SizedBox(height: SahneSpace.cardGap),
            // Sürüm, hakkında metni ve yasal bağlantılar tek bir yüzey
            // kartında; marka logo plakasıyla (eski "ZK" degrade karosu
            // kalktı).
            SahneSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const BrandMarkPlate(size: 44),
                      const SizedBox(width: SahneSpace.x3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ZanKurd',
                              style: SahneType.bodyStrong.copyWith(color: t.tx),
                            ),
                            Text(
                              '${context.t(K.version)} $_versionLabel',
                              style: SahneType.caption.copyWith(
                                color: t.tx2,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SahneSpace.x3),
                  Text(
                    context.t(K.aboutBody),
                    style: SahneType.body.copyWith(color: t.tx2),
                  ),
                  const SizedBox(height: SahneSpace.x3),
                  // Yasal bağlantılar (mağaza şartı)
                  const LegalLinksRow(),
                  // Soru fotoğrafları CC BY lisanslıdır; atıf yasal
                  // yükümlülüktür (bkz. image_credits_screen.dart).
                  SahneButton.text(
                    key: const ValueKey('settings-image-credits'),
                    label: context.t(K.imageCredits),
                    onPressed: () => Navigator.of(
                      context,
                    ).push(AppRoute.to(const ImageCreditsScreen())),
                  ),
                ],
              ),
            ),

            // Hesap silme en yıkıcı eylem olmasına rağmen ayarların
            // en üstünde, ikinci kartta duruyordu. Yeni kullanıcı
            // için yanlış öncelik — en alta taşındı
            // (2026-07-22 canlı UX denetimi).
            SahneSectionHeader(title: context.t(K.secDanger)),
            Padding(
              padding: const EdgeInsets.only(bottom: SahneSpace.x3),
              child: Text(
                context.t(K.dangerNote),
                style: SahneType.caption.copyWith(color: t.tx2),
              ),
            ),
            SahneListGroup(
              children: [
                SahneListRow.plain(
                  key: const ValueKey('delete-account-action'),
                  destructive: true,
                  title: context.t(K.deleteAccount),
                  subtitle: context.t(K.deleteAccountSub),
                  trailing: _deleting
                      ? const BrandedLoader(size: 20, strokeWidth: 2)
                      : null,
                  chevron: !_deleting,
                  onTap: _deleting ? null : _confirmDeleteAccount,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final service = await NotificationService.load();
      if (mounted) {
        setState(() {
          _notificationService = service;
          _notificationsEnabled = service.enabled;
          _notificationTime = service.timeDisplay;
        });
        if (service.enabled) {
          // Uygulama içi tercih açık ama sistem izni kapatılmış olabilir
          // (kullanıcı sistem ayarlarından engellemiştir) — uyarı göster.
          final granted = await service.hasSystemPermission();
          if (mounted && !granted) {
            setState(() => _systemPermissionDenied = true);
          }
        }
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'settings_action');
      // Bildirim servisi başlatılamazsa sessizce devam et.
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    final service = _notificationService;
    if (service == null) return;
    await service.setEnabled(value);
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = value;
      _systemPermissionDenied = false;
    });
    if (value) {
      final granted = await service.hasSystemPermission();
      if (!mounted || granted) return;
      setState(() => _systemPermissionDenied = true);
      _showSystemPermissionDialog();
    }
  }

  /// Sistem bildirim izni reddedilmişse kullanıcıyı bilgilendirir.
  void _showSystemPermissionDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t(K.notifPermDenied)),
        content: Text(context.t(K.notifPermDeniedBody)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.t(K.ok)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickNotificationTime() async {
    final service = _notificationService;
    if (service == null) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: service.hour, minute: service.minute),
    );
    if (picked != null && mounted) {
      await service.setTime(picked.hour, picked.minute);
      setState(() {
        _notificationTime = service.timeDisplay;
      });
    }
  }

  Future<void> _openPlacement() async {
    await Navigator.of(
      context,
    ).push(AppRoute.to(LevelPlacementScreen(repository: widget.repository)));
    if (mounted) setState(() {}); // güncel seviyeyi yansıt
  }

  Future<void> _confirmDeleteAccount() async {
    final continueDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t(K.deleteConfirmTitle)),
        content: Text(context.t(K.deleteConfirmBody)),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.t(K.cancel)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.t(K.continueAction)),
          ),
        ],
      ),
    );

    if (continueDelete != true || !mounted) return;
    final confirmed = await _showFinalDeleteConfirmation();
    if (confirmed != true || !mounted) return;
    await _deleteAccount();
  }

  Future<void> _savePlayerName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name == _currentName) return;

    // 2026-08-02: bu yol hiçbir içerik kontrolünden geçmiyordu. İsim kapısı
    // ve ayarlar aynı sütuna yazıyor; yalnız birini süzmek kapıyı açık
    // bırakırdı — kullanıcı adını kapıda temiz verip sonra buradan
    // değiştirebilirdi.
    final verdict = DisplayNamePolicy.review(name);
    if (verdict != DisplayNameVerdict.allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const ValueKey('settings-name-rejected'),
          content: Text(context.t(DisplayNamePolicy.messageKeyFor(verdict))),
        ),
      );
      return;
    }

    setState(() => _savingName = true);
    try {
      await widget.repository.updateProfileName(name);
      if (!mounted) return;
      setState(() {
        _currentName = name;
        _savingName = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t(K.playerNameUpdated))));
    } catch (error, stack) {
      ErrorReporter.record(
        error,
        stack,
        reason: 'settings profile name save failed',
      );
      if (!mounted) return;
      setState(() => _savingName = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t(K.playerNameSaveFailed))),
      );
    }
  }

  Future<bool?> _showFinalDeleteConfirmation() async {
    final controller = TextEditingController();
    final confirmWord = context.t(K.deleteWord);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        var canDelete = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(context.t(K.finalConfirm)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.t(K.deleteTypeWord, {'word': confirmWord})),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('delete-confirm-field'),
                    controller: controller,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(hintText: confirmWord),
                    onChanged: (value) {
                      setDialogState(
                        () => canDelete = value.trim() == confirmWord,
                      );
                    },
                  ),
                ],
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(context.t(K.cancel)),
                ),
                FilledButton(
                  onPressed: canDelete
                      ? () => Navigator.pop(dialogContext, true)
                      : null,
                  child: Text(context.t(K.deleteForever)),
                ),
              ],
            );
          },
        );
      },
    );
    // StatefulBuilder rebuild akışının tamamlanması için bir sonraki frame'de dispose.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    return result;
  }

  Future<void> _deleteAccount() async {
    setState(() => _deleting = true);
    final authProvider = context.read<AuthProvider>();
    final deletedUserId = widget.repository.currentUserId?.trim();
    try {
      await widget.repository.deleteMyAccount();
      // Sunucu silmesi başarılı olduktan sonra ekran route'u kapanmış olsa
      // bile yerel kimlik ve tam o hesaba ait kuyruk temizlenmelidir.
      await authProvider.signOut(
        discardPendingRewards: true,
        pendingRewardsOwnerId: deletedUserId,
      );
    } on AccountLocalCleanupException catch (error, stack) {
      ErrorReporter.record(
        error,
        stack,
        reason: 'deleteAccount local cleanup failed',
      );
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t(K.accountLocalCleanupFailed))),
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'deleteAccount failed');
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t(K.accountDeleteFailed))));
    }
  }
}

/// Liste satırında metnin başladığı hiza. Satır olmayan çocukların
/// (Consumer, Column) grup ayırıcısı da buradan başlar;
/// [SahneListRow.dividerIndent] ile aynı değer.
///
/// 2026-09-29 doğallık (K7): ayar satırları ikonsuzdur
/// ([SahneListRow.plain]); metin satırın kenarından (16) başlar. Eskiden
/// her satırın başında metni tekrarlayan bir ikon karosu vardı (dil
/// satırında dil ikonu, bildirimde zil, hareketi azalt'ta film şeridi…):
/// on dört karo alt alta, hiçbiri satırın söylemediği bir şey söylemiyordu.
/// Yalnız Premium satırı ikonunu korur: orada ikon bir ürünün kimliğidir.
const double _rowTextInset = SahneSpace.x4;

/// Liste grubunun ayırıcısı — grubun kendisi yerine `AppPanel` kullanılan
/// tek yerde (güvenlik bölümü) elle konur.
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: _rowTextInset),
      child: ExcludeSemantics(
        child: SizedBox(
          height: 1,
          child: ColoredBox(color: SahneTokens.of(context).line),
        ),
      ),
    );
  }
}

/// Satırın altındaki kısa not: ikon + açıklama. [error] Şaş metniyle
/// (durum hiçbir zaman yalnız renkle verilmez: ikon ve söz birlikte).
class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.text,
    this.error = false,
  });

  final IconData icon;
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final color = error ? t.errTx : t.tx2;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        _rowTextInset,
        0,
        SahneSpace.x4,
        SahneSpace.x3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: SahneSpace.x2),
          Expanded(
            child: Text(
              text,
              style: (error ? SahneType.captionStrong : SahneType.caption)
                  .copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Açılır bilgi satırı ("Nasıl oynanır", "Gizlilik"): liste satırı +
/// altında gövde metni. Açılış hareketi azaltta anında olur.
class _ExpandableRow extends StatefulWidget {
  const _ExpandableRow({required this.title, required this.body});

  final String title;
  final String body;

  @override
  State<_ExpandableRow> createState() => _ExpandableRowState();
}

class _ExpandableRowState extends State<_ExpandableRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return AnimatedSize(
      duration: sahneMotionReduced(context) ? Duration.zero : SahneMotion.fade,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SahneListRow.plain(
            title: widget.title,
            trailing: ExcludeSemantics(
              child: Icon(
                _open ? AppIcons.chevronUp : AppIcons.chevronDown,
                size: 20,
                color: t.tx3,
              ),
            ),
            onTap: () => setState(() => _open = !_open),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                _rowTextInset,
                0,
                SahneSpace.x4,
                SahneSpace.x4,
              ),
              child: Text(
                widget.body,
                style: SahneType.body.copyWith(color: t.tx2),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ayarlar > Seslendirme (TTS) bölümü. TtsService'i yükler; aç/kapa,
/// konuşma hızı ve ses seviyesi kontrollerini gösterir. Cihazda Kürtçe
/// seslendirme desteklenmiyorsa durum açıkça gösterilir ve etkisiz ayarlar
/// kapatılır.
class _TtsSettingsSection extends StatefulWidget {
  const _TtsSettingsSection();

  @override
  State<_TtsSettingsSection> createState() => _TtsSettingsSectionState();
}

class _TtsSettingsSectionState extends State<_TtsSettingsSection> {
  TtsService? _tts;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tts = await TtsService.load();
      if (mounted) {
        setState(() {
          _tts = tts;
          _loading = false;
        });
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'settings tts load');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tts = _tts;

    if (_loading) {
      // Yükleme çok kısa sürer; sonsuz animasyonlu bir gösterge yerine
      // sabit bir yer tutucu kullanılır (widget testlerinde pumpAndSettle
      // sonsuz dönen bir spinner'da takılmasın).
      return const SizedBox(height: 0);
    }

    final t = SahneTokens.of(context);
    if (tts == null) {
      return SahneSurfaceCard(
        child: Text(
          context.t(K.ttsUnavailable),
          style: SahneType.caption.copyWith(color: t.tx2),
        ),
      );
    }

    final enabled = tts.isEnabled;
    final canSpeak = tts.isKurdishAvailable;
    return SahneListGroup(
      dividerIndent: _rowTextInset,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SahneListRow.plain(
              title: context.t(K.ttsEnable),
              subtitle: context.t(K.ttsEnableSub),
              trailing: Switch(
                value: enabled && canSpeak,
                onChanged: canSpeak
                    ? (v) async {
                        await tts.setEnabled(v);
                        if (mounted) setState(() {});
                      }
                    : null,
              ),
            ),
            if (!tts.isKurdishAvailable)
              _InlineNotice(
                icon: AppIcons.circleInfo,
                text: context.t(K.ttsKurdishLimited),
              ),
          ],
        ),
        if (enabled && canSpeak) ...[
          _TtsSlider(
            label: context.t(K.ttsRate),
            value: tts.rate,
            onChanged: (v) async {
              await tts.setRate(v);
              if (mounted) setState(() {});
            },
          ),
          _TtsSlider(
            label: context.t(K.ttsVolume),
            value: tts.volume,
            onChanged: (v) async {
              await tts.setVolume(v);
              if (mounted) setState(() {});
            },
          ),
        ],
      ],
    );
  }
}

/// TTS hız/ses seviyesi için 0–1 aralığında etiketli kaydırıcı satırı.
///
/// Liste satırının geometrisi: başlık (Gövde 700) satırın kenarından (16)
/// başlar, sağda değer; kaydırıcı başlığın altında. 2026-09-29 doğallık:
/// ikonsuz, üstündeki ayar satırlarıyla aynı hizada (bkz. [_rowTextInset]).
class _TtsSlider extends StatelessWidget {
  const _TtsSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        _rowTextInset,
        SahneSpace.x2,
        SahneSpace.x4,
        SahneSpace.x1,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: SahneType.bodyStrong.copyWith(color: t.tx),
                      ),
                    ),
                    // Sınıf belgesi "etiketleli kaydırıcı" diyordu ama
                    // ekranda yalnız ad vardı: kullanıcı hızın ya da sesin
                    // hangi değerde olduğunu göremiyordu (2026-07-25
                    // denetimi). Yüzde, kaydırıcının kendisiyle aynı
                    // satırda durur; tablo rakamı değer değişirken etiketi
                    // zıplatmaz.
                    Text(
                      context.percentRatio(value.clamp(0.0, 1.0)),
                      textAlign: TextAlign.end,
                      style: SahneType.captionStrong.copyWith(
                        color: t.tx2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                Semantics(
                  slider: true,
                  label: label,
                  value: context.percentRatio(value.clamp(0.0, 1.0)),
                  child: Slider(
                    value: value.clamp(0.0, 1.0),
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Engellenen oyuncular ve engeli kaldırma.
///
/// 2026-08-02 denetiminde bulundu: `unblockPlayer` deposu vardı, arayüzü
/// yoktu. Engelleme geri alınabilir olmadıkça moderasyon aracı değil, tek
/// yönlü bir kapıdır — yanlışlıkla engellenen bir arkadaş kalıcı olarak
/// kayboluyordu.
class _BlockedUsersSection extends StatefulWidget {
  const _BlockedUsersSection({required this.repository});

  final ZanKurdRepository repository;

  @override
  State<_BlockedUsersSection> createState() => _BlockedUsersSectionState();
}

class _BlockedUsersSectionState extends State<_BlockedUsersSection> {
  late Future<List<PlayerSearchResult>> _future;
  final Set<String> _working = <String>{};

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadBlockedPlayers();
  }

  void _retry() => setState(() {
    _future = widget.repository.loadBlockedPlayers();
  });

  Future<void> _unblock(PlayerSearchResult player) async {
    setState(() => _working.add(player.id));
    final ok = await widget.repository.unblockPlayer(player.id);
    if (!mounted) return;
    setState(() {
      _working.remove(player.id);
      if (ok) _future = widget.repository.loadBlockedPlayers();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t(ok ? K.unblockDone : K.errorOccurred))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return FutureBuilder<List<PlayerSearchResult>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SahneSurfaceCard(
            child: Center(child: BrandedLoader(size: 20, strokeWidth: 2)),
          );
        }
        if (snapshot.hasError) {
          // `loadBlockedPlayers` artık okunamayan listeyi yutup boş
          // dönmüyor (rethrow) — burada da yutup "kimseyi engellemedin"
          // gösterirsek aynı sessiz kırılma boş durum kılığına girer.
          // Gerçekten engellenmiş biri kalıcı kaybolmuş gibi görünürdü,
          // engeli kaldırma yolu da onunla birlikte kaybolurdu
          // (2026-08-14 denetimi).
          return SahneSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        AppIcons.triangleExclamation,
                        size: 20,
                        color: t.errTx,
                      ),
                    ),
                    const SizedBox(width: SahneSpace.x2),
                    Expanded(
                      child: Text(
                        context.t(K.blockedLoadFailed),
                        key: const ValueKey('blocked-error'),
                        style: SahneType.body.copyWith(color: t.tx),
                      ),
                    ),
                  ],
                ),
                SahneButton.text(label: context.t(K.retry), onPressed: _retry),
              ],
            ),
          );
        }
        final blocked = snapshot.data ?? const <PlayerSearchResult>[];
        if (blocked.isEmpty) {
          return SahneSurfaceCard(
            child: Text(
              context.t(K.blockedEmpty),
              key: const ValueKey('blocked-empty'),
              style: SahneType.caption.copyWith(color: t.tx2),
            ),
          );
        }
        return SahneListGroup(
          children: [
            for (final player in blocked)
              SahneListRow.plain(
                key: ValueKey('blocked-row-${player.id}'),
                title: player.displayName,
                subtitle: player.formattedTag,
                trailing: SahneButton.text(
                  key: ValueKey('unblock-${player.id}'),
                  label: context.t(K.unblockAction),
                  arrow: false,
                  onPressed: _working.contains(player.id)
                      ? null
                      : () => _unblock(player),
                ),
              ),
          ],
        );
      },
    );
  }
}
