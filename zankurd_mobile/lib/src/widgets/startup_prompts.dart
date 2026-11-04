import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/age_gate_store.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../providers/analytics_consent_provider.dart';
import '../services/analytics_service.dart';
import '../utils/error_reporter.dart';
import 'sahne/sahne.dart';

/// İlk açılışta bir kez sorulan iki kısa soru: yaş beyanı ve ölçüm rızası.
///
/// ## Niçin
///
/// Ölçüm (Analytics/Crashlytics) varsayılan KAPALI (2026-10-29 kararı) ama
/// kullanıcıya hiç sorulmuyordu: izin yalnız Ayarlar'da gömülüydü, yani
/// pratikte kimse açmıyor, hata ve kullanım verisi görünmez kalıyordu.
/// Yaş beyanı ise mağaza/COPPA şartı (bkz. [AgeGate]).
///
/// ## Kurallar
///
/// * Açılışı ASLA bekletmez; kabuk hazır olup ilk akış bitince, kısa bir
///   gecikmeyle ve yalnız ekran hâlâ açıkken çıkar.
/// * Her soru BİR KEZ çıkar; sayfa kapatılırsa "cevap yok" sayılır
///   (rıza için kapalı kalır; yaş için kısıtsız ama tekrar sorulmaz).
/// * Sıra: yaş → (13 üstüyse) rıza. 13 altına ölçüm sorulmaz.
/// * Rıza daha önce AÇIKÇA verilmiş/reddedilmişse (eski anahtar) sorulmaz;
///   seçim her zaman Ayarlar'dan değiştirilir.
class StartupPrompts {
  const StartupPrompts._();

  static const consentShownKey = 'zankurd.consentPrompt.v1.shown';

  /// Soruların ilk akıştan sonra çıkmadan önce bekleyeceği süre. Bekleme
  /// çağıranın (kabuğun) iptal edilebilir sayacındadır: ağaç sökülünce
  /// sayaç da gider (bkz. `AppShell._promptTimer`).
  static const startDelay = Duration(seconds: 2);

  /// Kabuktan çağrılır; oturumda bir kez.
  static Future<void> run(BuildContext context) async {
    try {
      if (await AgeGate.shouldAsk()) {
        await AgeGate.markAsked();
        if (!context.mounted) return;
        await showAgeGateSheet(context);
        if (!context.mounted) return;
      }
      if (AgeGate.isMinor || !await shouldShowConsent()) return;
      if (!context.mounted) return;
      await showConsentSheet(context);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'startup_prompts');
    }
  }

  /// Rıza sayfası çıkmalı mı? Çıkmamalı: gösterildiyse, ya da kullanıcı
  /// kullanım analizi için daha önce açıkça seçim yaptıysa.
  static Future<bool> shouldShowConsent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(consentShownKey) == true) return false;
      if (prefs.containsKey('zankurd.analyticsConsent')) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> showConsentSheet(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(consentShownKey, true);
    } catch (_) {}
    if (!context.mounted) return;
    await showSahneSheet<void>(
      context: context,
      title: context.t(K.consentSheetTitle),
      builder: (_) => const _ConsentBody(),
    );
  }

  /// Sosyal bir özelliğe girmeden önce çağrılır. Beyan yoksa yaş sorusunu
  /// gösterir; `true` yalnız "13 yaşından büyüğüm" için döner. Çocuk beyanı
  /// ya da soruyu kapatma `false` verir (öğrenme ve tek kişilik oyun
  /// etkilenmez; çağıran yalnız sosyal adımı yapmaz).
  static Future<bool> ensureAgeCleared(BuildContext context) async {
    if (AgeGate.isAdult) return true;
    if (AgeGate.isMinor) return false;
    await AgeGate.markAsked();
    if (!context.mounted) return false;
    await showAgeGateSheet(context);
    return AgeGate.isAdult;
  }

  static Future<void> showAgeGateSheet(BuildContext context) =>
      showSahneSheet<void>(
        context: context,
        title: context.t(K.ageGateTitle),
        builder: (_) => const _AgeGateBody(),
      );
}

