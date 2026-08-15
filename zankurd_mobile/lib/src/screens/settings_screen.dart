import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../data/placement_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../utils/player_identity.dart';
import '../l10n/strings.dart';
import '../utils/app_route.dart';
import 'level_placement_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/analytics_consent_provider.dart';
import '../providers/child_safety_provider.dart';
import '../providers/reduced_motion_provider.dart';
import '../providers/untimed_mode_provider.dart';
import '../providers/sound_provider.dart';
import '../providers/theme_provider.dart';
import '../services/notification_service.dart';
import '../services/analytics_service.dart';
import '../services/premium_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../utils/percent_format.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../models/friend.dart';
import '../services/display_name_policy.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_panel.dart';
import '../widgets/legal_links.dart';
import '../widgets/screen_identity_header.dart';
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
      final name = PlayerIdentity.resolveName(raw, isKu: context.isKu);
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
  Future<void> _openAbuseReport() async {
    final uri = AppConfig.abuseReportUri(
      subject: context.t(K.abuseMailSubject),
    );
    final failed = context.t(K.linkOpenFailed);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok || !mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failed)));
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'abuse report mailto');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  Future<void> _openBetaFeedback() async {
    final uri = AppConfig.feedbackUri(subject: context.t(K.betaMailSubject));
    final failed = context.t(K.linkOpenFailed);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok || !mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failed)));
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'beta feedback mailto');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  Future<void> _setAnalyticsConsent(bool enabled) async {
    await context.read<AnalyticsConsentProvider>().setEnabled(enabled);
    if (enabled) {
      await AnalyticsService.instance.initialize();
    } else {
      await AnalyticsService.instance.disable();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;

    return Scaffold(
      extendBodyBehindAppBar: true,
      // Başlık [ScreenIdentityHeader]'da; AppBar yalnız geri düğmesini
      // taşır. İkisi de başlık yazdığında ekranın tepesinde aynı sözcük
      // iki kez görünüyordu (2026-07-25 canlı denetimi).
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: Container(
        color: AppTheme.bgOf(context),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.xs,
              AppSpacing.page,
              AppSpacing.lg,
            ),
            children: [
              ScreenIdentityHeader(
                title: context.t(K.settings),
                subtitle: context.t(K.settingsSubtitle),
                accent: AppTheme.culturalBrandBg,
                icon: AppIcons.gear,
                compact: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              // ============ HESAP / ACCOUNT ============
              ScreenSectionLabel(
                label: context.t(K.secAccount),
                accent: AppTheme.violet,
              ),
              AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SettingsIconTitle(
                      icon: AppIcons.idBadge,
                      color: AppTheme.primaryGradientStart,
                      title: context.t(K.playerName),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      key: const ValueKey('settings-player-name-field'),
                      controller: _nameController,
                      enabled: !_loadingName && !_savingName,
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor(context),
                      ),
                      decoration: InputDecoration(
                        hintText: context.t(K.playerNameHint),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _savePlayerName(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _loadingName || _savingName || !_isNameDirty
                            ? null
                            : _savePlayerName,
                        icon: _savingName
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(AppIcons.floppyDisk),
                        label: Text(Tr.forKu(K.save, ku)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),

              // ============ ÖĞRENME / LEARNING ============
              ScreenSectionLabel(
                label: context.t(K.secLearning),
                accent: AppTheme.playGreen,
              ),
              AppPanel(
                color: AppTheme.surfaceOf(context),
                child: InkWell(
                  key: const ValueKey('retake-placement-action'),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  onTap: _openPlacement,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Icon(
                          AppIcons.squareCheck,
                          color: AppTheme.playGreen,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.t(K.retakePlacement),
                                style: TextStyle(
                                  color: AppTheme.textPrimaryColor(context),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              FutureBuilder<PlacementStore>(
                                future: _placementStoreFuture,
                                builder: (context, snap) {
                                  final level = snap.data?.level;
                                  final String sub;
                                  if (level == null) {
                                    sub = context.t(K.retakePlacementSub);
                                  } else {
                                    final name = ku
                                        ? level.labelKu
                                        : level.labelTr;
                                    sub = context.t(K.currentLevel, {
                                      'name': name,
                                    });
                                  }
                                  return Text(
                                    sub,
                                    style: AppTypography.caption.copyWith(
                                      color: AppTheme.textMutedColor(context),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          AppIcons.chevronRight,
                          color: AppTheme.textMutedColor(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),

              // ============ GÜVENLİK / SAFETY ============
              //
              // Apple 1.2 dördüncü şart: UGC barındıran uygulamada
              // iletişim bilgisi YAYIMLANMIŞ olmalı. Oda sohbeti
              // 2026-07-31'de moderasyonuyla geri geldi; bu satır
              // kullanıcının taciz bildirimini nereye yapacağını söyler.
              // Web sayfasında durması yetmez — uygulamadan ulaşılmalı.
              ScreenSectionLabel(
                label: context.t(K.secSafety),
                accent: AppTheme.playGreen,
              ),
              AppPanel(
                padding: EdgeInsets.zero,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const ValueKey('settings-report-abuse'),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: _openAbuseReport,
                    child: _SettingsToggleRow(
                      icon: AppIcons.triangleExclamation,
                      color: AppTheme.playGreen,
                      title: context.t(K.reportAbuse),
                      trailing: Icon(
                        AppIcons.chevronRight,
                        color: AppTheme.textMutedColor(context),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              AppPanel(
                padding: EdgeInsets.zero,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const ValueKey('settings-beta-feedback'),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: _openBetaFeedback,
                    child: _SettingsToggleRow(
                      icon: AppIcons.circleInfo,
                      color: AppTheme.playCyan,
                      title: context.t(K.betaFeedback),
                      subtitle: context.t(K.betaFeedbackSub),
                      trailing: Icon(
                        AppIcons.chevronRight,
                        color: AppTheme.textMutedColor(context),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),

              // ============ GİZLİLİK / PRIVACY ============
              ScreenSectionLabel(
                label: context.t(K.secPrivacy),
                accent: AppTheme.violet,
              ),
              AppPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    Consumer<AnalyticsConsentProvider>(
                      builder: (context, consent, _) => _SettingsToggleRow(
                        icon: AppIcons.shieldHalved,
                        color: AppTheme.violet,
                        title: context.t(K.analyticsConsent),
                        subtitle: context.t(K.analyticsConsentSub),
                        trailing: Switch(
                          key: const ValueKey('analytics-consent-switch'),
                          value: consent.enabled,
                          onChanged: _setAnalyticsConsent,
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 56,
                      color: AppTheme.borderColor(context),
                    ),
                    Consumer<ChildSafetyProvider>(
                      builder: (context, childSafety, _) =>
                          _SettingsToggleRow(
                            icon: AppIcons.shield,
                            color: AppTheme.violet,
                            title: context.t(K.childSafetyMode),
                            subtitle: context.t(K.childSafetyModeSub),
                            trailing: Switch(
                              key: const ValueKey('child-safety-switch'),
                              value: childSafety.enabled,
                              onChanged: _toggleChildSafety,
                            ),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),

              // ============ GÖRÜNÜM / APPEARANCE ============
              ScreenSectionLabel(
                label: context.t(K.secAppearance),
                accent: AppTheme.violet,
              ),
              AppPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingsToggleRow(
                      icon: AppIcons.language,
                      color: AppTheme.violet,
                      title: context.t(K.appLanguage),
                      trailing: _LangSwitch(),
                    ),
                    Divider(
                      height: 1,
                      indent: 56,
                      color: AppTheme.borderColor(context),
                    ),
                    Consumer<ThemeProvider>(
                      builder: (context, themeProvider, _) =>
                          _SettingsToggleRow(
                            icon: themeProvider.isDark
                                ? AppIcons.moon
                                : AppIcons.sun,
                            color: AppTheme.violet,
                            title: context.t(K.darkLightMode),
                            trailing: Switch(
                              value: themeProvider.isDark,
                              onChanged: (_) {
                                themeProvider.toggleDarkLight();
                              },
                            ),
                          ),
                    ),
                    Divider(
                      height: 1,
                      indent: 56,
                      color: AppTheme.borderColor(context),
                    ),
                    Consumer<ReducedMotionProvider>(
                      builder: (context, motion, _) => _SettingsToggleRow(
                        icon: AppIcons.clapperboard,
                        color: AppTheme.violet,
                        title: context.t(K.reduceMotion),
                        trailing: Switch(
                          key: const ValueKey('reduce-motion-switch'),
                          value: motion.userReduce,
                          onChanged: (v) => motion.setUserReduce(v),
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 56,
                      color: AppTheme.borderColor(context),
                    ),
                    // WCAG 2.2.1: zaman sınırı olan içerikte sınırı kapatma
                    // yolu bulunmalı. Öğrenme ve tekrar akışları zaten
                    // sayaçsızdı; kategori ve alıştırma turunda kapatmanın
                    // hiçbir yolu yoktu.
                    Consumer<UntimedModeProvider>(
                      builder: (context, untimed, _) => _SettingsToggleRow(
                        icon: AppIcons.stopwatch,
                        color: AppTheme.violet,
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
              ),
              const SizedBox(height: AppSpacing.cardGap),

              // ============ SES & BİLDİRİM / SOUND & NOTIFICATIONS ============
              ScreenSectionLabel(
                label: context.t(K.secSoundNotif),
                accent: AppTheme.violet,
              ),
              AppPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    // Ses efektleri web'de HİÇ çalmıyor: `SoundProvider._play`
                    // ikinci satırında `if (kIsWeb) return;` diyor. Anahtar
                    // yine de koşulsuz gösteriliyordu, yani web kullanıcısı
                    // hiçbir şey yapmayan bir kontrolü açıp kapatıyordu
                    // (2026-07-31 denetimi). Ölü kontrol, bozuk kontroldür.
                    if (!kIsWeb) ...[
                      Consumer<SoundProvider>(
                        builder: (context, sound, _) => _SettingsToggleRow(
                          icon: sound.enabled
                              ? AppIcons.volumeHigh
                              : AppIcons.volumeXmark,
                          color: AppTheme.primaryGradientStart,
                          title: context.t(K.soundEffects),
                          trailing: Switch(
                            value: sound.enabled,
                            onChanged: (_) => sound.toggle(),
                          ),
                        ),
                      ),
                      Divider(
                        height: 1,
                        indent: 56,
                        color: AppTheme.borderColor(context),
                      ),
                    ],
                    _SettingsToggleRow(
                      icon: _notificationsEnabled
                          ? AppIcons.bell
                          : AppIcons.bellSlash,
                      color: AppTheme.violet,
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppTheme.wrong.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: AppTheme.wrong.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                AppIcons.bellSlash,
                                color: AppColors.onAccentTint(
                                  context,
                                  AppTheme.wrong,
                                ),
                                size: 20,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  context.t(K.notifPermDeniedInline),
                                  style: AppTypography.caption.copyWith(
                                    color: AppTheme.wrong,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_notificationsEnabled) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          onTap: _pickNotificationTime,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceHiColor(context),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(
                                color: AppTheme.borderColor(context),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  AppIcons.clock,
                                  color: AppTheme.violet,
                                  size: 18,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  context.t(K.changeTime, {
                                    'time': _notificationTime,
                                  }),
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppTheme.textPrimaryColor(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),

              // ============ SESLENDİRME (TTS) ============
              ScreenSectionLabel(
                label: context.t(K.secTts),
                accent: AppTheme.primaryGradientStart,
              ),
              const _TtsSettingsSection(),
              const SizedBox(height: AppSpacing.cardGap),

              // ============ ENGELLENENLER ============
              // 2026-08-02 denetimi: `unblockPlayer` depoda vardı ama TEK
              // bir çağıranı bile yoktu — kullanıcı birini engelledikten
              // sonra kararını geri alamıyordu. Engelleme, geri alınabilir
              // olmadıkça bir moderasyon aracı değil tek yönlü bir kapıdır.
              ScreenSectionLabel(
                label: context.t(K.secBlocked),
                accent: AppTheme.wrong,
              ),
              _BlockedUsersSection(repository: widget.repository),
              const SizedBox(height: AppSpacing.cardGap),

              // ============ PREMIUM ABONELİK ============
              // Diğer her blok gibi premium de kendi bölüm başlığını taşır.
              // Başlıksızken kart, bir üstteki "Seslendirme" bölümünün
              // devamı gibi görünüyor ve para kazandıran tek giriş noktası
              // ayarların içinde kayboluyordu (2026-07-25 canlı denetimi).
              const ScreenSectionLabel(label: 'Premium', accent: AppTheme.gold),
              Consumer<PremiumService>(
                builder: (context, premium, _) {
                  final isPremium = premium.isPremium;
                  return AppPanel(
                    padding: EdgeInsets.zero,
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        AppRoute.to(
                          PaywallScreen(repository: widget.repository),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.gold.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                                border: Border.all(
                                  color: AppTheme.gold.withValues(
                                    alpha: isPremium ? 0.5 : 0.3,
                                  ),
                                ),
                              ),
                              child: Icon(
                                AppIcons.gem,
                                color: AppColors.onAccentTint(
                                  context,
                                  AppTheme.gold,
                                ),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isPremium
                                        ? context.t(K.premiumBrand)
                                        : context.t(K.premiumCta),
                                    style: AppTypography.bodyLarge.copyWith(
                                      color: AppTheme.textPrimaryColor(context),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isPremium
                                        ? (context.t(K.premiumActive))
                                        : (context.t(K.premiumPerks)),
                                    style: AppTypography.caption.copyWith(
                                      color: AppTheme.textSubColor(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isPremium
                                    ? AppTheme.gold.withValues(alpha: 0.2)
                                    : AppTheme.primaryGradientStart.withValues(
                                        alpha: 0.16,
                                      ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.lg,
                                ),
                              ),
                              child: Text(
                                isPremium
                                    ? (context.t(K.premiumBadgeOn))
                                    : (context.t(K.premiumBadgeOff)),
                                style: TextStyle(
                                  color: AppColors.readableAccent(
                                    context,
                                    isPremium
                                        ? AppTheme.gold
                                        : AppTheme.primaryGradientStart,
                                  ),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.cardGap),

              // ============ HAKKINDA / ABOUT ============
              ScreenSectionLabel(
                label: context.t(K.secAbout),
                accent: AppTheme.violet,
              ),
              // How to play
              _ExpandableSection(
                icon: AppIcons.circleQuestion,
                iconColor: AppTheme.correct,
                title: context.t(K.howToPlay),
                body: context.t(K.howToPlayBody),
              ),
              const SizedBox(height: AppSpacing.cardGap),

              // Privacy
              _ExpandableSection(
                icon: AppIcons.shieldHalved,
                iconColor: AppTheme.violet,
                title: context.t(K.privacy),
                body: context.t(K.privacyBody),
              ),
              const SizedBox(height: AppSpacing.cardGap),

              // About (includes version)
              AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppTheme.accentGradient,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accent.withValues(alpha: 0.22),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                                spreadRadius: -8,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'ZK',
                              style: AppTypography.heading2.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ZanKurd',
                              style: AppTypography.bodyLarge.copyWith(
                                color: AppTheme.textPrimaryColor(context),
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                            Text(
                              '${context.t(K.version)} $_versionLabel',
                              style: AppTypography.caption.copyWith(
                                color: AppTheme.textMutedColor(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.t(K.aboutBody),
                      style: TextStyle(
                        color: AppTheme.textSubColor(context),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceHiColor(context),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(
                          color: AppTheme.borderColor(
                            context,
                          ).withValues(alpha: 0.8),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                AppRadius.badge,
                              ),
                            ),
                            child: Icon(
                              AppIcons.star,
                              color: AppColors.onAccentTint(
                                context,
                                AppTheme.accent,
                              ),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              context.t(K.localChangesNote),
                              style: AppTypography.caption.copyWith(
                                color: AppTheme.textSubColor(context),
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Yasal bağlantılar (mağaza şartı)
                    const LegalLinksRow(),
                    const SizedBox(height: 10),
                    // Soru fotoğrafları CC BY lisanslıdır; atıf yasal
                    // yükümlülüktür (bkz. image_credits_screen.dart).
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: InkWell(
                        key: const ValueKey('settings-image-credits'),
                        onTap: () => Navigator.of(
                          context,
                        ).push(AppRoute.to(const ImageCreditsScreen())),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            context.t(K.imageCredits),
                            style: AppTypography.caption.copyWith(
                              color: AppTheme.brand,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Hesap silme en yıkıcı eylem olmasına rağmen ayarların
              // en üstünde, ikinci kartta duruyordu. Yeni kullanıcı
              // için yanlış öncelik — en alta taşındı
              // (2026-07-22 canlı UX denetimi).
              const SizedBox(height: AppSpacing.cardGap),
              // Hesap Silme (kırmızı/uyarı stili ile ayrı görselleştirme, Hesap grubunun altında)
              AppPanel(
                color: AppTheme.surfaceOf(context).withValues(alpha: 0.92),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          AppIcons.triangleExclamation,
                          color: AppTheme.wrong,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          context.t(K.secDanger),
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppTheme.textPrimaryColor(context),
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.t(K.dangerNote),
                      style: AppTypography.caption.copyWith(
                        color: AppTheme.textMutedColor(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      key: const ValueKey('delete-account-action'),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      onTap: _deleting ? null : _confirmDeleteAccount,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.wrong.withValues(alpha: 0.12),
                              AppTheme.wrong.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(
                            color: AppTheme.wrong.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Row(
                          children: [
                            _deleting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.wrong,
                                    ),
                                  )
                                : const Icon(
                                    AppIcons.trashCan,
                                    color: AppTheme.wrong,
                                    size: 22,
                                  ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.t(K.deleteAccount),
                                    style: const TextStyle(
                                      color: AppTheme.wrong,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    context.t(K.deleteAccountSub),
                                    style: AppTypography.caption.copyWith(
                                      color: AppTheme.textMutedColor(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              AppIcons.chevronRight,
                              color: AppTheme.textMutedColor(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),
            ],
          ),
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
        backgroundColor: AppTheme.surfaceOf(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: AppTheme.borderColor(context)),
        ),
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

  /// Çocuk modunu değiştirir. Açarken ne değiştiğini açıklayan bir onay
  /// dialogu gösterir. (Yalnız cihaz tarafı — sunucu koruması yoktur.)
  ///
  /// Bu yorum uzun süre yetim kaldı: altındaki gövde hiç yazılmamıştı ve
  /// `ChildSafetyProvider` hiçbir yerde (ne bu ekranda ne widget ağacında)
  /// kayıtlı değildi — anahtar yoktu, kapı da çalışmıyordu (2026-08-14
  /// denetimi). Kapatmak onay istemez; yalnız AÇMAK isteği doğrular.
  Future<void> _toggleChildSafety(bool enabled) async {
    if (enabled) {
      final confirmed = await _confirmChildSafetyEnable();
      if (confirmed != true || !mounted) return;
    }
    if (!mounted) return;
    await context.read<ChildSafetyProvider>().setEnabled(enabled);
  }

  Future<bool?> _confirmChildSafetyEnable() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceOf(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: AppTheme.borderColor(context)),
        ),
        title: Text(context.t(K.childSafetyConfirmTitle)),
        content: Text(context.t(K.childSafetyConfirmBody)),
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
        backgroundColor: AppTheme.surfaceOf(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: AppTheme.borderColor(context)),
        ),
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
              backgroundColor: AppTheme.surfaceOf(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                side: BorderSide(color: AppTheme.borderColor(context)),
              ),
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

class _LangSwitch extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isKu = context.isKu;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHiColor(context),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: AppTheme.cardShadow(context),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LangChip(
            label: 'KU',
            active: isKu,
            onTap: () => context.langProvider.setLang('ku'),
          ),
          _LangChip(
            label: 'TR',
            active: !isKu,
            onTap: () => context.langProvider.setLang('tr'),
          ),
        ],
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accessibleLabel = label == 'KU' ? 'Kurmancî' : 'Türkçe';
    return Semantics(
      button: true,
      selected: active,
      label: accessibleLabel,
      excludeSemantics: true,
      child: Tooltip(
        message: accessibleLabel,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              constraints: const BoxConstraints(minHeight: 46, minWidth: 56),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                gradient: active ? AppTheme.accentGradient : null,
                color: active ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: AppTheme.accent.withValues(alpha: 0.24),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                          spreadRadius: -8,
                        ),
                      ]
                    : null,
              ),
              child: Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  color: active
                      ? Colors.white
                      : AppTheme.textMutedColor(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsIconTitle extends StatelessWidget {
  const _SettingsIconTitle({
    required this.icon,
    required this.color,
    required this.title,
  });

  final IconData icon;
  final Color color;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: ExcludeSemantics(
            child: Icon(
              icon,
              color: AppColors.onAccentTint(context, color),
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            title,
            style: AppTypography.bodyLarge.copyWith(
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.trailing,
    this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: title,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: color.withValues(alpha: 0.14)),
              ),
              child: ExcludeSemantics(
                child: Icon(
                  icon,
                  color: AppColors.onAccentTint(context, color),
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppTheme.textPrimaryColor(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTypography.caption.copyWith(
                        color: AppTheme.textMutedColor(context),
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _ExpandableSection extends StatelessWidget {
  const _ExpandableSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Material(
          color: Colors.transparent,
          child: ExpansionTile(
            leading: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                icon,
                color: AppColors.onAccentTint(context, iconColor),
                size: 18,
              ),
            ),
            iconColor: AppTheme.textSubColor(context),
            collapsedIconColor: AppTheme.textMutedColor(context),
            title: Text(
              title,
              style: AppTypography.bodyLarge.copyWith(
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.md,
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  body,
                  style: TextStyle(
                    color: AppTheme.textSubColor(context),
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ayarlar > Seslendirme (TTS) bölümü. TtsService'i yükler; aç/kapa,
/// konuşma hızı ve ses seviyesi kontrollerini gösterir. Cihazda Kürtçe
/// seslendirme desteklenmiyorsa bir bilgi notu gösterir (kontroller yine
/// çalışır; yedek dil sesi kullanılabilir).
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

    if (tts == null) {
      return AppPanel(
        child: Text(
          context.t(K.ttsUnavailable),
          style: AppTypography.caption.copyWith(
            color: AppTheme.textMutedColor(context),
          ),
        ),
      );
    }

    final enabled = tts.isEnabled;
    return AppPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _SettingsToggleRow(
            icon: enabled ? AppIcons.volumeHigh : AppIcons.volumeXmark,
            color: AppTheme.primaryGradientStart,
            title: context.t(K.ttsEnable),
            subtitle: context.t(K.ttsEnableSub),
            trailing: Switch(
              value: enabled,
              onChanged: (v) async {
                await tts.setEnabled(v);
                if (mounted) setState(() {});
              },
            ),
          ),
          if (!tts.isKurdishAvailable)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    AppIcons.circleInfo,
                    size: 16,
                    color: AppTheme.textMutedColor(context),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      context.t(K.ttsKurdishLimited),
                      style: AppTypography.caption.copyWith(
                        color: AppTheme.textMutedColor(context),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (enabled) ...[
            Divider(
              height: 1,
              indent: 56,
              color: AppTheme.borderColor(context),
            ),
            _TtsSlider(
              label: context.t(K.ttsRate),
              icon: AppIcons.bolt,
              value: tts.rate,
              onChanged: (v) async {
                await tts.setRate(v);
                if (mounted) setState(() {});
              },
            ),
            Divider(
              height: 1,
              indent: 56,
              color: AppTheme.borderColor(context),
            ),
            _TtsSlider(
              label: context.t(K.ttsVolume),
              icon: AppIcons.volumeHigh,
              value: tts.volume,
              onChanged: (v) async {
                await tts.setVolume(v);
                if (mounted) setState(() {});
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// TTS hız/ses seviyesi için 0–1 aralığında etiketleli kaydırıcı satırı.
class _TtsSlider extends StatelessWidget {
  const _TtsSlider({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primaryGradientStart.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              icon,
              color: AppColors.onAccentTint(
                context,
                AppTheme.primaryGradientStart,
              ),
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppTheme.textPrimaryColor(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    // Sınıf belgesi "etiketleli kaydırıcı" diyordu ama
                    // ekranda yalnız ad vardı: kullanıcı hızın ya da sesin
                    // hangi değerde olduğunu göremiyordu (2026-07-25
                    // denetimi). Yüzde, kaydırıcının kendisiyle aynı
                    // satırda ve sabit genişlikte durur ki değer
                    // değişirken etiket zıplamasın.
                    SizedBox(
                      width: 44,
                      child: Text(
                        context.percentRatio(value.clamp(0.0, 1.0)),
                        textAlign: TextAlign.end,
                        style: AppTypography.caption.copyWith(
                          color: AppTheme.textMutedColor(context),
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [
                            // Tabular rakam: %9 → %10 geçişinde genişlik
                            // değişmesin.
                            FontFeature.tabularFigures(),
                          ],
                        ),
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
    return AppPanel(
      child: FutureBuilder<List<PlayerSearchResult>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          if (snapshot.hasError) {
            // `loadBlockedPlayers` artık okunamayan listeyi yutup boş
            // dönmüyor (rethrow) — burada da yutup "kimseyi engellemedin"
            // gösterirsek aynı sessiz kırılma boş durum kılığına girer.
            // Gerçekten engellenmiş biri kalıcı kaybolmuş gibi görünürdü,
            // engeli kaldırma yolu da onunla birlikte kaybolurdu
            // (2026-08-14 denetimi).
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t(K.blockedLoadFailed),
                    key: const ValueKey('blocked-error'),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: _retry,
                    child: Text(context.t(K.retry)),
                  ),
                ],
              ),
            );
          }
          final blocked = snapshot.data ?? const <PlayerSearchResult>[];
          if (blocked.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                context.t(K.blockedEmpty),
                key: const ValueKey('blocked-empty'),
                style: AppTypography.caption.copyWith(
                  color: AppTheme.textMutedColor(context),
                ),
              ),
            );
          }
          return Column(
            children: [
              for (final player in blocked)
                ListTile(
                  key: ValueKey('blocked-row-${player.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    player.displayName,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                  subtitle: player.formattedTag == null
                      ? null
                      : Text(player.formattedTag!),
                  trailing: TextButton(
                    key: ValueKey('unblock-${player.id}'),
                    onPressed: _working.contains(player.id)
                        ? null
                        : () => _unblock(player),
                    child: Text(context.t(K.unblockAction)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
