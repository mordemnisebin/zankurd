import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../config/runtime_config.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../utils/error_reporter.dart';
import '../utils/external_link.dart';
import 'sahne/sahne.dart';

/// Zorunlu / yumuşak güncelleme kapısı + bakım iletisi (uzak ayardan).
///
/// ## Niçin var
///
/// Bir sürümde veri bozan ya da çöken bir hata çıkarsa eski sürümü
/// kullanan herkes kendi başına kalıyordu: yükseltmeye zorlamanın yolu
/// yoktu (olcek_* denetimi, 2026-11). Tablo `app_runtime_config`
/// (`min_supported_build_*`, `latest_build_*`).
///
/// ## Kurallar (bozulmamalı)
///
/// * Cihazın build numarası BİLİNMİYORSA ya da uzak ayar yoksa HİÇBİR
///   ŞEY çıkmaz: emin olunamayan cihaz kilitlenmez.
/// * Zorunlu: build < asgari ise kök [UpdateRequiredScreen] ile DEĞİŞİR
///   (altta oyun sürmez); tek eylem mağaza düğmesi.
/// * Yumuşak: build < son sürüm ise üstte KAPATILABİLİR bant, AYNI build
///   için yalnız bir kez (kapatınca ya da "Güncelle"ye basınca işaretlenir).
///   Bant üstte bir kaplamadır (Stack): yerleşimi iterek ZIPLATMAZ.
/// * Bakım iletisi (`maintenance_message_*`) engellemez; oturum boyunca
///   kapatılabilir bilgi bandıdır.
/// * Öne dönüşte (≥15 dk) ayar tazelenir.
class UpdateGate extends StatefulWidget {
  const UpdateGate({
    required this.child,
    this.buildNumber,
    this.platform,
    this.openStore,
    super.key,
  });

  final Widget child;

  /// Test için: cihazın build numarası. Verilmezse `package_info_plus`.
  final Future<int?> Function()? buildNumber;

  /// Test için: platform. Verilmezse [defaultTargetPlatform].
  final TargetPlatform? platform;

  /// Test için: mağaza açıcı. Verilmezse [openExternalLink].
  final Future<void> Function(BuildContext context, String url)? openStore;

  /// Bandın "bu build için kapatıldı" işareti (değer = build numarası).
  static const dismissedBuildKey = 'zankurd.updateBanner.dismissedBuild';

  static Future<int?> _packageBuild() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return int.tryParse(info.buildNumber);
    } catch (_) {
      return null;
    }
  }

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> with WidgetsBindingObserver {
  int? _build;
  bool _softDismissed = true; // okunana dek gösterme: ilk karede bant yok
  bool _maintenanceDismissed = false;

  TargetPlatform get _platform => widget.platform ?? defaultTargetPlatform;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadBuild());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    try {
      unawaited(context.read<RuntimeConfigService>().refreshIfStale());
    } catch (_) {}
  }

  Future<void> _loadBuild() async {
    final build = await (widget.buildNumber ?? UpdateGate._packageBuild)();
    var dismissed = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      dismissed =
          build != null && prefs.getInt(UpdateGate.dismissedBuildKey) == build;
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'update_banner_read');
    }
    if (!mounted) return;
    setState(() {
      _build = build;
      _softDismissed = dismissed;
    });
  }

  Future<void> _dismissSoft() async {
    setState(() => _softDismissed = true);
    final build = _build;
    if (build == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(UpdateGate.dismissedBuildKey, build);
    } catch (_) {}
  }

  String? get _storeUrl => switch (_platform) {
    TargetPlatform.iOS => AppConfig.appStoreUrl,
    TargetPlatform.android => AppConfig.playStoreUrl,
    _ => null,
  };

  Future<void> _openStore(BuildContext context) async {
    final url = _storeUrl;
    if (url == null) return;
    final open = widget.openStore ?? openExternalLink;
    await open(context, url);
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<RuntimeConfigService>().value;
    final build = _build;
    if (config.requiresUpdate(build, _platform) && _storeUrl != null) {
      return UpdateRequiredScreen(onOpenStore: () => _openStore(context));
    }
    final isKu = context.isKu;
    final maintenance = _maintenanceDismissed
        ? null
        : config.maintenanceMessage(isKu: isKu);
    final showSoft =
        !_softDismissed &&
        _storeUrl != null &&
        config.hasNewerBuild(build, _platform);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (maintenance != null || showSoft)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(SahneSpace.x3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (maintenance != null)
                      _NoticeBanner(
                        key: const ValueKey('maintenance-banner'),
                        message: maintenance,
                        onDismiss: () =>
                            setState(() => _maintenanceDismissed = true),
                      ),
                    if (maintenance != null && showSoft)
                      const SizedBox(height: SahneSpace.x2),
                    if (showSoft)
                      _NoticeBanner(
                        key: const ValueKey('update-soft-banner'),
                        message: context.t(K.updateSoftBanner),
                        actionLabel: context.t(K.updateSoftAction),
                        onAction: () {
                          unawaited(_dismissSoft());
                          unawaited(_openStore(context));
                        },
                        onDismiss: () => unawaited(_dismissSoft()),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({
    required this.message,
    required this.onDismiss,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Material(
      color: t.s2,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SahneSpace.x3),
        side: BorderSide(color: t.edge),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: SahneSpace.x4),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: SahneSpace.x3),
                child: Text(
                  message,
                  style: SahneType.body.copyWith(color: t.tx),
                ),
              ),
            ),
            if (actionLabel != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            IconButton(
              tooltip: context.t(K.close),
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

/// Zorunlu güncelleme: kök bunun YERİNE geçer; tek çıkış mağaza düğmesi.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({required this.onOpenStore, super.key});

  final VoidCallback onOpenStore;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        key: const ValueKey('update-required-screen'),
        backgroundColor: t.bg,
        body: SafeArea(
          // Küçük ekranda 2x yazıyla içerik yüksekliği ekranı aşar; tek çıkış
          // olan mağaza düğmesi görünmez kalmasın diye gövde kaydırılır,
          // sığdığında eskisi gibi ortalanır.
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Padding(
                      padding: const EdgeInsets.all(SahneSpace.x6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            Icons.system_update_rounded,
                            size: 56,
                            color: t.actTx,
                          ),
                          const SizedBox(height: SahneSpace.x5),
                          Semantics(
                            header: true,
                            child: Text(
                              context.t(K.updateRequiredTitle),
                              textAlign: TextAlign.center,
                              style: SahneType.title.copyWith(color: t.tx),
                            ),
                          ),
                          const SizedBox(height: SahneSpace.x3),
                          Text(
                            context.t(K.updateRequiredBody),
                            textAlign: TextAlign.center,
                            style: SahneType.body.copyWith(color: t.tx2),
                          ),
                          const SizedBox(height: SahneSpace.x8),
                          SahneButton.primary(
                            buttonKey: const ValueKey('update-required-store'),
                            label: context.t(K.updateRequiredAction),
                            expand: true,
                            onPressed: onOpenStore,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
