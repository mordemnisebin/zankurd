import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../data/placement_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../utils/app_route.dart';
import 'level_placement_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/child_safety_provider.dart';
import '../providers/reduced_motion_provider.dart';
import '../providers/sound_provider.dart';
import '../providers/theme_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_panel.dart';
import '../widgets/screen_identity_header.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  /// Fallback if [PackageInfo] unavailable (tests / edge platforms).
  static const appVersion = '1.8.0+10';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  bool _deleting = false;
  bool _loadingName = true;
  String _versionLabel = SettingsScreen.appVersion;
  bool _savingName = false;
  String _currentName = '';
  NotificationService? _notificationService;
  bool _notificationsEnabled = false;
  String _notificationTime = '19:00';

  @override
  void initState() {
    super.initState();
    _loadPlayerName();
    _loadNotificationSettings();
    _loadPackageVersion();
  }

  Future<void> _loadPackageVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _versionLabel = '${info.version}+${info.buildNumber}';
      });
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'settings_load');
      // Keep static fallback (tests / unsupported platforms).
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadPlayerName() async {
    try {
      final name = await widget.repository.getProfileName();
      if (!mounted) return;
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
          SnackBar(
            content: Text(
              context.s(
                'Navê lîstikvan nehat barkirin.',
                'Oyuncu adı yüklenemedi.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(ku ? 'Mîheng' : 'Ayarlar')),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.xs,
              AppSpacing.page,
              AppSpacing.lg,
            ),
            children: [
              // Profil ailesi — mor kimlik (AppShell sekme 4).
              ScreenIdentityHeader(
                title: ku ? 'Vebijarkên Te' : 'Tercihlerin',
                subtitle: ku
                    ? 'Hesab, dîmen û dengê xwe birêve bibe'
                    : 'Hesap, görünüm ve ses tercihlerini yönet',
                accent: AppTheme.violet,
                icon: Icons.settings_rounded,
              ),
              const SizedBox(height: AppSpacing.md),

              // ============ HESAP / ACCOUNT ============
              ScreenSectionLabel(
                label: ku ? 'Hesap' : 'Hesap',
                accent: AppTheme.violet,
              ),
              AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SettingsIconTitle(
                      icon: Icons.badge_outlined,
                      color: AppTheme.primaryGradientStart,
                      title: ku ? 'Navê lîstikê' : 'Oyuncu Adı',
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
                        hintText: ku
                            ? 'Navê xwe binivîse...'
                            : 'Oyundaki adını gir...',
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _savePlayerName(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _loadingName || _savingName
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
                            : Icon(Icons.save_outlined),
                        label: Text(ku ? 'Tomar Bike' : 'Kaydet'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),

              // Hesap Silme (kırmızı/uyarı stili ile ayrı görselleştirme, Hesap grubunun altında)
              AppPanel(
                color: AppTheme.surfaceOf(context).withValues(alpha: 0.92),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppTheme.wrong,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          ku ? 'Karên Hesabê' : 'Hesap İşlemleri',
                          style: TextStyle(
                            color: AppTheme.textPrimaryColor(context),
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ku
                          ? 'Ev kar nayên vegerandin.'
                          : 'Bu alandaki işlemler geri alınamaz.',
                      style: TextStyle(
                        color: AppTheme.textMutedColor(context),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      key: const ValueKey('delete-account-action'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: _deleting ? null : _confirmDeleteAccount,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.wrong.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.wrong.withValues(alpha: 0.28),
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
                                : Icon(
                                    Icons.delete_forever_outlined,
                                    color: AppTheme.wrong,
                                    size: 22,
                                  ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ku ? 'Hesabê Min Jê Bibe' : 'Hesabımı Sil',
                                    style: TextStyle(
                                      color: AppTheme.wrong,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    ku
                                        ? 'Profîl, coin û pirsên tomarkirî tên jêbirin.'
                                        : 'Profil, coin ve kaydedilen soru verilerin silinir.',
                                    style: TextStyle(
                                      color: AppTheme.textMutedColor(context),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
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

              // ============ ÖĞRENME / LEARNING ============
              ScreenSectionLabel(
                label: ku ? 'Hînbûn' : 'Öğrenme',
                accent: AppTheme.playGreen,
              ),
              AppPanel(
                color: AppTheme.surfaceOf(context).withValues(alpha: 0.92),
                child: InkWell(
                  key: const ValueKey('retake-placement-action'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: _openPlacement,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.assignment_turned_in_outlined,
                          color: AppTheme.playGreen,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ku
                                    ? 'Asta xwe ji nû ve diyar bike'
                                    : 'Seviyeni yeniden belirle',
                                style: TextStyle(
                                  color: AppTheme.textPrimaryColor(context),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              FutureBuilder<PlacementStore>(
                                future: PlacementStore.load(),
                                builder: (context, snap) {
                                  final level = snap.data?.level;
                                  final String sub;
                                  if (level == null) {
                                    sub = ku
                                        ? 'Kurt sînavek bê tade'
                                        : 'Kısa, baskısız bir sınav';
                                  } else {
                                    final name = ku
                                        ? level.labelKu
                                        : level.labelTr;
                                    sub = ku
                                        ? 'Asta te ya niha: $name'
                                        : 'Mevcut seviyen: $name';
                                  }
                                  return Text(
                                    sub,
                                    style: TextStyle(
                                      color: AppTheme.textMutedColor(context),
                                      fontSize: 12,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.textMutedColor(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),

              // ============ GÜVENLİK / SAFETY ============
              ScreenSectionLabel(
                label: ku ? 'Ewlekarî' : 'Güvenlik',
                accent: AppTheme.playGreen,
              ),
              AppPanel(
                padding: EdgeInsets.zero,
                child: Consumer<ChildSafetyProvider>(
                  builder: (context, child, _) => _SettingsToggleRow(
                    icon: Icons.shield_outlined,
                    color: AppTheme.playGreen,
                    title: ku ? 'Moda zaroka ewle' : 'Güvenli çocuk modu',
                    trailing: Switch(
                      key: const ValueKey('child-safe-switch'),
                      value: child.enabled,
                      onChanged: (v) => _toggleChildSafety(child, v, ku),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),

              // ============ GÖRÜNÜM / APPEARANCE ============
              ScreenSectionLabel(
                label: ku ? 'Dîmen' : 'Görünüm',
                accent: AppTheme.violet,
              ),
              AppPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingsToggleRow(
                      icon: Icons.language,
                      color: AppTheme.violet,
                      title: ku ? 'Zimanê sepanê' : 'Uygulama dili',
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
                                ? Icons.dark_mode_outlined
                                : Icons.light_mode_outlined,
                            color: AppTheme.violet,
                            title: ku
                                ? 'Modê tarî/ronahî'
                                : 'Karanlık/Aydınlık mod',
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
                        icon: Icons.animation_outlined,
                        color: AppTheme.violet,
                        title: ku ? 'Tevgerê kêm bike' : 'Hareketi azalt',
                        trailing: Switch(
                          key: const ValueKey('reduce-motion-switch'),
                          value: motion.userReduce,
                          onChanged: (v) => motion.setUserReduce(v),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),

              // ============ SES & BİLDİRİM / SOUND & NOTIFICATIONS ============
              ScreenSectionLabel(
                label: ku ? 'Deng û Agahdarî' : 'Ses & Bildirim',
                accent: AppTheme.violet,
              ),
              AppPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    Consumer<SoundProvider>(
                      builder: (context, sound, _) => _SettingsToggleRow(
                        icon: sound.enabled
                            ? Icons.volume_up_outlined
                            : Icons.volume_off_outlined,
                        color: AppTheme.primaryGradientStart,
                        title: ku ? 'Deng û mûzîk' : 'Ses efektleri',
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
                    _SettingsToggleRow(
                      icon: _notificationsEnabled
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_off_outlined,
                      color: AppTheme.violet,
                      title: ku ? 'Bîranîna rojane' : 'Günlük hatırlatıcı',
                      subtitle: ku
                          ? 'Her roj di demjimêr $_notificationTime de'
                          : 'Her gün saat $_notificationTime',
                      trailing: Switch(
                        value: _notificationsEnabled,
                        onChanged: _toggleNotifications,
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
                                Icon(
                                  Icons.access_time_outlined,
                                  color: AppTheme.violet,
                                  size: 18,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  ku
                                      ? 'Demê biguherîne: $_notificationTime'
                                      : 'Saati değiştir: $_notificationTime',
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

              // ============ HAKKINDA / ABOUT ============
              ScreenSectionLabel(
                label: ku ? 'Derbarê Sepanê' : 'Uygulama Hakkında',
                accent: AppTheme.violet,
              ),
              // How to play
              _ExpandableSection(
                icon: Icons.help_outline_rounded,
                iconColor: AppTheme.correct,
                title: ku ? 'Çawa tê lîstin?' : 'Nasıl oynanır?',
                body: ku
                    ? '• Pêşbirka Bilez: tavilê 10 pirsan bibersivîne.\n'
                          '• Pêşbirka Rojê: her roj ji bo hemû lîstikvanan heman 10 pirs.\n'
                          '• Odeyek Ava Bike: kodê bide hevalên xwe û bi hev re bilîzin.\n'
                          '• Kategorî û Ast: ji 8 kategoriyan û 5 astan hilbijêre.\n'
                          '• Joker 50/50: du bersivên şaş radike.\n'
                          '• Bersiva rast pûan û coin dide; rêza rast bonus zêde dike.'
                    : '• Hızlı Yarış: hemen 10 soru cevapla.\n'
                          '• Günün Yarışması: her gün tüm oyunculara aynı 10 soru.\n'
                          '• Oda Kur: kodu arkadaşlarına ver, birlikte yarışın.\n'
                          '• Kategori ve Seviye: 8 kategori, 5 seviye arasından seç.\n'
                          '• 50/50 jokeri iki yanlış cevabı eler.\n'
                          '• Doğru cevap puan ve coin kazandırır; seri bonusu artırır.',
              ),
              const SizedBox(height: AppSpacing.cardGap),

              // Privacy
              _ExpandableSection(
                icon: Icons.privacy_tip_outlined,
                iconColor: AppTheme.violet,
                title: ku ? 'Nepenî' : 'Gizlilik',
                body: ku
                    ? 'ZanKurd ev dane tomar dike: navê lîstikvan, '
                          'navnîşana e-peyamê (heke tomar bibî), pûan û statîstîkên '
                          'lîstikê, hejmara coinan û pirsên tomarkirî. Di xetayan de '
                          'tomarên teknîkî yên anonîm tên berhevkirin.\n\n'
                          'Daneyên te nayên firotin û ji bo reklamê bi kesên sêyemîn '
                          're nayên parvekirin. Navê te tenê di tabloya pêşderçûnê de '
                          'xuya dibe.\n\n'
                          'Ji bo jêbirina hesabê û hemû daneyan: '
                          'nisebinbawer47@gmail.com'
                    : 'ZanKurd şu verileri saklar: oyuncu adı, e-posta adresi '
                          '(kayıt olursan), oyun puanları ve istatistikleri, coin '
                          'bakiyesi ve kaydedilen sorular. Hatalarda anonim teknik '
                          'çökme kayıtları toplanır.\n\n'
                          'Verilerin satılmaz ve üçüncü taraflarla pazarlama amaçlı '
                          'paylaşılmaz. Adın yalnızca liderlik tablosunda görünür.\n\n'
                          'Hesabını ve tüm verilerini kalıcı sildirmek için: '
                          'nisebinbawer47@gmail.com',
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
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'ZK',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
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
                              style: TextStyle(
                                color: AppTheme.textPrimaryColor(context),
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                            Text(
                              '${ku ? 'Guherto' : 'Sürüm'} $_versionLabel',
                              style: TextStyle(
                                color: AppTheme.textMutedColor(context),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      ku
                          ? 'Sepana pêşbirkê ya Kurmancî — ziman, çand, dîrok, '
                                'edebiyat, erdnîgarî û muzîka Kurdî hîn bibe û pêşbirkê bike.'
                          : 'Kurmancî bilgi yarışması uygulaması — Kürt dili, kültürü, '
                                'tarihi, edebiyatı, coğrafyası ve müziğini öğren, yarış.',
                      style: TextStyle(
                        color: AppTheme.textSubColor(context),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
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
    if (mounted) {
      setState(() {
        _notificationsEnabled = value;
      });
    }
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
  Future<void> _toggleChildSafety(
    ChildSafetyProvider provider,
    bool value,
    bool ku,
  ) async {
    if (!value) {
      await provider.setEnabled(false);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(ku ? 'Moda zaroka ewle' : 'Güvenli çocuk modu'),
        content: Text(
          ku
              ? 'Ev mod li ser vê amûrê: lêgerîna hevalan, daxwazên nû, '
                    'sohbeta odeyê û parvekirina derve digire. Dane nayên jêbirin; '
                    'gava tu bigirî her tişt vedigere.'
              : 'Bu mod bu cihazda: arkadaş aramayı, yeni istekleri, oda '
                    'sohbetini ve dış paylaşımı kapatır. Hiçbir veri silinmez; '
                    'kapattığında her şey geri gelir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(ku ? 'Betal' : 'Vazgeç'),
          ),
          FilledButton(
            key: const ValueKey('child-safe-confirm'),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(ku ? 'Veke' : 'Aç'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.setEnabled(true);
    }
  }

  Future<void> _openPlacement() async {
    await Navigator.of(
      context,
    ).push(AppRoute.to(LevelPlacementScreen(repository: widget.repository)));
    if (mounted) setState(() {}); // güncel seviyeyi yansıt
  }

  Future<void> _confirmDeleteAccount() async {
    final ku = context.isKu;
    final continueDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceOf(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.borderColor(context)),
        ),
        title: Text(
          ku ? 'Hesabê bi dawî jê bibî?' : 'Hesabı kalıcı olarak sil?',
        ),
        content: Text(
          ku
              ? 'Ev çalakî venagere. Profîl, coin, pirsên tomarkirî û daneyên kesane yên hesabê te tên jêbirin.'
              : 'Bu işlem geri alınamaz. Profil, coin, kaydedilen sorular ve hesabına bağlı kişisel veriler silinir.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(ku ? 'Betal' : 'Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(ku ? 'Berdewam Bike' : 'Devam Et'),
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
    setState(() => _savingName = true);
    try {
      await widget.repository.updateProfileName(name);
      if (!mounted) return;
      setState(() {
        _currentName = name;
        _savingName = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.s(
              'Navê lîstikvan hate nûvekirin.',
              'Oyuncu adı güncellendi.',
            ),
          ),
        ),
      );
    } catch (error, stack) {
      ErrorReporter.record(
        error,
        stack,
        reason: 'settings profile name save failed',
      );
      if (!mounted) return;
      setState(() => _savingName = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.s(
              'Navê lîstikvan nehat tomar kirin.',
              'Oyuncu adı kaydedilemedi.',
            ),
          ),
        ),
      );
    }
  }

  Future<bool?> _showFinalDeleteConfirmation() async {
    final controller = TextEditingController();
    final ku = context.isKu;
    final confirmWord = ku ? 'JÊ BIBE' : 'SIL';
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        var canDelete = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceOf(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppTheme.borderColor(context)),
              ),
              title: Text(ku ? 'Erêkirina dawî' : 'Son onay'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ku
                        ? 'Ji bo jêbirina hesabê "$confirmWord" binivîse.'
                        : 'Hesabını silmek için "$confirmWord" yaz.',
                  ),
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
                  child: Text(ku ? 'Betal' : 'Vazgeç'),
                ),
                FilledButton(
                  onPressed: canDelete
                      ? () => Navigator.pop(dialogContext, true)
                      : null,
                  child: Text(ku ? 'Bi Dawî Jê Bibe' : 'Kalıcı Olarak Sil'),
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
    try {
      await widget.repository.deleteMyAccount();
      if (!mounted) return;
      await context.read<AuthProvider>().signOut();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'deleteAccount failed');
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.s(
              'Hesab nehat jêbirin. Ji kerema xwe dîsa biceribîne.',
              'Hesap silinemedi. Lütfen tekrar deneyin.',
            ),
          ),
        ),
      );
    }
  }
}

class _LangSwitch extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isKu = context.isKu;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHiColor(context),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppTheme.borderColor(context)),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryGradientStart : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppTheme.textMutedColor(context),
            fontWeight: FontWeight.w700,
            fontSize: 12,
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
          child: Icon(icon, color: color, size: 18),
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: color, size: 18),
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
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTypography.caption.copyWith(
                      color: AppTheme.textMutedColor(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing,
        ],
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
              child: Icon(icon, color: iconColor, size: 18),
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