class _ConsentBody extends StatefulWidget {
  const _ConsentBody();

  @override
  State<_ConsentBody> createState() => _ConsentBodyState();
}

class _ConsentBodyState extends State<_ConsentBody> {
  /// Kayıt sürerken düğmeler kapalı: hızlı çift dokunuş iki `_choose`
  /// başlatıp ikinci `pop`la arkadaki ekranı ya da sıradaki pencereyi
  /// kapatıyordu.
  bool _busy = false;

  Future<void> _choose(bool accept) async {
    if (_busy) return;
    setState(() => _busy = true);
    final consent = context.read<AnalyticsConsentProvider>();
    final navigator = Navigator.of(context);
    // Seçim önce yazılır, sonra sayfa kapanır; ikisi de AYRI anahtar.
    await consent.setEnabled(accept);
    await consent.setCrashReportsEnabled(accept);
    if (accept) {
      unawaited(AnalyticsService.instance.initialize(enabled: true));
    }
    if (mounted && navigator.mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SahneSpace.page,
        0,
        SahneSpace.page,
        SahneSpace.x4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t(K.consentSheetBody),
            style: SahneType.body.copyWith(color: t.tx2),
          ),
          const SizedBox(height: SahneSpace.x5),
          SahneButton.primary(
            buttonKey: const ValueKey('consent-accept'),
            label: context.t(K.consentSheetAccept),
            expand: true,
            arrow: false,
            onPressed: _busy ? null : () => unawaited(_choose(true)),
          ),
          const SizedBox(height: SahneSpace.x2),
          SahneButton.secondary(
            buttonKey: const ValueKey('consent-decline'),
            label: context.t(K.consentSheetDecline),
            expand: true,
            onPressed: _busy ? null : () => unawaited(_choose(false)),
          ),
        ],
      ),
    );
  }
}

class _AgeGateBody extends StatefulWidget {
  const _AgeGateBody();

  @override
  State<_AgeGateBody> createState() => _AgeGateBodyState();
}

class _AgeGateBodyState extends State<_AgeGateBody> {
  /// Kayıt sürerken düğmeler kapalı: hızlı çift dokunuş iki `_choose`
  /// başlatıp ikinci `pop`la arkadaki ekranı ya da sıradaki pencereyi
  /// kapatıyordu.
  bool _busy = false;

  Future<void> _choose(AgeDeclaration value) async {
    if (_busy) return;
    setState(() => _busy = true);
    final consent = context.read<AnalyticsConsentProvider>();
    final navigator = Navigator.of(context);
    await AgeGate.declare(value);
    if (value == AgeDeclaration.minor) {
      // Kişiselleştirilmiş ölçüm anında kapanır (zaten kapalıysa no-op).
      await consent.setEnabled(false);
      await consent.setCrashReportsEnabled(false);
      unawaited(AnalyticsService.instance.disable());
    }
    if (mounted && navigator.mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SahneSpace.page,
        0,
        SahneSpace.page,
        SahneSpace.x4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t(K.ageGateBody),
            style: SahneType.body.copyWith(color: t.tx2),
          ),
          const SizedBox(height: SahneSpace.x5),
          SahneButton.primary(
            buttonKey: const ValueKey('age-gate-yes'),
            label: context.t(K.yes),
            expand: true,
            arrow: false,
            onPressed: _busy
                ? null
                : () => unawaited(_choose(AgeDeclaration.adult)),
          ),
          const SizedBox(height: SahneSpace.x2),
          SahneButton.secondary(
            buttonKey: const ValueKey('age-gate-no'),
            label: context.t(K.no),
            expand: true,
            onPressed: _busy
                ? null
                : () => unawaited(_choose(AgeDeclaration.minor)),
          ),
        ],
      ),
    );
  }
}
